import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/dialogo_periodos_adeudada.dart';

/// Alumnos que intensifican, recursan o adeudan como previa ESTA materia
/// (acad_materias_adeudadas.materia_original_id = esta materia). El docente
/// titular carga acá las mesas/coloquios de intensificación — antes esto
/// solo lo podía tocar Dirección.
class PanelIntensificacionMateria extends StatefulWidget {
  final String materiaId;
  final String nombreAsignatura;

  const PanelIntensificacionMateria({
    super.key,
    required this.materiaId,
    required this.nombreAsignatura,
  });

  @override
  State<PanelIntensificacionMateria> createState() => _PanelIntensificacionMateriaState();
}

class _PanelIntensificacionMateriaState extends State<PanelIntensificacionMateria> {
  final _service = SupabaseService();
  bool _loading = true;
  List<Map<String, dynamic>> _adeudadas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      _adeudadas = await _service.obtenerAdeudadasPorMateria(widget.materiaId);
    } catch (e) {
      debugPrint('Error al cargar adeudadas de la materia: $e');
      _adeudadas = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _nombreAlumno(Map<String, dynamic> item) {
    final alumno = item['usr_legajo_alumno'] as Map<String, dynamic>?;
    final demo = alumno?['datos_demograficos'] as Map<String, dynamic>?;
    final nombre = '${demo?['apellido'] ?? ''} ${demo?['nombre'] ?? ''}'.trim();
    return nombre.isEmpty ? 'Alumno' : nombre;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Intensificación — ${widget.nombreAsignatura}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _cargar),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _adeudadas.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Nadie está intensificando, recursando o adeudando esta materia de años anteriores.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _adeudadas.length,
                  itemBuilder: (context, index) {
                    final item = _adeudadas[index];
                    final condicion = (item['condicion'] ?? '').toString();
                    final aprobada = (item['estado'] ?? '') == 'APROBADA';
                    final color = condicion == SupabaseService.kCondicionRecursa ? Colors.orange.shade800 : Colors.deepPurple;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withAlpha(80))),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withAlpha(25),
                          child: Icon(
                            condicion == SupabaseService.kCondicionRecursa ? Icons.refresh_rounded : Icons.bolt_rounded,
                            color: color,
                          ),
                        ),
                        title: Text(_nombreAlumno(item), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${SupabaseService.labelCondicionAdeudada(condicion)} · Año origen: ${item['anio_origen']}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (aprobada ? Colors.green : Colors.red).withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            aprobada ? 'APROBADA' : 'PENDIENTE',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: aprobada ? Colors.green.shade800 : Colors.red.shade800),
                          ),
                        ),
                        onTap: condicion == SupabaseService.kCondicionRecursa
                            ? () => ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Está recursando: cargale notas desde la Planilla de Calificaciones normal.')),
                                )
                            : () => mostrarGestionAdeudada(
                                  context,
                                  adeudada: item,
                                  nombreAlumno: _nombreAlumno(item),
                                  onCambio: _cargar,
                                ),
                      ),
                    );
                  },
                ),
    );
  }
}
