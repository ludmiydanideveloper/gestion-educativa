import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class PanelCierreEtapa extends StatefulWidget {
  final String materiaId;
  final String cursoId;
  final String nombreAsignatura;

  const PanelCierreEtapa({
    super.key,
    required this.materiaId,
    required this.cursoId,
    required this.nombreAsignatura,
  });

  @override
  State<PanelCierreEtapa> createState() => _PanelCierreEtapaState();
}

class _PanelCierreEtapaState extends State<PanelCierreEtapa> {
  final _service = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _alumnos = [];
  final int _anioLectivo = DateTime.now().year;

  // criterios[alumnoId] = { 'apropiacion': 'MB', ... }
  final Map<String, Map<String, String>> _criterios = {};

  final List<String> _opciones = ['S', 'MB', 'B', 'R'];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.fetchAlumnos(cursoId: widget.cursoId);
      final listCompleta = <Map<String, dynamic>>[];
      
      for (final a in list) {
        final boletin = await _service.obtenerOCrearBoletin(a.id, widget.cursoId, _anioLectivo);
        final detalles = await _service.obtenerDetallesBoletin(boletin['boletin_id'] as String);
        final detalleMateria = detalles.firstWhere(
          (d) => d['materia_id'] == widget.materiaId, 
          orElse: () => {}
        );

        _criterios[a.id] = {
          'apropiacion': detalleMateria['apropiacion_contenidos'] ?? 'S',
          'resolucion': detalleMateria['resolucion_actividades'] ?? 'S',
          'participacion': detalleMateria['participacion_clases'] ?? 'S',
          'dudas': detalleMateria['planteos_dudas'] ?? 'S',
          'entrega': detalleMateria['entrega_actividades'] ?? 'S',
          'prolijidad': detalleMateria['prolijidad_carpeta'] ?? 'S',
          'aic': detalleMateria['cumplimiento_aic'] ?? 'S',
        };

        listCompleta.add({
          'id': a.id,
          'nombre': a.nombre,
          'boletin_id': boletin['boletin_id'],
        });
      }

      setState(() {
        _alumnos = listCompleta;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarTodos() async {
    setState(() => _isLoading = true);
    try {
      for (var a in _alumnos) {
        await _service.guardarCriteriosDocente(
          a['boletin_id'], 
          widget.materiaId, 
          _criterios[a['id']]!
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Criterios guardados correctamente.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _calcularPromediosYTEA(int etapa) async {
    // Aquí iría el modal para seleccionar qué actividades promediar.
    // Para simplificar, simularemos el cálculo.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calcular Promedios (Simulación)'),
        content: Text('Se promediarán las notas y se asignará TEA/TEP/TED para la Etapa $etapa a todos los alumnos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              for (var a in _alumnos) {
                // Simulación de promedio = 8.0 (TEA)
                await _service.guardarPromedioEtapa(a['boletin_id'], widget.materiaId, etapa, 8.0);
              }
              setState(() => _isLoading = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Promedios y valoraciones calculadas con éxito.'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Calcular'),
          )
        ],
      )
    );
  }

  Widget _buildDropdown(String alumnoId, String criterio) {
    return DropdownButton<String>(
      value: _criterios[alumnoId]![criterio],
      isDense: true,
      items: _opciones.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _criterios[alumnoId]![criterio] = val;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre de Etapa (Criterios)', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            onPressed: _guardarTodos,
            tooltip: 'Guardar Criterios',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.calculate_rounded),
                        label: const Text('Calcular Promedio 1° Etapa'),
                        onPressed: () => _calcularPromediosYTEA(1),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.calculate_rounded),
                        label: const Text('Calcular Promedio 2° Etapa'),
                        onPressed: () => _calcularPromediosYTEA(2),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        columns: const [
                          DataColumn(label: Text('Alumno')),
                          DataColumn(label: Text('Apropiación')),
                          DataColumn(label: Text('Resolución')),
                          DataColumn(label: Text('Participación')),
                          DataColumn(label: Text('Dudas')),
                          DataColumn(label: Text('Entrega')),
                          DataColumn(label: Text('Prolijidad')),
                          DataColumn(label: Text('AIC')),
                        ],
                        rows: _alumnos.map((a) {
                          return DataRow(cells: [
                            DataCell(Text(a['nombre'])),
                            DataCell(_buildDropdown(a['id'], 'apropiacion')),
                            DataCell(_buildDropdown(a['id'], 'resolucion')),
                            DataCell(_buildDropdown(a['id'], 'participacion')),
                            DataCell(_buildDropdown(a['id'], 'dudas')),
                            DataCell(_buildDropdown(a['id'], 'entrega')),
                            DataCell(_buildDropdown(a['id'], 'prolijidad')),
                            DataCell(_buildDropdown(a['id'], 'aic')),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
