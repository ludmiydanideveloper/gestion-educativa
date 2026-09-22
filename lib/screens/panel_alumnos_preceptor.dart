import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../services/print_helper.dart';

class PanelAlumnosPreceptor extends StatefulWidget {
  final String? cursoIdInicial;
  const PanelAlumnosPreceptor({super.key, this.cursoIdInicial});

  @override
  State<PanelAlumnosPreceptor> createState() => _PanelAlumnosPreceptorState();
}

class _PanelAlumnosPreceptorState extends State<PanelAlumnosPreceptor> {
  final _service = SupabaseService();
  bool _loadingCursos = true;
  bool _loadingAlumnos = false;
  
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
      // Obtener detalles adicionales de legajos si es necesario
      // Para mostrar el DNI de cada alumno, consultamos la tabla usr_legajo_alumno
      // fetchAlumnos ya trae el nombre resuelto. Consultemos los legajos del curso:
      final response = await _service.fetchAlumnosList();
      
      // Filtrar y cruzar por ID
      final List<Map<String, dynamic>> listCompleta = [];
      
      for (final a in list) {
        final ext = response.firstWhere(
          (element) => element['legajo_id'] == a.id,
          orElse: () => {},
        );
        final Map<String, dynamic> demo = Map<String, dynamic>.from(ext['datos_demograficos'] as Map? ?? {});
        listCompleta.add({
          'id': a.id,
          'nombre': a.nombre,
          'dni': ext['dni'] ?? 'DNI No cargado',
          'fecha_nacimiento': ext['fecha_nacimiento'] ?? '15/05/2010',
          'genero': ext['genero'] ?? 'No especificado',
          'adecuacion_curricular': demo['adecuacion_curricular'] == true,
          'tipo_adecuacion': demo['tipo_adecuacion'] ?? '',
          'detalles_adecuacion': demo['detalles_adecuacion'] ?? '',
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

  void _abrirFichaTrayectoria(Map<String, dynamic> alumno) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FichaTrayectoriaSheet(alumno: alumno),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ficha y Trayectoria del Alumno',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loadingCursos
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                  
                  const Text('Alumnos Registrados',
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
                                      leading: CircleAvatar(
                                        backgroundColor: colorScheme.primary.withAlpha(20),
                                        child: Text(
                                          al['nombre'].substring(0, 1).toUpperCase(),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary),
                                        ),
                                      ),
                                      title: Text(al['nombre'] as String,
                                          style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('DNI: ${al['dni']}'),
                                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                                          size: 16, color: colorScheme.primary),
                                      onTap: () => _abrirFichaTrayectoria(al),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FichaTrayectoriaSheet extends StatefulWidget {
  final Map<String, dynamic> alumno;
  const _FichaTrayectoriaSheet({required this.alumno});

  @override
  State<_FichaTrayectoriaSheet> createState() => _FichaTrayectoriaSheetState();
}

class _FichaTrayectoriaSheetState extends State<_FichaTrayectoriaSheet> {
  final _service = SupabaseService();
  bool _loading = true;
  
  List<Map<String, dynamic>> _asistencia = [];
  List<Map<String, dynamic>> _conducta = [];
  // Trayectoria real (acad_trayectoria_alumno / acad_materias_adeudadas):
  // la misma fuente que usa el PDF Analítico oficial en el panel de admin.
  List<Map<String, dynamic>> _trayectoria = [];
  List<Map<String, dynamic>> _materiasAdeudadas = [];
  bool _subiendoCertificado = false;

  void _editarAdecuacionDialog(Map<String, dynamic> al) {
    final formKey = GlobalKey<FormState>();
    bool activa = al['adecuacion_curricular'] == true;
    String tipo = al['tipo_adecuacion'] ?? 'Metodológica';
    final detallesCtrl = TextEditingController(text: al['detalles_adecuacion'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Adecuación Curricular', style: TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text('Tiene adecuación activa', style: TextStyle(fontWeight: FontWeight.w600)),
                        value: activa,
                        onChanged: (val) => setModalState(() => activa = val),
                      ),
                      if (activa) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: tipo.isEmpty ? 'Metodológica' : tipo,
                          decoration: const InputDecoration(labelText: 'Tipo de Adecuación', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Metodológica', child: Text('Metodológica')),
                            DropdownMenuItem(value: 'De Acceso', child: Text('De Acceso')),
                            DropdownMenuItem(value: 'De Contenido', child: Text('De Contenido')),
                          ],
                          onChanged: (val) => setModalState(() => tipo = val ?? 'Metodológica'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: detallesCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Detalles / Pautas de Adaptación',
                            hintText: 'ej. Tiempos extendidos en exámenes, ubicación al frente...',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese detalles' : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (activa && !formKey.currentState!.validate()) return;
                          setModalState(() => isSaving = true);
                          try {
                            await _service.actualizarAdecuacionCurricular(
                              alumnoId: al['id'] as String,
                              activa: activa,
                              tipo: activa ? tipo : '',
                              detalles: activa ? detallesCtrl.text.trim() : '',
                            );
                            
                            // Actualizar localmente el mapa del alumno
                            setState(() {
                              al['adecuacion_curricular'] = activa;
                              al['tipo_adecuacion'] = activa ? tipo : '';
                              al['detalles_adecuacion'] = activa ? detallesCtrl.text.trim() : '';
                            });

                            Navigator.of(context).pop();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Adecuación curricular actualizada con éxito'), backgroundColor: Colors.green),
                            );
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al actualizar adecuación: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Sube el certificado/justificativo para una inasistencia puntual
  /// (asistencia_detalle_id) y la marca JUSTIFICADO.
  Future<void> _subirCertificado(Map<String, dynamic> item) async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    final f = res.files.first;
    setState(() => _subiendoCertificado = true);
    try {
      await _service.subirCertificadoAusencia(
        asistenciaDetalleId: item['asistencia_detalle_id'].toString(),
        bytes: f.bytes!,
        fileName: f.name,
      );
      setState(() {
        item['estado_justificacion'] = 'JUSTIFICADO';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificado subido y ausencia justificada.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir certificado: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoCertificado = false);
    }
  }

  Future<void> _verCertificado(Map<String, dynamic> item) async {
    final path = item['url_certificado']?.toString();
    if (path == null || path.isEmpty) return;
    try {
      final url = await _service.urlFirmadaStorage('certificados', path);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir certificado: $e')),
        );
      }
    }
  }

  Widget _buildAdecuacionCard(Map<String, dynamic> al, ColorScheme colorScheme) {
    final tieneAdecuacion = al['adecuacion_curricular'] == true;
    final tipo = al['tipo_adecuacion'] ?? '';
    final detalles = al['detalles_adecuacion'] ?? '';

    return Card(
      elevation: 0,
      color: tieneAdecuacion ? Colors.indigo.shade50 : colorScheme.surfaceVariant.withAlpha(40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: tieneAdecuacion ? Colors.indigo.shade200 : colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              tieneAdecuacion ? Icons.accessibility_new_rounded : Icons.info_outline_rounded,
              color: tieneAdecuacion ? Colors.indigo.shade800 : colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tieneAdecuacion ? 'Adecuación Curricular Activa ($tipo)' : 'Sin Adecuación Curricular',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tieneAdecuacion ? Colors.indigo.shade900 : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                  if (tieneAdecuacion) ...[
                    const SizedBox(height: 4),
                    Text(
                      detalles,
                      style: TextStyle(color: Colors.indigo.shade900, fontSize: 12, height: 1.3),
                    ),
                  ] else ...[
                    const SizedBox(height: 2),
                    const Text(
                      'El alumno no registra adaptaciones especiales de aprendizaje.',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_rounded, color: tieneAdecuacion ? Colors.indigo.shade800 : Colors.grey, size: 20),
              tooltip: 'Editar Adecuación',
              onPressed: () => _editarAdecuacionDialog(al),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    try {
      final alumnoId = widget.alumno['id'] as String;
      final results = await Future.wait([
        _service.obtenerAsistenciaAlumno(alumnoId),
        Supabase.instance.client
            .from('aca_conducta')
            .select('*, acad_materias (nombre_asignatura)')
            .eq('alumno_id', alumnoId),
        Supabase.instance.client
            .from('acad_trayectoria_alumno')
            .select('*')
            .eq('alumno_id', alumnoId)
            .order('anio_lectivo'),
        Supabase.instance.client
            .from('acad_materias_adeudadas')
            .select('*')
            .eq('alumno_id', alumnoId)
            .order('anio_origen'),
      ]);

      setState(() {
        _asistencia = List<Map<String, dynamic>>.from(results[0]);
        _conducta = List<Map<String, dynamic>>.from(results[1]);
        _trayectoria = List<Map<String, dynamic>>.from(results[2]);
        _materiasAdeudadas = List<Map<String, dynamic>>.from(results[3]);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error al cargar historial: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _recargarTrayectoria() async {
    final alumnoId = widget.alumno['id'] as String;
    final results = await Future.wait([
      Supabase.instance.client
          .from('acad_trayectoria_alumno')
          .select('*')
          .eq('alumno_id', alumnoId)
          .order('anio_lectivo'),
      Supabase.instance.client
          .from('acad_materias_adeudadas')
          .select('*')
          .eq('alumno_id', alumnoId)
          .order('anio_origen'),
    ]);
    if (!mounted) return;
    setState(() {
      _trayectoria = List<Map<String, dynamic>>.from(results[0]);
      _materiasAdeudadas = List<Map<String, dynamic>>.from(results[1]);
    });
  }

  /// % de ciclos lectivos aprobados sobre el total cargado en la trayectoria
  /// real (acad_trayectoria_alumno). Sin datos cargados, no hay progreso que
  /// mostrar — nada de inventar un número.
  double? get _progresoAcademico {
    if (_trayectoria.isEmpty) return null;
    final aprobados = _trayectoria.where((t) => (t['condicion'] ?? '') == 'APROBADO').length;
    return aprobados / _trayectoria.length;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalFaltas = _asistencia.fold<double>(
        0.0, (sum, item) => sum + (item['valor_inasistencia'] as num? ?? 0.0).toDouble());
    final progreso = _progresoAcademico;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Nombre y datos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.alumno['nombre'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'DNI: ${widget.alumno['dni']} • Género: ${widget.alumno['genero']}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.print_rounded, color: Colors.blueGrey),
                tooltip: 'Imprimir Ficha',
                onPressed: () {
                  final totalFaltas = _asistencia.fold<double>(
                      0.0, (sum, item) => sum + (item['valor_inasistencia'] as num? ?? 0.0).toDouble());
                  
                  final asistRows = _asistencia.map((item) {
                    final cab = item['asistencia_cabecera'] as Map<String, dynamic>?;
                    final fecha = cab?['fecha'] as String? ?? 'Fecha';
                    final tipo = item['tipo'] as String? ?? 'PRESENTE';
                    final valor = item['valor_inasistencia'] as num? ?? 0.0;
                    return '<tr><td>$fecha</td><td>$tipo</td><td>$valor</td></tr>';
                  }).join('');

                  final condRows = _conducta.map((item) {
                    return '<tr><td>${item['fecha'] ?? "-"}</td><td>${item['tipo_incidencia'] ?? "-"}</td><td>${item['descripcion'] ?? "-"}</td></tr>';
                  }).join('');

                  final certRows = _asistencia
                      .where((item) => (item['estado_justificacion'] ?? 'NINGUNO') != 'NINGUNO')
                      .map((item) {
                    final cab = item['asistencia_cabecera'] as Map<String, dynamic>?;
                    final fecha = cab?['fecha'] as String? ?? 'Fecha';
                    return '<tr><td>$fecha</td><td>${item['tipo'] ?? "-"}</td><td>${item['estado_justificacion'] ?? "-"}</td></tr>';
                  }).join('');

                  final htmlContent = '''
                    <h2>Ficha de Trayectoria Educativa: ${widget.alumno['nombre']}</h2>
                    <p><strong>DNI:</strong> ${widget.alumno['dni']} | <strong>Género:</strong> ${widget.alumno['genero']}</p>
                    <p><strong>Progreso Académico:</strong> ${progreso != null ? '${(progreso * 100).toStringAsFixed(0)}%' : 'Sin datos de trayectoria cargados'}</p>
                    <p><strong>Total Inasistencias:</strong> ${totalFaltas.toStringAsFixed(2)} faltas</p>
                    
                    <h3 style="margin-top:24px;">Historial de Inasistencias</h3>
                    <table>
                      <thead>
                        <tr><th>Fecha</th><th>Tipo</th><th>Valor</th></tr>
                      </thead>
                      <tbody>
                        ${asistRows.isEmpty ? '<tr><td colspan="3">Sin inasistencias</td></tr>' : asistRows}
                      </tbody>
                    </table>

                    <h3 style="margin-top:24px;">Historial Disciplinario / Conducta</h3>
                    <table>
                      <thead>
                        <tr><th>Fecha</th><th>Tipo</th><th>Descripción</th></tr>
                      </thead>
                      <tbody>
                        ${condRows.isEmpty ? '<tr><td colspan="3">Sin sanciones</td></tr>' : condRows}
                      </tbody>
                    </table>

                    <h3 style="margin-top:24px;">Certificados Médicos</h3>
                    <table>
                      <thead>
                        <tr><th>Fecha</th><th>Título</th><th>Estado</th></tr>
                      </thead>
                      <tbody>
                        ${certRows.isEmpty ? '<tr><td colspan="3">Sin certificados</td></tr>' : certRows}
                      </tbody>
                    </table>
                  ''';

                  PrintHelper.imprimirHTML(
                    titulo: 'Ficha de Trayectoria - IA Baradero',
                    htmlContentBody: htmlContent,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra de Progreso del Proceso Académico — real, en base a
          // acad_trayectoria_alumno (ciclos aprobados / ciclos cargados).
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progreso del Proceso Académico:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
              ),
              Text(
                progreso != null ? '${(progreso * 100).toStringAsFixed(0)}%' : 'Sin datos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progreso ?? 0,
            backgroundColor: Colors.grey.shade200,
            color: colorScheme.primary,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const Divider(height: 24),
          _buildAdecuacionCard(widget.alumno, colorScheme),
          const SizedBox(height: 12),

          _loading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: DefaultTabController(
                    length: 5,
                    child: Column(
                      children: [
                        TabBar(
                          labelColor: colorScheme.primary,
                          unselectedLabelColor: colorScheme.onSurfaceVariant,
                          indicatorColor: colorScheme.primary,
                          isScrollable: true,
                          tabs: const [
                            Tab(icon: Icon(Icons.school_rounded), text: 'Boletín Trayectoria'),
                            Tab(icon: Icon(Icons.analytics_rounded), text: 'Asistencias'),
                            Tab(icon: Icon(Icons.gavel_rounded), text: 'Sanciones'),
                            Tab(icon: Icon(Icons.today_rounded), text: 'Conducta Diaria'),
                            Tab(icon: Icon(Icons.medical_services_rounded), text: 'Certificados'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Pestaña 1: Boletín y Trayectoria Histórica (Ficticio / Modelo)
                              _buildBoletinTrayectoriaTab(colorScheme),

                              // Pestaña 2: Asistencias
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer.withAlpha(40),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: colorScheme.primary.withAlpha(51)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Inasistencias Acumuladas:',
                                            style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text(
                                          '${totalFaltas.toStringAsFixed(2)} faltas',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: totalFaltas > 15 ? Colors.red : colorScheme.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Historial de Inasistencias:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: _asistencia.isEmpty
                                        ? const Center(child: Text('Sin faltas registradas.'))
                                        : ListView.builder(
                                            physics: const BouncingScrollPhysics(),
                                            itemCount: _asistencia.length,
                                            itemBuilder: (context, index) {
                                              final item = _asistencia[index];
                                              final cab = item['asistencia_cabecera'] as Map<String, dynamic>?;
                                              final fecha = cab?['fecha'] as String? ?? 'Fecha';
                                              final tipo = item['tipo'] as String? ?? 'PRESENTE';
                                              final valor = item['valor_inasistencia'] as num? ?? 0.0;
                                              final materia = (cab?['acad_materias'] as Map?)?['nombre_asignatura']
                                                  as String?;

                                              if (tipo == 'PRESENTE') return const SizedBox();

                                              return Card(
                                                elevation: 0,
                                                margin: const EdgeInsets.only(bottom: 6),
                                                color: Colors.red.shade50.withAlpha(127),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  side: BorderSide(color: Colors.red.shade100),
                                                ),
                                                child: ListTile(
                                                  leading: const Icon(Icons.cancel_rounded, color: Colors.red),
                                                  title: Text(tipo),
                                                  subtitle: Text(materia != null && materia.isNotEmpty
                                                      ? 'Fecha: $fecha · $materia'
                                                      : 'Fecha: $fecha'),
                                                  trailing: Text('+$valor',
                                                      style: const TextStyle(
                                                          color: Colors.red, fontWeight: FontWeight.bold)),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
 
                              // Pestaña Sanciones / Disciplina
                              _buildSancionesTab(colorScheme),
 
                              // Pestaña Conducta Diaria
                              _buildConductaDiariaTab(colorScheme),

                              // Pestaña Certificados Médicos: uno por inasistencia real
                              // (asistencia_detalle.url_certificado / estado_justificacion),
                              // no una lista aparte inventada.
                              _buildCertificadosTab(colorScheme),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// Alta de un ciclo lectivo cursado (acad_trayectoria_alumno) — misma tabla
  /// real que gestiona el panel de administración para el PDF Analítico.
  Future<void> _agregarAnioTrayectoria() async {
    final anioCtrl = TextEditingController(text: (DateTime.now().year - 1).toString());
    final cursoCtrl = TextEditingController();
    final promCtrl = TextEditingController();
    String cond = 'APROBADO';

    await showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Registrar Año Cursado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: anioCtrl, decoration: const InputDecoration(labelText: 'Año lectivo (ej. 2024)'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: cursoCtrl, decoration: const InputDecoration(labelText: 'Curso / división (ej. 1° A)')),
              const SizedBox(height: 10),
              TextField(controller: promCtrl, decoration: const InputDecoration(labelText: 'Promedio general (ej. 8.50)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: cond,
                decoration: const InputDecoration(labelText: 'Condición final'),
                items: const [
                  DropdownMenuItem(value: 'APROBADO', child: Text('Aprobado')),
                  DropdownMenuItem(value: 'EN_CURSO', child: Text('En curso')),
                  DropdownMenuItem(value: 'ADEUDA_MATERIAS', child: Text('Adeuda materias')),
                ],
                onChanged: (v) => setD(() => cond = v ?? cond),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (cursoCtrl.text.trim().isEmpty) return;
                try {
                  await Supabase.instance.client.from('acad_trayectoria_alumno').insert({
                    'alumno_id': widget.alumno['id'],
                    'anio_lectivo': int.tryParse(anioCtrl.text) ?? DateTime.now().year,
                    'curso_nombre': cursoCtrl.text.trim(),
                    'promedio': double.tryParse(promCtrl.text.replaceAll(',', '.')),
                    'condicion': cond,
                  });
                  if (dCtx.mounted) Navigator.pop(dCtx);
                  await _recargarTrayectoria();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarTrayectoria(Map<String, dynamic> t) async {
    await Supabase.instance.client.from('acad_trayectoria_alumno').delete().eq('id', t['id']);
    await _recargarTrayectoria();
  }

  /// Alta de una materia pendiente para Comisión RITE (acad_materias_adeudadas).
  Future<void> _agregarMateriaAdeudada() async {
    final matCtrl = TextEditingController();
    final anioCtrl = TextEditingController(text: (DateTime.now().year - 1).toString());
    // Códigos reales del CHECK de la tabla — ver SupabaseService.labelCondicionAdeudada.
    String cond = SupabaseService.kCondicionIntensifica;

    await showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Registrar Materia para Comisión RITE'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: matCtrl, decoration: const InputDecoration(labelText: 'Nombre de la materia')),
              const SizedBox(height: 10),
              TextField(controller: anioCtrl, decoration: const InputDecoration(labelText: 'Año en que se cursó')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: cond,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Condición RITE'),
                items: [
                  DropdownMenuItem(
                      value: SupabaseService.kCondicionIntensifica,
                      child: Text(SupabaseService.labelCondicionAdeudada(SupabaseService.kCondicionIntensifica))),
                  DropdownMenuItem(
                      value: SupabaseService.kCondicionRecursa,
                      child: Text(SupabaseService.labelCondicionAdeudada(SupabaseService.kCondicionRecursa))),
                  DropdownMenuItem(
                      value: SupabaseService.kCondicionPreviaLibre,
                      child: Text(SupabaseService.labelCondicionAdeudada(SupabaseService.kCondicionPreviaLibre))),
                ],
                onChanged: (v) => setD(() => cond = v ?? cond),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Para vincularla a una materia real del plan de estudios (y que el '
                  'docente titular pueda cargar coloquios o notas), usá el módulo RITE.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (matCtrl.text.trim().isEmpty) return;
                try {
                  await _service.crearMateriaAdeudada(
                    alumnoId: widget.alumno['id'] as String,
                    materiaOriginalId: '',
                    nombreMateria: matCtrl.text.trim(),
                    anioOrigen: int.tryParse(anioCtrl.text) ?? DateTime.now().year,
                    condicion: cond,
                  );
                  if (dCtx.mounted) Navigator.pop(dCtx);
                  await _recargarTrayectoria();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarMateriaAdeudada(Map<String, dynamic> m) async {
    await _service.eliminarMateriaAdeudadaReal(m['adeudada_id'].toString());
    await _recargarTrayectoria();
  }

  Widget _buildBoletinTrayectoriaTab(ColorScheme colorScheme) {
    final promedios = _trayectoria
        .map((t) => double.tryParse(t['promedio']?.toString() ?? ''))
        .whereType<double>()
        .toList();
    final promedioGeneral = promedios.isEmpty ? null : promedios.reduce((a, b) => a + b) / promedios.length;
    final aprobadas = _trayectoria.where((t) => (t['condicion'] ?? '') == 'APROBADO').length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner destacado con opción de impresión
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primaryContainer.withAlpha(150), colorScheme.secondaryContainer.withAlpha(100)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.primary.withAlpha(80)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Boletín Curricular y Analítico Histórico',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Trayectoria real cargada por Dirección (RITE Provincial)',
                            style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: _trayectoria.isEmpty
                          ? null
                          : () {
                              PrintHelper.imprimirTrayectoriaYAnalitico(
                                studentName: widget.alumno['nombre'] ?? 'ALUMNO',
                                dni: widget.alumno['dni']?.toString() ?? 'Sin DNI',
                                cursoActual: _trayectoria.isNotEmpty
                                    ? (_trayectoria.last['curso_nombre'] ?? '').toString()
                                    : '',
                                trayectoria: _trayectoria,
                                materiasAdeudadas: _materiasAdeudadas,
                              );
                            },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Imprimir PDF Analítico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cards de Resumen Histórico — sólo con lo que hay datos reales cargados.
          Row(
            children: [
              Expanded(
                child: _buildResumenCard('Promedio General', promedioGeneral?.toStringAsFixed(2) ?? 'Sin datos',
                    Icons.star_rounded, Colors.amber.shade800),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildResumenCard(
                    'Ciclos Aprobados',
                    _trayectoria.isEmpty ? 'Sin datos' : '$aprobadas / ${_trayectoria.length}',
                    Icons.check_circle_rounded,
                    Colors.green.shade800),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildResumenCard('Materias Pendientes', '${_materiasAdeudadas.length}',
                    Icons.pending_actions_rounded, Colors.blue.shade800),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Historial de Promoción por Ciclo Lectivo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              TextButton.icon(
                onPressed: _agregarAnioTrayectoria,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: const Text('Agregar año', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_trayectoria.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: const Text('Todavía no se cargó el historial de ciclos lectivos de este alumno.',
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _trayectoria.length,
              itemBuilder: (context, index) {
                final t = _trayectoria[index];
                final condicion = (t['condicion'] ?? 'APROBADO').toString();
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 6),
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: colorScheme.primary.withAlpha(25),
                      child: Text('${t['anio_lectivo'] ?? '-'}',
                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    title: Text(t['curso_nombre']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t['promedio'] != null ? 'Prom: ${t['promedio']}' : 'Sin promedio',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: condicion == 'APROBADO' ? Colors.green.shade100 : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            condicion,
                            style: TextStyle(
                              color: condicion == 'APROBADO' ? Colors.green.shade800 : Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                          onPressed: () => _eliminarTrayectoria(t),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Materias Adeudadas / Comisión RITE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              TextButton.icon(
                onPressed: _agregarMateriaAdeudada,
                icon: const Icon(Icons.add_task_rounded, size: 16),
                label: const Text('Agregar materia', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_materiasAdeudadas.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.green.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withAlpha(60))),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green),
                  SizedBox(width: 10),
                  Expanded(child: Text('El alumno no registra materias adeudadas.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 36,
                    headingRowColor: WidgetStateProperty.all(colorScheme.surfaceVariant.withAlpha(80)),
                    columns: const [
                      DataColumn(label: Text('Materia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Año origen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Condición', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('')),
                    ],
                    rows: _materiasAdeudadas.map((m) {
                      final aprobada = (m['estado'] ?? '') == 'APROBADA';
                      return DataRow(cells: [
                        DataCell(Text(m['nombre_materia']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                        DataCell(Text('${m['anio_origen'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                        DataCell(Text(SupabaseService.labelCondicionAdeudada(m['condicion']?.toString()), style: const TextStyle(fontSize: 12))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: aprobada ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(m['estado']?.toString() ?? 'PENDIENTE',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: aprobada ? Colors.green.shade800 : Colors.orange.shade900)),
                          ),
                        ),
                        DataCell(IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                          onPressed: () => _eliminarMateriaAdeudada(m),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildResumenCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildSancionesTab(ColorScheme colorScheme) {
    final listIncidencias = _conducta.where((item) {
      final tipo = (item['tipo_incidencia'] ?? '').toString().toLowerCase();
      final desc = (item['descripcion'] ?? '').toString().toLowerCase();
      return tipo != 'bien' && tipo != 'más o menos' && tipo != 'mal' && !desc.contains('conducta diaria:');
    }).toList();

    if (listIncidencias.isEmpty) {
      return const Center(child: Text('Sin sanciones o reportes de disciplina.'));
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: listIncidencias.length,
      itemBuilder: (context, index) {
        final item = listIncidencias[index];
        final tipo = item['tipo_incidencia'] as String? ?? 'General';
        final sev = item['severidad'] as String? ?? 'Leve';
        final desc = item['descripcion'] as String? ?? '';
        final fecha = (item['fecha'] as String?)?.substring(0, 10) ?? 'Sin fecha';

        Color colorSev = Colors.blue;
        if (sev == 'Grave') colorSev = Colors.orange;
        if (sev == 'Gravísima') colorSev = Colors.red;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tipo, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorSev.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sev,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorSev),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text('Fecha: $fecha',
                    style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConductaDiariaTab(ColorScheme colorScheme) {
    final listDiaria = _conducta.where((item) {
      final tipo = (item['tipo_incidencia'] ?? '').toString().toLowerCase();
      final desc = (item['descripcion'] ?? '').toString().toLowerCase();
      return tipo == 'bien' || tipo == 'más o menos' || tipo == 'mal' || desc.contains('conducta diaria:');
    }).toList();

    if (listDiaria.isEmpty) {
      return const Center(child: Text('Sin registros de conducta diaria en clase.'));
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: listDiaria.length,
      itemBuilder: (context, index) {
        final item = listDiaria[index];
        final tipo = item['tipo_incidencia'] as String? ?? 'Bien';
        final desc = item['descripcion'] as String? ?? '';
        final fecha = (item['fecha'] as String?)?.substring(0, 10) ?? 'Sin fecha';
        final materia = (item['acad_materias'] as Map?)?['nombre_asignatura'] as String?;

        Color badgeColor = Colors.green;
        if (tipo.toLowerCase() == 'mal') badgeColor = Colors.red;
        if (tipo.toLowerCase().contains('menos')) badgeColor = Colors.orange;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tipo.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor),
                      ),
                    ),
                    Text(
                      fecha,
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(fontSize: 13)),
                if (materia != null && materia.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 13, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(materia,
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.primary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCertificadosTab(ColorScheme colorScheme) {
    final ausencias = _asistencia.where((item) => (item['tipo'] ?? 'PRESENTE') != 'PRESENTE').toList();

    if (ausencias.isEmpty) {
      return const Center(
        child: Text('Sin inasistencias registradas para este alumno.',
            style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
      );
    }

    Color colorEstado(String estado) {
      switch (estado) {
        case 'JUSTIFICADO':
          return Colors.green;
        case 'PENDIENTE_CERTIFICADO_MEDICO':
          return Colors.orange;
        case 'RECHAZADO':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    String labelEstado(String estado) {
      switch (estado) {
        case 'JUSTIFICADO':
          return 'Justificado';
        case 'PENDIENTE_CERTIFICADO_MEDICO':
          return 'Pendiente';
        case 'RECHAZADO':
          return 'Rechazado';
        default:
          return 'Sin certificado';
      }
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: ausencias.length,
      itemBuilder: (context, index) {
        final item = ausencias[index];
        final cab = item['asistencia_cabecera'] as Map<String, dynamic>?;
        final fecha = cab?['fecha'] as String? ?? 'Fecha';
        final tipo = item['tipo'] as String? ?? 'AUSENTE';
        final materia = (cab?['acad_materias'] as Map?)?['nombre_asignatura'] as String?;
        final estado = (item['estado_justificacion'] ?? 'NINGUNO') as String;
        final tieneCertificado = (item['url_certificado'] ?? '').toString().isNotEmpty;
        final color = colorEstado(estado);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          color: color.withAlpha(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withAlpha(80)),
          ),
          child: ListTile(
            leading: Icon(Icons.verified_user_rounded, color: color, size: 24),
            title: Text(
              materia != null && materia.isNotEmpty ? '$tipo · $materia' : tipo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            subtitle: Text('Fecha: $fecha'),
            trailing: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    labelEstado(estado),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                if (tieneCertificado)
                  TextButton.icon(
                    onPressed: () => _verCertificado(item),
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('Ver', style: TextStyle(fontSize: 12)),
                  )
                else
                  TextButton.icon(
                    onPressed: _subiendoCertificado ? null : () => _subirCertificado(item),
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('Subir', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
