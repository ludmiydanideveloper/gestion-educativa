import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/asistencia_provider.dart';
import '../widgets/alumno_tile_mobile.dart';
import '../models/alumno_asistencia.dart';
import '../services/supabase_service.dart';

class PanelAsistencia extends StatefulWidget {
  final String cursoId;
  final String? materiaId;
  const PanelAsistencia({super.key, required this.cursoId, this.materiaId});

  @override
  State<PanelAsistencia> createState() => _PanelAsistenciaState();
}

class _PanelAsistenciaState extends State<PanelAsistencia> {
  final SupabaseService _supabaseService = SupabaseService();
  
  bool _verPlanillaMensual = false;
  int _selectedMesIndex = DateTime.now().month;
  List<Map<String, dynamic>> _asistenciaMensualDatos = [];
  bool _loadingAsistenciaMensual = false;

  final List<String> _mesesNombres = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AsistenciaProvider>().cargarAlumnos(cursoId: widget.cursoId);
      _cargarAsistenciaMensual();
    });
  }

  Future<void> _cargarAsistenciaMensual() async {
    setState(() => _loadingAsistenciaMensual = true);
    try {
      final list = await _supabaseService.obtenerAsistenciaMensualCurso(
        widget.cursoId,
        materiaId: widget.materiaId,
        tipoAsistencia: widget.materiaId != null ? 'POR_MATERIA' : 'PRECEPTOR_DIARIA',
      );
      setState(() {
        _asistenciaMensualDatos = list;
        _loadingAsistenciaMensual = false;
      });
    } catch (e) {
      print('Error al cargar asistencia mensual: $e');
      setState(() => _loadingAsistenciaMensual = false);
    }
  }

  void _confirmarAsistencia(BuildContext context) {
    final provider = context.read<AsistenciaProvider>();
    provider.guardarAsistencia(
      cursoId: widget.cursoId,
      materiaId: widget.materiaId,
      tipoAsistencia: widget.materiaId != null ? 'POR_MATERIA' : 'PRECEPTOR_DIARIA',
    ).then((exito) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(
                  exito ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: Colors.white),
              const SizedBox(width: 12),
              Text(exito
                  ? 'Asistencia consolidada y guardada'
                  : 'Error al guardar la planilla'),
            ]),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                exito ? Colors.green.shade800 : Colors.red.shade800,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        if (exito) {
          _cargarAsistenciaMensual(); // Recargar grilla mensual
          Navigator.of(context).pop();
        }
      }
    });
  }

  void _mostrarConfirmacionGuardado() {
    final provider = context.read<AsistenciaProvider>();
    final presentes = provider.alumnos.where((a) => a.estado == EstadoAsistencia.presente).length;
    final ausentes = provider.alumnos.where((a) => a.estado == EstadoAsistencia.ausente).length;
    final tardes = provider.alumnos.where((a) => a.estado == EstadoAsistencia.tarde).length;
    final retiros = provider.alumnos.where((a) => a.estado == EstadoAsistencia.retiro).length;
    final total = provider.alumnos.length;

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assignment_turned_in_rounded, color: colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Confirmar Planilla', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Deseas consolidar y guardar la asistencia de hoy con el siguiente resumen?',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant.withAlpha(40)),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Total Alumnos:', total.toString(), Colors.black87),
                    const Divider(height: 12),
                    _buildSummaryRow('Presentes:', presentes.toString(), Colors.green.shade800),
                    _buildSummaryRow('Ausentes (Faltas):', ausentes.toString(), Colors.red.shade800),
                    _buildSummaryRow('Tardes:', tardes.toString(), Colors.orange.shade800),
                    _buildSummaryRow('Retiros Anticipados:', retiros.toString(), Colors.purple.shade800),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmarAsistencia(context);
              },
              child: const Text('Guardar Planilla'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanillaMensualGrid(ColorScheme colorScheme, List<dynamic> alumnos) {
    if (_loadingAsistenciaMensual) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // 1. Filtrar las fechas registradas para el mes seleccionado
    final datesInMonth = _asistenciaMensualDatos.map((d) {
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

    // Dropdown de selección de mes
    final monthDropdown = Container(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<int>(
        value: _selectedMesIndex,
        decoration: const InputDecoration(
          labelText: 'Mes de Consulta',
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          prefixIcon: Icon(Icons.calendar_month_rounded),
        ),
        items: List.generate(12, (i) {
          return DropdownMenuItem(
            value: i + 1,
            child: Text(_mesesNombres[i]),
          );
        }),
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _selectedMesIndex = val;
            });
          }
        },
      ),
    );

    // Si no hay días cargados
    if (sortedKeys.isEmpty) {
      return Expanded(
        child: ListView(
          children: [
            monthDropdown,
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 48, color: colorScheme.primary.withAlpha(120)),
                      const SizedBox(height: 16),
                      const Text(
                        'Sin registros de asistencia para este mes.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Selecciona otro mes o registra asistencia para hoy.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Renderizar tabla con scroll horizontal
    return Expanded(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          monthDropdown,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildLegendItem('P', 'Pres.', Colors.green),
                const SizedBox(width: 8),
                _buildLegendItem('A', 'Aus.', Colors.red),
                const SizedBox(width: 8),
                _buildLegendItem('T', 'Tarde', Colors.orange),
                const SizedBox(width: 8),
                _buildLegendItem('R', 'Ret.', Colors.purple),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 14,
                    headingRowHeight: 44,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 36,
                    columns: [
                      const DataColumn(
                        label: Text(
                          'Alumno',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...sortedKeys.map((dateKey) {
                        return DataColumn(
                          label: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              dateKey,
                              style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 11),
                            ),
                          ),
                        );
                      }),
                      const DataColumn(label: Center(child: Text('P', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)))),
                      const DataColumn(label: Center(child: Text('A', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)))),
                      const DataColumn(label: Center(child: Text('T', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)))),
                      const DataColumn(label: Center(child: Text('Faltas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)))),
                    ],
                    rows: List.generate(alumnos.length, (idx) {
                      final al = alumnos[idx];
                      final name = al.nombre.toUpperCase();
                      final alId = al.id;

                      // Filtrar registros de este alumno en este mes
                      final studentMonthRecords = _asistenciaMensualDatos.where((r) {
                        try {
                          final dt = DateTime.parse(r['fecha'] as String);
                          return r['alumno_id'] == alId && dt.month == _selectedMesIndex;
                        } catch (_) {
                          return false;
                        }
                      }).toList();

                      final totalPresentes = studentMonthRecords.where((r) => (r['tipo'] ?? '').toString().toLowerCase() == 'presente').length;
                      final totalAusentes = studentMonthRecords.where((r) => (r['tipo'] ?? '').toString().toLowerCase() == 'ausente').length;
                      final totalTardes = studentMonthRecords.where((r) => (r['tipo'] ?? '').toString().toLowerCase() == 'tarde').length;
                      final totalFaltas = totalAusentes + (totalTardes * 0.25);

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                Text(
                                  '${idx + 1}. ',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                                Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          ...sortedKeys.map((dateKey) {
                            final rec = studentMonthRecords.firstWhere(
                              (r) {
                                try {
                                  final dt = DateTime.parse(r['fecha'] as String);
                                  final key = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
                                  return key == dateKey;
                                } catch (_) {
                                  return false;
                                }
                              },
                              orElse: () => {},
                            );

                            if (rec.isEmpty) {
                              return const DataCell(Center(child: Text('-', style: TextStyle(color: Colors.grey))));
                            }

                            final tipo = (rec['tipo'] ?? '').toString().toLowerCase();
                            String letter = '-';
                            Color color = Colors.grey;

                            if (tipo == 'presente') {
                              letter = 'P';
                              color = Colors.green;
                            } else if (tipo == 'ausente') {
                              letter = 'A';
                              color = Colors.red;
                            } else if (tipo == 'tarde') {
                              letter = 'T';
                              color = Colors.orange;
                            } else if (tipo == 'retiro') {
                              letter = 'R';
                              color = Colors.purple;
                            }

                            return DataCell(
                              Center(
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(30),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: color, width: 1.2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      letter,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          DataCell(Center(child: Text(totalPresentes.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)))),
                          DataCell(Center(child: Text(totalAusentes.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12)))),
                          DataCell(Center(child: Text(totalTardes.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12)))),
                          DataCell(
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: totalFaltas > 0 ? Colors.red.withAlpha(20) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  totalFaltas == 0 ? '0' : totalFaltas.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: totalFaltas > 0 ? Colors.red.shade900 : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String letter, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withAlpha(35),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.2),
          ),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AsistenciaProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // Contadores para el resumen del encabezado
    final presentes = provider.alumnos
        .where((a) => a.estado == EstadoAsistencia.presente)
        .length;
    final ausentes = provider.alumnos
        .where((a) => a.estado == EstadoAsistencia.ausente)
        .length;
    final tardes = provider.alumnos
        .where((a) => a.estado == EstadoAsistencia.tarde)
        .length;
    final hoy = DateTime.now();
    final fechaStr =
        '${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text(_verPlanillaMensual ? 'Asistencia Mensual' : 'Toma de Asistencia',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: Icon(_verPlanillaMensual ? Icons.edit_calendar_rounded : Icons.calendar_month_rounded),
            tooltip: _verPlanillaMensual ? 'Registrar Asistencia' : 'Ver Planilla Mensual',
            onPressed: () {
              setState(() {
                _verPlanillaMensual = !_verPlanillaMensual;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar',
            onPressed: () {
              provider.cargarAlumnos(cursoId: widget.cursoId);
              _cargarAsistenciaMensual();
            },
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_verPlanillaMensual) ...[
                  // ── Encabezado con fecha y contadores (solo en modo registro) ─────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    color: colorScheme.primaryContainer.withAlpha(60),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 15, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(fechaStr,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary)),
                        const Spacer(),
                        _statChip(Icons.check_circle_rounded, '$presentes',
                            Colors.green),
                        const SizedBox(width: 6),
                        _statChip(
                            Icons.cancel_rounded, '$ausentes', Colors.red),
                        const SizedBox(width: 6),
                        _statChip(Icons.access_time_rounded, '$tardes',
                            Colors.orange),
                      ],
                    ),
                  ),
                  // ── Lista de alumnos ───────────────────────────────────
                  Expanded(
                    child: provider.alumnos.isEmpty
                        ? const Center(
                            child: Text('No hay alumnos asignados.'))
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                                10, 8, 10, 100),
                            itemCount: provider.alumnos.length,
                            itemBuilder: (context, index) =>
                                AlumnoTileMobile(
                                    alumnoId:
                                        provider.alumnos[index].id),
                          ),
                  ),
                ] else ...[
                  // ── Grilla Mensual ───────────────────────────────────
                  _buildPlanillaMensualGrid(colorScheme, provider.alumnos),
                ],
              ],
            ),
      floatingActionButton: _verPlanillaMensual
          ? null
          : FloatingActionButton.extended(
              onPressed:
                  provider.isLoading || provider.alumnos.isEmpty
                      ? null
                      : () => _mostrarConfirmacionGuardado(),
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_rounded),
              label: const Text('Confirmar Planilla',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}
