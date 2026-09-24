import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/boletin_academico.dart';
import '../widgets/boletin_academico_tabla.dart';

class PanelBoletinesPreceptor extends StatefulWidget {
  final String? cursoIdInicial;
  const PanelBoletinesPreceptor({super.key, this.cursoIdInicial});

  @override
  State<PanelBoletinesPreceptor> createState() => _PanelBoletinesPreceptorState();
}

class _PanelBoletinesPreceptorState extends State<PanelBoletinesPreceptor> {
  final _service = SupabaseService();
  bool _loadingCursos = true;
  bool _loadingAlumnos = false;
  bool _generatingBoletin = false;
  
  List<Map<String, dynamic>> _cursos = [];
  String? _selectedCursoId;
  
  List<Map<String, dynamic>> _alumnos = [];
  List<Map<String, dynamic>> _alumnosFiltrados = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCursoId = widget.cursoIdInicial;
    _cargarCursos();
  }

  Future<void> _cargarCursos() async {
    try {
      final lista = await _service.fetchCursos();
      setState(() {
        _cursos = lista;
        _loadingCursos = false;
        if (_selectedCursoId == null && _cursos.isNotEmpty) {
          _selectedCursoId = _cursos.first['curso_id'] as String;
        }
      });
      if (_selectedCursoId != null) {
        _cargarAlumnos(_selectedCursoId!);
      }
    } catch (e) {
      debugPrint('Error cargando cursos: $e');
      setState(() => _loadingCursos = false);
    }
  }

  Future<void> _cargarAlumnos(String cursoId) async {
    setState(() {
      _loadingAlumnos = true;
      _alumnos = [];
      _alumnosFiltrados = [];
    });
    try {
      final list = await _service.fetchAlumnos(cursoId: cursoId);
      final response = await _service.fetchAlumnosList();
      
      final List<Map<String, dynamic>> listCompleta = [];
      for (final a in list) {
        final ext = response.firstWhere(
          (element) => element['legajo_id'] == a.id,
          orElse: () => {},
        );
        listCompleta.add({
          'id': a.id,
          'nombre': a.nombre,
          'dni': ext['dni'] ?? 'DNI No cargado',
          'curso_nombre': ext['curso_nombre'] ?? 'Curso',
        });
      }

      setState(() {
        _alumnos = listCompleta;
        _alumnosFiltrados = listCompleta;
        _loadingAlumnos = false;
      });
      _filtrarAlumnos(_searchCtrl.text);
    } catch (e) {
      debugPrint('Error cargando alumnos: $e');
      setState(() => _loadingAlumnos = false);
    }
  }

  void _filtrarAlumnos(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _alumnosFiltrados = _alumnos;
      } else {
        _alumnosFiltrados = _alumnos
            .where((a) =>
                a['nombre'].toString().toLowerCase().contains(query.toLowerCase()) ||
                a['dni'].toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _abrirVistaPreviaBoletin(Map<String, dynamic> alumno) {
    final alumnoId = alumno['id'] as String;
    final anioLectivo = DateTime.now().year;

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assignment_rounded, color: colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Informe de Trayectoria', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 1200, // Hacerlo más ancho porque tiene muchas columnas
            child: FutureBuilder<List<dynamic>>(
              future: Future.wait([
                _service.obtenerOCrearBoletin(alumnoId, _selectedCursoId!, anioLectivo),
                BoletinAcademico.cargar(
                  service: _service,
                  cursoId: _selectedCursoId!,
                  alumno: BoletinAlumno(
                    id: alumnoId,
                    nombre: alumno['nombre']?.toString() ?? '',
                    dni: alumno['dni']?.toString(),
                  ),
                ),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Text('Error al cargar boletín.')),
                  );
                }

                final boletin = snapshot.data![0] as Map<String, dynamic>;
                final datosBoletin = snapshot.data![1] as DatosBoletin;

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Encabezado
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorScheme.primary.withAlpha(50)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ALUMNO/A: ${(alumno['nombre'] as String).toUpperCase()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text('DNI: ${datosBoletin.dni}  |  AÑO: ${datosBoletin.identificadorDivision}'),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('TOTAL INASISTENCIAS DIARIAS: ${boletin['total_inasistencias_diarias'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                TextButton.icon(
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: const Text('Actualizar Inasistencias', style: TextStyle(fontSize: 12)),
                                  onPressed: () async {
                                    final total = await _service.calcularInasistenciasTotales(alumnoId, _selectedCursoId!, anioLectivo);
                                    await _service.actualizarInasistenciasBoletin(boletin['boletin_id'], total);
                                    if (context.mounted) Navigator.pop(context); // Cierra el modal para que lo vuelva a abrir
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Misma tabla que el Boletín Académico impreso
                      BoletinAcademicoTabla(filas: datosBoletin.filas),

                      const SizedBox(height: 16),
                      const BoletinAcademicoLeyenda(),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              // Mismo Boletín Académico que imprime el docente (todas las
              // materias del curso, notas de informe y de cuatrimestre).
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final error = await BoletinAcademico.imprimir(
                  service: _service,
                  cursoId: _selectedCursoId!,
                  alumnos: [
                    BoletinAlumno(
                      id: alumnoId,
                      nombre: alumno['nombre']?.toString() ?? '',
                      dni: alumno['dni']?.toString(),
                    ),
                  ],
                );
                if (error != null) {
                  messenger.showSnackBar(SnackBar(content: Text(error)));
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Descargar Informe (PDF)'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planilla de Boletines (RITE)',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loadingCursos
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de Curso
                      DropdownButtonFormField<String>(
                        value: _selectedCursoId,
                        decoration: const InputDecoration(
                          labelText: 'Seleccionar Curso',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.class_rounded),
                        ),
                        items: _cursos.map((c) {
                          return DropdownMenuItem(
                            value: c['curso_id'] as String,
                            child: Text(c['identificador_division'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCursoId = val);
                            _cargarAlumnos(val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Buscador
                      TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nombre o DNI...',
                          prefixIcon: Icon(Icons.search_rounded),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: _filtrarAlumnos,
                      ),
                      const SizedBox(height: 16),
                      
                      const Text('Alumnos y Boletines',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),

                      Expanded(
                        child: _loadingAlumnos
                            ? const Center(child: CircularProgressIndicator())
                            : _alumnosFiltrados.isEmpty
                                ? const Center(child: Text('No se encontraron alumnos.'))
                                : ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: _alumnosFiltrados.length,
                                    itemBuilder: (context, index) {
                                      final al = _alumnosFiltrados[index];
                                      return Card(
                                        elevation: 0,
                                        margin: const EdgeInsets.only(bottom: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(
                                              color: colorScheme.outlineVariant.withAlpha(80)),
                                        ),
                                        child: ListTile(
                                          onTap: () => _abrirVistaPreviaBoletin(al),
                                          leading: Icon(Icons.picture_as_pdf_rounded,
                                              color: Colors.red.shade700),
                                          title: Text(al['nombre'] as String,
                                              style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('DNI: ${al['dni']}'),
                                          trailing: ElevatedButton.icon(
                                            onPressed: () => _abrirVistaPreviaBoletin(al),
                                            icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                                            label: const Text('Ver Boletín', style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
                if (_generatingBoletin)
                  Container(
                    color: Colors.black.withAlpha(50),
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Generando Boletín PDF...',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
