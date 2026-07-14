import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

// ── Enum de estado de conducta diaria ──────────────────────────────────────
enum _EstadoConducta { bien, regular, mal }

// ── Modelo de conducta por alumno ──────────────────────────────────────────
class _ConductaAlumno {
  final String alumnoId;
  final String nombre;
  _EstadoConducta estado;
  String observacion;

  _ConductaAlumno({
    required this.alumnoId,
    required this.nombre,
    this.estado = _EstadoConducta.bien,
    this.observacion = '',
  });
}

// ── Pantalla principal ─────────────────────────────────────────────────────
class PanelConductaDiaria extends StatefulWidget {
  final String cursoId;
  final String nombreAsignatura;

  const PanelConductaDiaria({
    super.key,
    required this.cursoId,
    required this.nombreAsignatura,
  });

  @override
  State<PanelConductaDiaria> createState() => _PanelConductaDiariaState();
}

class _PanelConductaDiariaState extends State<PanelConductaDiaria> {
  final _service = SupabaseService();
  late Future<List<_ConductaAlumno>> _alumnosFuture;
  bool _guardando = false;

  bool _verPlanillaMensual = false;
  int _selectedMesIndex = DateTime.now().month;
  List<Map<String, dynamic>> _conductaMensualDatos = [];
  bool _loadingConductaMensual = false;

