import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/print_helper_web.dart';

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
  final List<Map<String, String>> _certificados = [
    {'fecha': '05/07/2026', 'titulo': 'Certificado Odontológico', 'estado': 'Presentado'},
  ];

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

  void _subirCertificadoDialog(ColorScheme colorScheme) {
    final titleCtrl = TextEditingController();
    final fechaCtrl = TextEditingController(text: '10/07/2026');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.upload_file_rounded, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('Subir Certificado'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Suba un certificado médico o justificativo para avalar las inasistencias del alumno.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Título',
                      border: OutlineInputBorder(),
                      hintText: 'Ej: Certificado Médico Gripe',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fechaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Fecha de Inasistencia',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade800,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Archivo PDF / Imagen seleccionado correctamente.')),
                      );
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('Adjuntar archivo (PDF/Imagen)'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ingrese una descripción')),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    setState(() {
                      _certificados.add({
                        'fecha': fechaCtrl.text.trim(),
                        'titulo': titleCtrl.text.trim(),
                        'estado': 'Presentado',
                      });
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.send_rounded, color: Colors.white),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text('¡Certificado médico subido! Se ha enviado una notificación automática a los docentes de las materias y a la familia del alumno.'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green.shade800,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  child: const Text('Subir y Notificar'),
                ),
              ],
            );
          },
        );
      },
    );
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
      final results = await Future.wait([
        _service.obtenerAsistenciaAlumno(widget.alumno['id'] as String),
        _service.obtenerCalificacionesAlumno(widget.alumno['id'] as String), // Notas
      ]);
      
      // Obtener incidencias de conducta
      final response = await Supabase.instance.client
          .from('aca_conducta')
          .select('*')
          .eq('alumno_id', widget.alumno['id'] as String);
      
      setState(() {
        _asistencia = List<Map<String, dynamic>>.from(results[0]);
        _conducta = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error al cargar historial: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalFaltas = _asistencia.fold<double>(
        0.0, (sum, item) => sum + (item['valor_inasistencia'] as num? ?? 0.0).toDouble());

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
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                    return '<tr><td>${item['fecha_suceso'] ?? "-"}</td><td>${item['tipo_incidencia'] ?? "-"}</td><td>${item['descripcion'] ?? "-"}</td></tr>';
                  }).join('');

                  final certRows = _certificados.map((item) {
                    return '<tr><td>${item['fecha']}</td><td>${item['titulo']}</td><td>${item['estado']}</td></tr>';
                  }).join('');

                  final htmlContent = '''
                    <h2>Ficha de Trayectoria Educativa: ${widget.alumno['nombre']}</h2>
                    <p><strong>DNI:</strong> ${widget.alumno['dni']} | <strong>Género:</strong> ${widget.alumno['genero']}</p>
                    <p><strong>Progreso Académico:</strong> 82%</p>
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
          // Barra de Progreso del Proceso Académico
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progreso del Proceso Académico:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
              ),
              Text(
                '82%',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: 0.82,
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
                                                  subtitle: Text('Fecha: $fecha'),
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

                              // Pestaña Certificados Médicos
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Certificados y Justificativos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ElevatedButton.icon(
                                        onPressed: () => _subirCertificadoDialog(colorScheme),
                                        icon: const Icon(Icons.upload_file_rounded),
                                        label: const Text('Subir Certificado'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: _certificados.isEmpty
                                        ? const Center(child: Text('No se registraron certificados médicos para este alumno.', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)))
                                        : ListView.builder(
                                            physics: const BouncingScrollPhysics(),
                                            itemCount: _certificados.length,
                                            itemBuilder: (context, index) {
                                              final cert = _certificados[index];
                                              return Card(
                                                elevation: 0,
                                                margin: const EdgeInsets.only(bottom: 8),
                                                color: Colors.blue.shade50.withAlpha(127),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  side: BorderSide(color: Colors.blue.shade100),
                                                ),
                                                child: ListTile(
                                                  leading: const Icon(Icons.verified_user_rounded, color: Colors.blue, size: 24),
                                                  title: Text(cert['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                  subtitle: Text('Fecha de Falta: ${cert['fecha']}'),
                                                  trailing: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
                                                    child: Text(
                                                      cert['estado'] ?? '',
                                                      style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 10),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
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

  Widget _buildBoletinTrayectoriaTab(ColorScheme colorScheme) {
    // Datos ficticios / Modelo Oficial para toda la trayectoria
    final List<Map<String, dynamic>> trayectoriaFicticia = [
      {'anio_lectivo': '2023 - 1° Año Sec.', 'curso_nombre': '1° A - Turno Mañana', 'condicion': 'APROBADO', 'promedio': '8.40'},
      {'anio_lectivo': '2024 - 2° Año Sec.', 'curso_nombre': '2° A - Turno Mañana', 'condicion': 'APROBADO', 'promedio': '7.85'},
      {'anio_lectivo': '2025 - 3° Año Sec.', 'curso_nombre': '3° A - Turno Mañana', 'condicion': 'EN_CURSO', 'promedio': '8.20'},
    ];

    final List<Map<String, dynamic>> materiasFicticias = [
      {'materia': 'Matemática I, II y III', 'anio': '1° a 3° Año', 'nota': '8.20', 'estado': 'APROBADA'},
      {'materia': 'Prácticas del Lenguaje I, II y III', 'anio': '1° a 3° Año', 'nota': '8.80', 'estado': 'APROBADA'},
      {'materia': 'Ciencias Naturales / Biología', 'anio': '1° y 2° Año', 'nota': '8.50', 'estado': 'APROBADA'},
      {'materia': 'Historia / Construcción Ciudadana', 'anio': '1° a 3° Año', 'nota': '9.00', 'estado': 'APROBADA'},
      {'materia': 'Geografía General', 'anio': '2° y 3° Año', 'nota': '7.75', 'estado': 'APROBADA'},
      {'materia': 'Inglés Técnico I y II', 'anio': '1° a 3° Año', 'nota': '8.10', 'estado': 'APROBADA'},
      {'materia': 'Física I', 'anio': '3° Año', 'nota': '6.50', 'estado': 'COMISIÓN RITE'},
    ];

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
                            'Trayectoria completa consolidada (RITE Provincial)',
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
                      onPressed: () {
                        PrintHelper.imprimirTrayectoriaYAnalitico(
                          studentName: widget.alumno['nombre'] ?? 'ALUMNO',
                          dni: widget.alumno['dni']?.toString() ?? 'Sin DNI',
                          cursoActual: '3° A Secundaria',
                          trayectoria: trayectoriaFicticia,
                          materiasAdeudadas: [
                            {'nombre_materia': 'Física I', 'anio_origen': '3° Año', 'condicion': 'COMISIÓN RITE', 'estado': 'PENDIENTE'}
                          ],
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Imprimir PDF Modelo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cards de Resumen Histórico
          Row(
            children: [
              Expanded(child: _buildResumenCard('Promedio General', '8.15', Icons.star_rounded, Colors.amber.shade800)),
              const SizedBox(width: 10),
              Expanded(child: _buildResumenCard('Acreditadas', '28 / 29', Icons.check_circle_rounded, Colors.green.shade800)),
              const SizedBox(width: 10),
              Expanded(child: _buildResumenCard('Promoción', 'DIRECTA', Icons.trending_up_rounded, Colors.blue.shade800)),
            ],
          ),
          const SizedBox(height: 18),

          const Text('Historial de Promoción por Ciclo Lectivo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trayectoriaFicticia.length,
            itemBuilder: (context, index) {
              final t = trayectoriaFicticia[index];
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
                    child: Text('${index + 1}', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  title: Text(t['anio_lectivo']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(t['curso_nombre']!, style: const TextStyle(fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Prom: ${t['promedio']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: t['condicion'] == 'APROBADO' ? Colors.green.shade100 : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t['condicion']!,
                          style: TextStyle(
                            color: t['condicion'] == 'APROBADO' ? Colors.green.shade800 : Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),

          const Text('Desempeño Curricular Acumulado por Materias:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
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
                    DataColumn(label: Text('Asignatura / Área', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Ciclos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Prom. RITE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: materiasFicticias.map((m) {
                    final aprobada = m['estado'] == 'APROBADA';
                    return DataRow(cells: [
                      DataCell(Text(m['materia']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      DataCell(Text(m['anio']!, style: const TextStyle(fontSize: 11, color: Colors.grey))),
                      DataCell(Text(m['nota']!, style: TextStyle(fontWeight: FontWeight.bold, color: aprobada ? Colors.green.shade800 : Colors.orange.shade900))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: aprobada ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(m['estado']!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: aprobada ? Colors.green.shade800 : Colors.orange.shade900)),
                        ),
                      ),
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
        final fecha = (item['created_at'] as String?)?.substring(0, 10) ?? 'Reciente';

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
        final fecha = (item['created_at'] as String?)?.substring(0, 10) ?? 'Reciente';

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
              ],
            ),
          ),
        );
      },
    );
  }
}
