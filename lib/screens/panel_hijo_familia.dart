import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class PanelHijoFamilia extends StatefulWidget {
  final Map<String, dynamic> hijo;
  const PanelHijoFamilia({super.key, required this.hijo});

  @override
  State<PanelHijoFamilia> createState() => _PanelHijoFamiliaState();
}

class _PanelHijoFamiliaState extends State<PanelHijoFamilia> {
  final _service = SupabaseService();
  bool _loading = true;
  
  List<Map<String, dynamic>> _asistencia = [];
  List<Map<String, dynamic>> _calificaciones = [];
  List<Map<String, dynamic>> _conducta = [];
  List<Map<String, dynamic>> _evaluaciones = [];
  List<Map<String, dynamic>> _adeudadas = [];
  List<Map<String, dynamic>> _materias = [];
  List<Map<String, dynamic>> _categorias = [];
  // materia_id → última rúbrica cualitativa cargada por el docente (S/MB/B/R
  // por criterio), la misma fuente real que usa el Boletín Cualitativo del
  // docente y el Informe de Trayectoria de Dirección.
  Map<String, Map<String, dynamic>> _rubricasPorMateria = {};

  @override
  void initState() {
    super.initState();
    _cargarDatosHijo();
  }

  Future<void> _cargarDatosHijo() async {
    final hijoId = widget.hijo['legajo_id'] as String;
    
    // Intentar extraer el curso del hijo
    String? cursoId;
    if (widget.hijo['cursos'] != null && (widget.hijo['cursos'] as List).isNotEmpty) {
      cursoId = widget.hijo['cursos'][0]['curso_id'] as String?;
    }

    try {
      final results = await Future.wait([
        _service.obtenerAsistenciaAlumno(hijoId),
        _service.obtenerCalificacionesAlumno(hijoId),
        _service.obtenerCategoriasCalificaciones(),
        cursoId != null ? _service.fetchMaterias(cursoId: cursoId) : Future.value(<Map<String, dynamic>>[]),
        _service.obtenerCalendarioPorCurso(cursoId),
      ]);
      final rubricasPorMateria = await _service.obtenerRubricasCualitativasPorAlumno(hijoId);

      // Consultar conducta
      final condResp = await Supabase.instance.client
          .from('aca_conducta')
          .select('*')
          .eq('alumno_id', hijoId);

      // Consultar materias adeudadas
      final adeudadasResp = await Supabase.instance.client
          .from('acad_materias_adeudadas')
          .select('*, acad_materias(nombre_asignatura)')
          .eq('alumno_id', hijoId);

      setState(() {
        _asistencia = List<Map<String, dynamic>>.from(results[0]);
        _calificaciones = List<Map<String, dynamic>>.from(results[1]);
        _categorias = List<Map<String, dynamic>>.from(results[2]);
        _materias = List<Map<String, dynamic>>.from(results[3]);
        _evaluaciones = List<Map<String, dynamic>>.from(results[4])
            .where((e) => e['tipo_evento'] == 'EVALUACION')
            .toList();
        _conducta = List<Map<String, dynamic>>.from(condResp);
        _adeudadas = List<Map<String, dynamic>>.from(adeudadasResp);
        _rubricasPorMateria = rubricasPorMateria;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error al cargar datos del hijo: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Ficha de ${widget.hijo['nombre_completo']}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              indicatorColor: colorScheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.analytics_rounded), text: 'Asistencia'),
                Tab(icon: Icon(Icons.assignment_rounded), text: 'Boletín RITE'),
                Tab(icon: Icon(Icons.fact_check_rounded), text: 'Evaluaciones'),
                Tab(icon: Icon(Icons.gavel_rounded), text: 'Convivencia'),
                Tab(icon: Icon(Icons.bookmark_added_rounded), text: 'Adeudadas'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAsistenciasTab(colorScheme),
                  _buildBoletinTab(colorScheme),
                  _buildEvaluacionesTab(colorScheme),
                  _buildConvivenciaTab(colorScheme),
                  _buildAdeudadasTab(colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Asistencias Tab
  Widget _buildAsistenciasTab(ColorScheme colorScheme) {
    final totalFaltas = _asistencia.fold<double>(
        0.0, (sum, item) => sum + (item['valor_inasistencia'] as num? ?? 0.0).toDouble());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
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
                const Text('Inasistencias Totales Acumuladas:',
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
          const SizedBox(height: 16),
          const Text('Historial de Inasistencias',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Expanded(
            child: _asistencia.isEmpty
                ? const Center(child: Text('Sin inasistencias registradas.'))
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
    );
  }

  // 2. Boletín Tab (RITE / Informe de Avance Oficial)
  Widget _buildBoletinTab(ColorScheme colorScheme) {
    if (_materias.isEmpty) {
      return const Center(child: Text('No hay materias cargadas para el curso de este alumno.'));
    }

    final nombreAlumno = '${widget.hijo['apellido'] ?? ''}, ${widget.hijo['nombre'] ?? ''}'.trim();
    final dniAlumno = widget.hijo['dni']?.toString() ?? 'Sin DNI';
    final cursoNombre = (widget.hijo['curso_nombre'] ?? '1° ES').toString();

    // Calcular inasistencias totales
    double totalFaltas = 0;
    for (final a in _asistencia) {
      if (a['tipo'] == 'INASISTENCIA') {
        totalFaltas += (a['valor_inasistencia'] as num? ?? 1.0).toDouble();
      } else if (a['tipo'] == 'MEDIA_FALTA') {
        totalFaltas += 0.5;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado Institucional del Boletín (Estilo Foto 2)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withAlpha(40),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'INFORME DE AVANCE - 1° ETAPA / CUATRIMESTRE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'CICLO LECTIVO 2026',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ALUMNO/A: $nombreAlumno',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('DNI: $dniAlumno | CURSO: $cursoNombre',
                            style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 13)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_busy_rounded, color: colorScheme.primary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Inasistencias: ${totalFaltas == totalFaltas.roundToDouble() ? totalFaltas.round() : totalFaltas}',
                            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Leyenda Informativa
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(100),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Este boletín se completa en tiempo real únicamente con las calificaciones oficiales y ponderaciones RITE cargadas por los docentes del curso.',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tabla Oficial del Boletín
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest),
                dataRowMinHeight: 64,
                dataRowMaxHeight: 80,
                columnSpacing: 28,
                columns: const [
                  DataColumn(label: Text('MATERIA Y DOCENTE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('CRITERIOS CUALITATIVOS', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('TRAYECTORIA (RITE)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('CALIFICACIÓN NUMÉRICA', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('FALTAS*', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _materias.map((mat) {
                  final matId = mat['materia_id'] as String;
                  final matName = mat['nombre_asignatura'] as String;

                  // Filtrar notas del alumno para esta materia
                  final notasMateria = _calificaciones.where((c) {
                    final act = c['aca_actividades'] as Map<String, dynamic>?;
                    return act?['materia_id'] == matId;
                  }).toList();

                  double? promedio;
                  if (notasMateria.isNotEmpty) {
                    final List<Map<String, dynamic>> califsFormatted = [];
                    final List<Map<String, dynamic>> actsFormatted = [];
                    for (final n in notasMateria) {
                      final act = n['aca_actividades'] as Map<String, dynamic>?;
                      califsFormatted.add({
                        'alumno_id': widget.hijo['legajo_id'],
                        'actividad_id': act?['id'],
                        'nota_numerica': n['nota_numerica']
                      });
                      actsFormatted.add({
                        'id': act?['id'],
                        'categoria_id': act?['categoria_id']
                      });
                    }
                    promedio = _service.calcularPromedioRite(
                      actividades: actsFormatted,
                      calificaciones: califsFormatted,
                      categorias: _categorias,
                      alumnoId: widget.hijo['legajo_id'] as String,
                    );
                  }

                  String valorRite = 'S/C';
                  Color colorRite = Colors.grey;
                  String numText = '-';

                  if (promedio != null) {
                    numText = promedio.toStringAsFixed(1);
                    if (promedio >= 7.0) {
                      valorRite = 'TEA';
                      colorRite = Colors.green.shade700;
                    } else if (promedio >= 4.0) {
                      valorRite = 'TEP';
                      colorRite = Colors.orange.shade800;
                    } else {
                      valorRite = 'TED';
                      colorRite = Colors.red.shade700;
                    }
                  }

                  // Criterios cualitativos reales cargados por el docente en el
                  // Boletín Cualitativo (aca_rubricas_cualitativas) — antes acá
                  // se mostraba un texto inventado a partir del promedio numérico.
                  String cualitativo = 'Sin evaluar aún';
                  Color colorCualitativo = Colors.grey;
                  String tooltipCualitativo =
                      'Todavía no hay criterios cualitativos cargados por el docente para esta materia.';
                  final rubrica = _rubricasPorMateria[matId];
                  if (rubrica != null) {
                    const prioridad = ['R', 'B', 'MB', 'S']; // el criterio más flojo domina el resumen
                    final valores = <String>[];
                    final detalle = <String>[];
                    for (final c in _kCriteriosBoletin) {
                      final v = (rubrica[c['key']] ?? '').toString();
                      if (v.isNotEmpty) {
                        valores.add(v);
                        detalle.add('${c['label']}: $v');
                      }
                    }
                    if (valores.isNotEmpty) {
                      valores.sort((a, b) => prioridad.indexOf(a).compareTo(prioridad.indexOf(b)));
                      cualitativo = _labelNivelCualitativo(valores.first);
                      colorCualitativo = _colorNivelCualitativo(valores.first);
                      tooltipCualitativo = detalle.join(' · ');
                    }
                  }

                  // Asignación de docentes por materia
                  String profesorNombre = 'Docente a cargo';
                  if (cursoNombre.contains('1')) {
                    if (matName.contains('Historia Sagrada')) profesorNombre = 'Daniel Gómez';
                    else if (matName.contains('Lenguaje') || matName.contains('Prácticas del Lenguaje')) profesorNombre = 'Jessica Romero';
                    else if (matName.contains('Naturales')) profesorNombre = 'Daniel Gómez';
                    else if (matName.contains('Física')) profesorNombre = 'Julio Lesson';
                    else if (matName.contains('Ciudadanía')) profesorNombre = 'María Funes';
                    else if (matName.contains('Matemática')) profesorNombre = 'Florencia Viera';
                    else if (matName.contains('Sociales')) profesorNombre = 'Carlos Ruiz';
                  }

                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(matName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('Prof. $profesorNombre', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      DataCell(
                        Tooltip(
                          message: tooltipCualitativo,
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 16, color: colorCualitativo),
                              const SizedBox(width: 6),
                              Text(cualitativo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorCualitativo)),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorRite.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorRite.withAlpha(60)),
                          ),
                          child: Text(
                            valorRite,
                            style: TextStyle(fontWeight: FontWeight.bold, color: colorRite, fontSize: 13),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          numText,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: promedio != null && promedio >= 7.0 ? Colors.green.shade800 : colorScheme.onSurface),
                        ),
                      ),
                      DataCell(
                        Text('0', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Referencia de la escala cualitativa (legenda general, no un
          // listado de lo evaluado — eso se ve por materia en la columna
          // "Criterios Cualitativos" de la tabla, con el detalle en el tooltip).
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withAlpha(60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ESCALA DE CRITERIOS CUALITATIVOS (apropiación de contenidos, resolución de '
                          'actividades, participación, dudas, entrega, prolijidad y cumplimiento de los AIC):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildCriterioChip('S: Sobresaliente', colorScheme),
                      _buildCriterioChip('MB: Muy Bueno', colorScheme),
                      _buildCriterioChip('B: Bueno', colorScheme),
                      _buildCriterioChip('R: Regular', colorScheme),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mismos 7 criterios que carga el docente en el Boletín Cualitativo
  // (panel_calificaciones.dart) y que lee Dirección en el Informe de
  // Trayectoria — clave real en aca_rubricas_cualitativas → etiqueta corta.
  static const _kCriteriosBoletin = [
    {'key': 'criterio_apropiacion', 'label': 'Apropiación'},
    {'key': 'criterio_resolucion', 'label': 'Resolución'},
    {'key': 'criterio_participacion', 'label': 'Participación'},
    {'key': 'criterio_planteos', 'label': 'Dudas'},
    {'key': 'criterio_entrega', 'label': 'Entrega'},
    {'key': 'criterio_prolijidad', 'label': 'Prolijidad'},
    {'key': 'criterio_aic', 'label': 'AIC'},
  ];

  String _labelNivelCualitativo(String v) {
    switch (v) {
      case 'S':
        return 'Sobresaliente';
      case 'MB':
        return 'Muy Bueno';
      case 'B':
        return 'Bueno';
      case 'R':
        return 'Regular';
      default:
        return v;
    }
  }

  Color _colorNivelCualitativo(String v) {
    switch (v) {
      case 'S':
        return Colors.green.shade700;
      case 'MB':
        return Colors.blue.shade700;
      case 'B':
        return Colors.amber.shade800;
      case 'R':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCriterioChip(String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurface)),
    );
  }

  // 3. Evaluaciones Tab
  Widget _buildEvaluacionesTab(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Próximas Evaluaciones Programadas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Expanded(
            child: _evaluaciones.isEmpty
                ? const Center(child: Text('No hay exámenes agendados a la brevedad.'))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _evaluaciones.length,
                    itemBuilder: (context, index) {
                      final ev = _evaluaciones[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red.shade100),
                        ),
                        color: Colors.red.shade50.withAlpha(50),
                        child: ListTile(
                          leading: const Icon(Icons.quiz_rounded, color: Colors.red),
                          title: Text(ev['titulo'] as String? ?? 'Evaluación',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(ev['descripcion'] as String? ?? ''),
                          trailing: Text(ev['fecha'] as String? ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 4. Convivencia Tab
  Widget _buildConvivenciaTab(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registro de Comportamiento y Convivencia',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Expanded(
            child: _conducta.isEmpty
                ? const Center(child: Text('Sin reportes de conducta en el legajo.'))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _conducta.length,
                    itemBuilder: (context, index) {
                      final item = _conducta[index];
                      final tipo = item['tipo_incidencia'] as String? ?? 'Observación';
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
                          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
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
                  ),
          ),
        ],
      ),
    );
  }

  // 5. Adeudadas Tab
  Widget _buildAdeudadasTab(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Materias Adeudadas (Previas / Equivalencias)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Expanded(
            child: _adeudadas.isEmpty
                ? const Center(child: Text('¡Felicitaciones! No registra materias adeudadas.'))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _adeudadas.length,
                    itemBuilder: (context, index) {
                      final item = _adeudadas[index];
                      final mat = item['acad_materias'] as Map<String, dynamic>?;
                      final matName = mat?['nombre_asignatura'] as String? ?? 'Materia';
                      final anio = item['anio_origen'] as int? ?? 2025;
                      final condicion = item['condicion'] as String? ?? 'PREVIO';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.amber.shade200),
                        ),
                        color: Colors.amber.shade50.withAlpha(50),
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                          title: Text(matName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Año de origen: $anio • Condición: $condicion'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
