import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/print_helper.dart';

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

  Future<void> _imprimirBoletin(Map<String, dynamic> alumno) async {
    if (_selectedCursoId == null) return;
    
    setState(() => _generatingBoletin = true);
    try {
      final alumnoId = alumno['id'] as String;
      
      final results = await Future.wait([
        _service.obtenerCategoriasCalificaciones(),
        _service.obtenerCalificacionesAlumno(alumnoId),
        _service.fetchMaterias(cursoId: _selectedCursoId!),
      ]);

      PrintHelper.imprimirBoletin(
        studentName: alumno['nombre'] ?? '',
        dni: alumno['dni']?.toString() ?? '',
        cursoName: alumno['curso_nombre'] ?? 'Sin curso',
        categorias: results[0] as List<Map<String, dynamic>>,
        calificaciones: results[1] as List<Map<String, dynamic>>,
        materias: results[2] as List<Map<String, dynamic>>,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Boletín RITE generado con éxito.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al generar boletín: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar boletín: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _generatingBoletin = false);
    }
  }

  String _obtenerProfesor(String materiaName) {
    final cleanMateria = materiaName.trim().toLowerCase();
    if (cleanMateria.contains('historia sagrada')) return 'Daniel Gomez';
    if (cleanMateria.contains('lenguaje') || cleanMateria.contains('prácticas del lenguaje')) return 'Jenica Romero';
    if (cleanMateria.contains('naturales')) return 'Danilo Gomez';
    if (cleanMateria.contains('física') || cleanMateria.contains('educación física')) return 'Julio Lesson';
    if (cleanMateria.contains('ciudadanía') || cleanMateria.contains('construcción de la ciudadanía')) return 'Maria Funes';
    if (cleanMateria.contains('matemática')) return 'Florencia Viero';
    return 'Docente Asignado';
  }

  void _abrirVistaPreviaBoletin(Map<String, dynamic> alumno) {
    final alumnoId = alumno['id'] as String;

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assignment_rounded, color: colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Vista Previa del Boletín', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 700,
            child: FutureBuilder<List<dynamic>>(
              future: Future.wait([
                _service.obtenerCategoriasCalificaciones(),
                _service.obtenerCalificacionesAlumno(alumnoId),
                _service.fetchMaterias(cursoId: _selectedCursoId!),
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
                    child: Center(child: Text('Error al cargar calificaciones.')),
                  );
                }

                final categorias = snapshot.data![0] as List<Map<String, dynamic>>;
                final calificaciones = snapshot.data![1] as List<Map<String, dynamic>>;
                final materias = snapshot.data![2] as List<Map<String, dynamic>>;

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (alumno['nombre'] as String).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text('DNI: ${alumno['dni']}  |  Curso: ${alumno['curso_nombre']}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tabla
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          columns: [
                            const DataColumn(label: Text('Materia', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('Profesor', style: TextStyle(fontWeight: FontWeight.bold))),
                            ...categorias.map((cat) {
                              return DataColumn(
                                label: Text(
                                  cat['nombre_categoria'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              );
                            }),
                          ],
                          rows: materias.map((mat) {
                            final matId = mat['materia_id'] as String;
                            final matName = mat['nombre_asignatura'] as String;

                            return DataRow(
                              cells: [
                                DataCell(Text(matName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(_obtenerProfesor(matName), style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12))),
                                ...categorias.map((cat) {
                                  final catId = cat['categoria_id'] as String;
                                  final cal = calificaciones.firstWhere(
                                    (c) => c['materia_id'] == matId && c['categoria_id'] == catId,
                                    orElse: () => {},
                                  );
                                  final nota = cal['nota_valor']?.toString() ?? '-';
                                  return DataCell(Center(child: Text(nota)));
                                }),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
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
              onPressed: () {
                Navigator.of(context).pop();
                _imprimirBoletin(alumno);
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Descargar Boletín Oficial (PDF)'),
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