  final List<String> _mesesNombres = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _alumnosFuture = _cargarAlumnos();
    _cargarConductaMensual();
  }

  Future<void> _cargarConductaMensual() async {
    setState(() => _loadingConductaMensual = true);
    try {
      final list = await _service.obtenerConductaMensualCurso(widget.cursoId);
      setState(() {
        _conductaMensualDatos = list;
        _loadingConductaMensual = false;
      });
    } catch (e) {
      print('Error al cargar conducta mensual: $e');
      setState(() => _loadingConductaMensual = false);
    }
  }

  Future<List<_ConductaAlumno>> _cargarAlumnos() async {
    try {
      final lista = await _service.fetchAlumnos(cursoId: widget.cursoId);
      return lista
          .map((a) => _ConductaAlumno(
                alumnoId: a.id,
                nombre: a.nombre,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error cargando alumnos conducta: $e');
      return [];
    }
  }

  Future<void> _guardarConducta(List<_ConductaAlumno> alumnos) async {
    setState(() => _guardando = true);
    int errores = 0;
    for (final a in alumnos) {
      if (a.alumnoId.isEmpty) continue;
      if (a.estado != _EstadoConducta.bien || a.observacion.isNotEmpty) {
        try {
          await _service.registrarIncidencia(
            alumnoId: a.alumnoId,
            tipoIncidencia: a.observacion.isNotEmpty
                ? a.observacion
                : _labelEstado(a.estado),
            severidad: a.estado == _EstadoConducta.mal
                ? 'MODERADA'
                : 'LEVE',
            descripcion:
                'Conducta diaria: ${_labelEstado(a.estado)}${a.observacion.isNotEmpty ? ' — ${a.observacion}' : ''}',
          );
        } catch (_) {
          errores++;
        }
      }
    }
    if (mounted) {
      setState(() => _guardando = false);
      _cargarConductaMensual(); // Recargar grilla mensual
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(
              errores == 0
                  ? Icons.check_circle_rounded
                  : Icons.warning_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(errores == 0
                ? 'Conducta diaria guardada correctamente'
                : 'Se guardó con $errores errores'),
          ]),
          backgroundColor:
              errores == 0 ? Colors.green.shade800 : Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      if (errores == 0) Navigator.of(context).pop();
    }
  }

  String _labelEstado(_EstadoConducta e) {
    switch (e) {
      case _EstadoConducta.bien:
        return 'Bien';
      case _EstadoConducta.regular:
        return 'Regular';
      case _EstadoConducta.mal:
        return 'Mal';
    }
  }

  Future<void> _generarNotaDesempenoRite(List<_ConductaAlumno> alumnos) async {
    final mesNombre = _mesesNombres[_selectedMesIndex - 1];
    final List<Map<String, dynamic>> calculoAlumnos = [];

    for (final al in alumnos) {
      int countBien = 0;
      int countRegular = 0;
      int countMal = 0;

      final datosAlumnoMes = _conductaMensualDatos.where((d) {
        try {
          final dt = DateTime.parse(d['fecha'] as String);
          return d['alumno_id'] == al.alumnoId && dt.month == _selectedMesIndex;
        } catch (_) {
          return false;
        }
      });

      for (final match in datosAlumnoMes) {
        final tipo = match['tipo_incidencia'] as String? ?? 'Bien';
        if (tipo == 'Regular' || tipo == 'Más o menos') {
          countRegular++;
        } else if (tipo == 'Mal') {
          countMal++;
        } else {
          countBien++;
        }
      }

      double notaNum = 10.0 - (countMal * 1.5) - (countRegular * 0.5);
      if (notaNum < 1.0) notaNum = 1.0;
      if (notaNum > 10.0) notaNum = 10.0;

      String concepto = 'TEA';
      if (notaNum < 4.0) {
        concepto = 'TED';
      } else if (notaNum < 7.0) {
        concepto = 'TEP';
      }

      calculoAlumnos.add({
        'alumno_id': al.alumnoId,
        'nombre': al.nombre,
        'nota_numerica': notaNum.toStringAsFixed(1),
        'concepto': concepto,
        'mal': countMal,
        'regular': countRegular,
      });
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Generar Nota Desempeño ($mesNombre) - 30% RITE', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade300)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📌 Plan de Integración en RITE (30% del Desempeño):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                    SizedBox(height: 6),
                    Text(
                      'Esta herramienta calcula el promedio de comportamiento diario y genera automáticamente la calificación del mes para sumarla directamente a la Planilla de Calificaciones Oficial.\n• TEA (Trayectoria Avanzada): Nota ≥ 7.0\n• TEP (En Proceso): Nota 4.0 a 6.9\n• TED (Discontinua): Nota < 4.0',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Resumen por Alumno:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ...calculoAlumnos.map((item) {
                final conc = item['concepto'] as String;
                Color col = Colors.green;
                if (conc == 'TEP') col = Colors.orange;
                if (conc == 'TED') col = Colors.red;

                return Card(
                  elevation: 0,
                  color: Colors.grey.shade50,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    title: Text(item['nombre'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Incidencias - Reg: ${item['regular']} | Mal: ${item['mal']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${item['nota_numerica']} pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: col.withAlpha(40), borderRadius: BorderRadius.circular(6), border: Border.all(color: col)),
                          child: Text(conc, style: TextStyle(fontWeight: FontWeight.bold, color: col, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton.icon(
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Exportar a Planilla Calificaciones (30% RITE)'),
            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
            onPressed: () async {
              int guardados = 0;
              
              // 1. Obtener o resolver materia para vincular a aca_actividades / aca_calificaciones
              String materiaIdEncontrada = '';
              try {
                final materiasCurso = await _service.fetchMaterias(cursoId: widget.cursoId);
                if (materiasCurso.isNotEmpty) {
                  final mMatch = materiasCurso.firstWhere(
                    (m) => (m['nombre'] ?? '').toString().toLowerCase() == widget.nombreAsignatura.toLowerCase(),
                    orElse: () => materiasCurso.first,
                  );
                  materiaIdEncontrada = mMatch['materia_id'] ?? mMatch['id'] ?? '';
                }
              } catch (_) {}

              // 2. Crear actividad en aca_actividades si tenemos materia
              String? nuevaActividadId;
              if (materiaIdEncontrada.isNotEmpty) {
                try {
                  final categorias = await _service.obtenerCategoriasCalificaciones();
                  final categoriaId = categorias.isNotEmpty ? categorias.first['id'] as String : '1';
                  final act = await _service.crearActividad(
                    materiaId: materiaIdEncontrada,
                    categoriaId: categoriaId,
                    titulo: 'Desempeño Diario ($mesNombre - 30% RITE)',
                    fecha: DateTime.now(),
                  );
                  nuevaActividadId = act['id'] as String?;
                } catch (_) {}
              }

              for (final c in calculoAlumnos) {
                try {
                  final notaNum = double.tryParse(c['nota_numerica'] as String);

                  // Guardar en tabla aca_calificaciones si se creó actividad
                  if (nuevaActividadId != null && notaNum != null) {
                    await _service.upsertCalificacion(
                      actividadId: nuevaActividadId,
                      alumnoId: c['alumno_id'] as String,
                      notaNumerica: notaNum,
                    );
                  }

                  // Guardar en tabla calificaciones legacy para boletines e historial RITE
                  await Supabase.instance.client.from('calificaciones').insert({
                    'curso_id': widget.cursoId,
                    'materia_id': materiaIdEncontrada,
                    'alumno_id': c['alumno_id'],
                    'periodo': '1° Trimestre',
                    'instancia': 'Desempeño Diario Conducta ($mesNombre - 30% RITE)',
                    'calificacion': c['nota_numerica'],
                    'es_rite': true,
                    'calificacion_rite': c['concepto'],
                    'observaciones': 'Generada automáticamente desde registro de Conducta Diaria.',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  guardados++;
                } catch (_) {}
              }
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ $guardados notas generadas e inyectadas a la Planilla de Calificaciones (Instancia 30% RITE Desempeño).'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlanillaMensualGrid(ColorScheme colorScheme, List<_ConductaAlumno> alumnos) {
    if (_loadingConductaMensual) {
      return const Center(child: CircularProgressIndicator());
    }

    final datesInMonth = _conductaMensualDatos.map((d) {
      try {
        return DateTime.parse(d['fecha'] as String);
      } catch (_) {
        return null;
      }
    }).where((dt) => dt != null && dt!.month == _selectedMesIndex).cast<DateTime>().toList();

    final Map<String, DateTime> uniqueDates = {};
    for (final dt in datesInMonth) {
      final key = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
      uniqueDates[key] = dt;
    }
    final sortedKeys = uniqueDates.keys.toList()..sort();

    final monthDropdown = Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _selectedMesIndex,
              decoration: const InputDecoration(
                labelText: 'Mes de Consulta',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                prefixIcon: Icon(Icons.calendar_month_rounded),
              ),
              items: List.generate(12, (i) => i + 1).map((mIndex) {
                return DropdownMenuItem(
                  value: mIndex,
                  child: Text(_mesesNombres[mIndex - 1]),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedMesIndex = val;
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _generarNotaDesempenoRite(alumnos),
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Generar Nota (30% RITE)'),
            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18)),
          ),
        ],
      ),
    );

    if (sortedKeys.isEmpty) {
      return Column(
        children: [
          monthDropdown,
          const Expanded(
            child: Center(
              child: Text(
                'Sin registros de conducta para el mes seleccionado.',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        monthDropdown,
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
                ),
                child: DataTable(
                  columnSpacing: 18,
                  horizontalMargin: 16,
                  columns: [
                    const DataColumn(label: Text('Alumno', style: TextStyle(fontWeight: FontWeight.bold))),
                    ...sortedKeys.map((dateStr) => DataColumn(
                      label: Text(
                        dateStr,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    )),
                    const DataColumn(label: Text('B', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                    const DataColumn(label: Text('R', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
                    const DataColumn(label: Text('M', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                  ],
                  rows: alumnos.map((al) {
                    int countBien = 0;
                    int countRegular = 0;
                    int countMal = 0;

                    final cells = sortedKeys.map((dateStr) {
                      final match = _conductaMensualDatos.firstWhere(
                        (d) {
                          try {
                            final dt = DateTime.parse(d['fecha'] as String);
                            final key = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
                            return d['alumno_id'] == al.alumnoId && key == dateStr;
                          } catch (_) {
                            return false;
                          }
                        },
                        orElse: () => {},
                      );

                      if (match.isEmpty) {
                        countBien++;
                        return const DataCell(
                          Center(
                            child: CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.transparent,
                              child: Text('-', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            ),
                          ),
                        );
                      }

                      final tipo = match['tipo_incidencia'] as String? ?? 'Bien';
                      Color color = Colors.green;
                      String letter = 'B';

                      if (tipo == 'Regular' || tipo == 'Más o menos') {
                        color = Colors.orange;
                        letter = 'R';
                        countRegular++;
                      } else if (tipo == 'Mal') {
                        color = Colors.red;
                        letter = 'M';
                        countMal++;
                      } else {
                        countBien++;
                      }

                      return DataCell(
                        Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: color.withAlpha(30),
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                letter,
                                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList();

                    return DataRow(
                      cells: [
                        DataCell(Text(al.nombre, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                        ...cells,
                        DataCell(Text(countBien.toString(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                        DataCell(Text(countRegular.toString(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                        DataCell(Text(countMal.toString(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hoy = DateTime.now();
    final fechaStr =
        '${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}';

    return FutureBuilder<List<_ConductaAlumno>>(
      future: _alumnosFuture,
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Conducta Diaria',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.nombreAsignatura,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        )),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: ElevatedButton.icon(
                  onPressed: snapshot.data == null ? null : () => _generarNotaDesempenoRite(snapshot.data!),
                  icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                  label: const Text('Generar Nota Mes (30% RITE)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(_verPlanillaMensual ? Icons.view_list_rounded : Icons.calendar_month_rounded),
                tooltip: _verPlanillaMensual ? 'Ver Fichas Diario' : 'Ver Planilla Mensual',
                onPressed: () {
                  setState(() {
                    _verPlanillaMensual = !_verPlanillaMensual;
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
            backgroundColor: colorScheme.surface,
            elevation: 0,
            scrolledUnderElevation: 1,
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError || (snapshot.data?.isEmpty ?? true)
                  ? const Center(
                      child: Text('No hay alumnos asignados a este curso.'))
                  : _verPlanillaMensual
                      ? _buildPlanillaMensualGrid(colorScheme, snapshot.data!)
                      : _ConductaBody(
                          alumnos: snapshot.data!,
                          fechaStr: fechaStr,
                          guardando: _guardando,
                          onGuardar: _guardarConducta,
                        ),
        );
      },
    );
  }
}

// ── Cuerpo separado (StatefulWidget) para mutar la lista de alumnos ─────────
class _ConductaBody extends StatefulWidget {
  final List<_ConductaAlumno> alumnos;
  final String fechaStr;
  final bool guardando;
  final Future<void> Function(List<_ConductaAlumno>) onGuardar;

  const _ConductaBody({
    required this.alumnos,
    required this.fechaStr,
    required this.guardando,
    required this.onGuardar,
  });

  @override
  State<_ConductaBody> createState() => _ConductaBodyState();
}

class _ConductaBodyState extends State<_ConductaBody> {
  late final List<_ConductaAlumno> _alumnos;

  static const _opciones = [
    _EstadoConducta.bien,
    _EstadoConducta.regular,
    _EstadoConducta.mal,
  ];
  static const _etiquetas = ['Bien', 'Regular', 'Mal'];
  static const _iconos = [
    Icons.sentiment_very_satisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_very_dissatisfied_rounded,
  ];
  static final _colores = [
    Colors.green,
    Colors.orange,
    Colors.red,
  ];

  @override
  void initState() {
    super.initState();
    _alumnos = widget.alumnos;
  }

  int get _bien =>
      _alumnos.where((a) => a.estado == _EstadoConducta.bien).length;
  int get _regular =>
      _alumnos.where((a) => a.estado == _EstadoConducta.regular).length;
  int get _mal =>
      _alumnos.where((a) => a.estado == _EstadoConducta.mal).length;

  void _abrirObservacion(_ConductaAlumno alumno) {
    final ctrl = TextEditingController(text: alumno.observacion);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Observación — ${alumno.nombre}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Escribí una observación opcional...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  setState(() => alumno.observacion = ctrl.text.trim());
                  Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Guardar observación'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Encabezado con resumen ─────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: colorScheme.primaryContainer.withAlpha(50),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 15, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(widget.fechaStr,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: colorScheme.primary)),
              const Spacer(),
              _chip(Icons.sentiment_very_satisfied_rounded, '$_bien',
                  Colors.green),
              const SizedBox(width: 6),
              _chip(Icons.sentiment_neutral_rounded, '$_regular',
                  Colors.orange),
              const SizedBox(width: 6),
              _chip(Icons.sentiment_very_dissatisfied_rounded, '$_mal',
                  Colors.red),
            ],
          ),
        ),

        // ── Lista de alumnos ───────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: _alumnos.length,
            itemBuilder: (context, i) {
              final alumno = _alumnos[i];
              final estadoIdx = _opciones.indexOf(alumno.estado);
              final colorEstado = _colores[estadoIdx];

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: alumno.estado == _EstadoConducta.bien
                        ? colorScheme.outlineVariant
                        : colorEstado.withAlpha(80),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Fila nombre + estado badge ─────────────────
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: colorEstado.withAlpha(40),
                            child: Text(
                              alumno.nombre.isNotEmpty
                                  ? alumno.nombre
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorEstado,
                                  fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              alumno.nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                          // Badge estado actual
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorEstado.withAlpha(30),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_iconos[estadoIdx],
                                    size: 13, color: colorEstado),
                                const SizedBox(width: 4),
                                Text(_etiquetas[estadoIdx].replaceAll('\n', ' '),
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: colorEstado)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── Botones Bien / Más o menos / Mal ──────────
                      Row(
                        children: List.generate(3, (j) {
                          final selected = alumno.estado == _opciones[j];
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: j < 2 ? 8 : 0),
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => alumno.estado = _opciones[j]),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? _colores[j]
                                        : _colores[j].withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? _colores[j]
                                          : _colores[j].withAlpha(60),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_iconos[j],
                                          size: 22,
                                          color: selected
                                              ? Colors.white
                                              : _colores[j]),
                                      const SizedBox(height: 4),
                                      Text(
                                        _etiquetas[j],
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: selected
                                                ? Colors.white
                                                : _colores[j]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),

                      // ── Observación (si tiene o botón para agregar) ─
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _abrirObservacion(alumno),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: alumno.observacion.isNotEmpty
                                ? colorScheme.secondaryContainer
                                    .withAlpha(80)
                                : colorScheme.surfaceContainerHighest
                                    .withAlpha(60),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: colorScheme.outlineVariant
                                    .withAlpha(80)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                alumno.observacion.isNotEmpty
                                    ? Icons.chat_bubble_rounded
                                    : Icons.add_comment_rounded,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  alumno.observacion.isNotEmpty
                                      ? alumno.observacion
                                      : 'Agregar observación...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: alumno.observacion.isNotEmpty
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurfaceVariant,
                                    fontStyle: alumno.observacion.isEmpty
                                        ? FontStyle.italic
                                        : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (alumno.observacion.isNotEmpty)
                                Icon(Icons.edit_rounded,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ── Barra de confirmación ──────────────────────────────────────
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_alumnos.length} alumnos',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      Text('Guardar el registro de hoy',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.guardando
                      ? null
                      : () => widget.onGuardar(_alumnos),
                  icon: widget.guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Confirmar conducta',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
