import 'package:flutter/material.dart';

class PanelPlanificacionDiaria extends StatefulWidget {
  final String cursoId;
  final String nombreAsignatura;

  const PanelPlanificacionDiaria({
    super.key,
    required this.cursoId,
    required this.nombreAsignatura,
  });

  @override
  State<PanelPlanificacionDiaria> createState() => _PanelPlanificacionDiariaState();
}

class _PanelPlanificacionDiariaState extends State<PanelPlanificacionDiaria> {
  final _formKey = GlobalKey<FormState>();
  final _temaCtrl = TextEditingController();
  final _objetivosCtrl = TextEditingController();
  final _actividadesCtrl = TextEditingController();
  final _materialesCtrl = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  // Mock list of previous daily plans
  final List<Map<String, dynamic>> _planificaciones = [
    {
      'fecha': '2026-07-08',
      'tema': 'Ecuaciones cuadráticas y factorización',
      'objetivos': 'Comprender la fórmula resolvente de segundo grado.',
      'actividades': 'Resolución de 5 ejercicios prácticos en parejas.',
      'materiales': 'Pizarrón, guía de ejercicios número 3.'
    },
    {
      'fecha': '2026-07-01',
      'tema': 'Función lineal y representación gráfica',
      'objetivos': 'Identificar pendiente y ordenada al origen.',
      'actividades': 'Graficar 3 funciones en ejes cartesianos.',
      'materiales': 'Hojas cuadriculadas, reglas y colores.'
    }
  ];

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _guardarPlanificacion() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _planificaciones.insert(0, {
          'fecha': _formatDate(_selectedDate),
          'tema': _temaCtrl.text.trim(),
          'objetivos': _objetivosCtrl.text.trim(),
          'actividades': _actividadesCtrl.text.trim(),
          'materiales': _materialesCtrl.text.trim(),
        });
        _temaCtrl.clear();
        _objetivosCtrl.clear();
        _actividadesCtrl.clear();
        _materialesCtrl.clear();
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Planificación Diaria guardada correctamente.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  void dispose() {
    _temaCtrl.dispose();
    _objetivosCtrl.dispose();
    _actividadesCtrl.dispose();
    _materialesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Planificación Diaria - ${widget.nombreAsignatura}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Formulario
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.primary.withAlpha(51)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.edit_note_rounded, color: Colors.blue),
                          SizedBox(width: 10),
                          Text(
                            'Nueva Planificación de Clase',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Selector de Fecha
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Fecha de la clase: ${_formatDate(_selectedDate)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2026, 1, 1),
                                lastDate: DateTime(2026, 12, 31),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDate = picked;
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_month_rounded),
                            label: const Text('Cambiar Fecha'),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Tema de la clase
                      TextFormField(
                        controller: _temaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tema de la Clase / Contenido',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),

                      // Objetivos
                      TextFormField(
                        controller: _objetivosCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Objetivos Pedagógicos / Metas',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.emoji_objects_rounded),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),

                      // Actividades
                      TextFormField(
                        controller: _actividadesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Actividades y Propuestas Didácticas',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.assignment_rounded),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),

                      // Materiales
                      TextFormField(
                        controller: _materialesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Materiales y Recursos Necesarios',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.handyman_rounded),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _guardarPlanificacion,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text(
                            'Guardar Planificación',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 28),
            const Text(
              'Historial de Planificaciones Diarias',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _planificaciones.length,
              itemBuilder: (context, index) {
                final plan = _planificaciones[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                plan['fecha']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                            const Icon(Icons.assignment_turned_in_rounded, color: Colors.green, size: 20),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          plan['tema']!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailText('Objetivos:', plan['objetivos']!),
                        _buildDetailText('Actividades:', plan['actividades']!),
                        _buildDetailText('Materiales:', plan['materiales']!),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailText(String label, String detail) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: detail),
          ],
        ),
      ),
    );
  }
}
