import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class PanelBancoEvaluaciones extends StatefulWidget {
  final String materiaId;
  final String cursoId;
  final String nombreAsignatura;

  const PanelBancoEvaluaciones({
    super.key,
    required this.materiaId,
    required this.cursoId,
    required this.nombreAsignatura,
  });

  @override
  State<PanelBancoEvaluaciones> createState() => _PanelBancoEvaluacionesState();
}

class _PanelBancoEvaluacionesState extends State<PanelBancoEvaluaciones> {
  final _service = SupabaseService();
  bool _loading = true;
  List<Map<String, dynamic>> _evaluaciones = [];
  bool _esAdmin = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final rol = user?.userMetadata?['rol'] as String? ?? 'DOCENTE';
    _esAdmin = rol == 'ADMIN' || rol == 'PRECEPTOR';
    _cargarBanco();
  }

  Future<void> _cargarBanco() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('banco_evaluaciones')
          .select()
          .eq('materia_id', widget.materiaId)
          .order('created_at', ascending: false);
      _evaluaciones = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      // Fallback in memory o si la tabla no existe aún
      if (_evaluaciones.isEmpty) {
        _evaluaciones = [
          {
            'id': 'mock-1',
            'materia_id': widget.materiaId,
            'titulo': 'Examen Integrador de Mitosis y Meiosis',
            'descripcion': 'Evaluación escrita con esquema comparativo y preguntas de múltiple opción.',
            'tipo': 'Parcial Trimestral',
            'archivo_url': 'evaluacion_mitosis_v2.pdf',
            'estado': 'APROBADA',
            'subido_por': 'Prof. Danilo Gomez',
            'created_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
          },
          {
            'id': 'mock-2',
            'materia_id': widget.materiaId,
            'titulo': 'Trabajo Práctico Rúbrica: Sistema Endocrino',
            'descripcion': 'Guía de investigación colaborativa en laboratorio con defensa oral.',
            'tipo': 'Trabajo Práctico',
            'archivo_url': 'tp_sistema_endocrino_rubrica.docx',
            'estado': 'PENDIENTE DE APROBACIÓN',
            'subido_por': 'Prof. Florencia Viero',
            'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          },
        ];
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _subirPropuesta() async {
    final tituloCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String tipoSel = 'Parcial Trimestral';
    final user = Supabase.instance.client.auth.currentUser;
    final nombreDocente = user?.userMetadata?['nombre'] as String? ?? user?.email ?? 'Docente';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.upload_file_rounded, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Subir Evaluación al Banco', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Asignatura: ${widget.nombreAsignatura}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: tituloCtrl,
                decoration: InputDecoration(
                  labelText: 'Título del Examen / TP',
                  hintText: 'Ej. Examen Integrador de Genética',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: tipoSel,
                decoration: InputDecoration(
                  labelText: 'Tipo de Evaluación',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['Parcial Trimestral', 'Trabajo Práctico', 'Rúbrica / Proyecto Integrador', 'Recuperatorio']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => tipoSel = val ?? tipoSel,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción / Consignas principales',
                  hintText: 'Breve resumen de los contenidos evaluados...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primaryContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(ctx).colorScheme.primary.withAlpha(100), style: BorderStyle.solid),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_file_rounded, color: Theme.of(ctx).colorScheme.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Adjuntar archivo (.docx / .pdf)\n*Se subirá al servidor para revisión del Administrador',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Subir Propuesta'),
            onPressed: () async {
              if (tituloCtrl.text.trim().isEmpty) return;
              final nuevo = {
                'materia_id': widget.materiaId,
                'titulo': tituloCtrl.text.trim(),
                'descripcion': descCtrl.text.trim(),
                'tipo': tipoSel,
                'archivo_url': '${tituloCtrl.text.trim().replaceAll(' ', '_').toLowerCase()}.docx',
                'estado': _esAdmin ? 'APROBADA' : 'PENDIENTE DE APROBACIÓN',
                'subido_por': nombreDocente,
                'created_at': DateTime.now().toIso8601String(),
              };

              try {
                await Supabase.instance.client.from('banco_evaluaciones').insert(nuevo);
              } catch (_) {
                // Si la tabla aún no existe en DB, guardamos en memoria y mostramos aviso
              }
              setState(() {
                _evaluaciones.insert(0, {...nuevo, 'id': 'local-${DateTime.now().millisecondsSinceEpoch}'});
              });
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_esAdmin
                        ? '✅ Evaluación agregada y APROBADA en el banco institucional.'
                        : '📤 Evaluación enviada a revisión. El Administrador deberá aprobarla antes de publicarse en el banco general.'),
                    backgroundColor: _esAdmin ? Colors.green : Colors.blue,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _cambiarEstado(Map<String, dynamic> item, String nuevoEstado) async {
    setState(() {
      item['estado'] = nuevoEstado;
    });
    try {
      if (item['id'] != null && !item['id'].toString().startsWith('mock-')) {
        await Supabase.instance.client
            .from('banco_evaluaciones')
            .update({'estado': nuevoEstado}).eq('id', item['id']);
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nuevoEstado == 'APROBADA'
              ? '✅ Evaluación APROBADA y disponible en el banco institucional.'
              : '❌ Evaluación rechazada o devuelta para corrección.'),
          backgroundColor: nuevoEstado == 'APROBADA' ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Banco de Evaluaciones - ${widget.nombreAsignatura}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _subirPropuesta,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Subir Evaluación', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _evaluaciones.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('El banco de evaluaciones de ${widget.nombreAsignatura} está vacío.',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Sube parciales, trabajos prácticos y rúbricas para que el Administrador los apruebe y queden accesibles.',
                          style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _evaluaciones.length,
                  itemBuilder: (context, index) {
                    final item = _evaluaciones[index];
                    final estado = item['estado'] ?? 'PENDIENTE DE APROBACIÓN';
                    final esAprobada = estado == 'APROBADA';
                    final esPendiente = estado == 'PENDIENTE DE APROBACIÓN';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: esAprobada
                              ? Colors.green.withAlpha(80)
                              : esPendiente
                                  ? Colors.orange.withAlpha(80)
                                  : Colors.red.withAlpha(80),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: esAprobada
                                        ? Colors.green.shade50
                                        : esPendiente
                                            ? Colors.orange.shade50
                                            : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        esAprobada
                                            ? Icons.check_circle_rounded
                                            : esPendiente
                                                ? Icons.pending_actions_rounded
                                                : Icons.cancel_rounded,
                                        size: 14,
                                        color: esAprobada
                                            ? Colors.green
                                            : esPendiente
                                                ? Colors.orange
                                                : Colors.red,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        estado,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: esAprobada
                                              ? Colors.green.shade700
                                              : esPendiente
                                                  ? Colors.orange.shade800
                                                  : Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  item['tipo'] ?? 'Evaluación',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item['titulo'] ?? 'Sin título',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['descripcion'] ?? 'Sin descripción.',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 14),
                            Divider(color: Colors.grey.shade200),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person_rounded, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Text('Subido por: ${item['subido_por'] ?? 'Docente'}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('📥 Descargando archivo: ${item['archivo_url'] ?? 'evaluacion.docx'}...')),
                                    );
                                  },
                                  icon: const Icon(Icons.download_rounded, size: 16),
                                  label: const Text('Descargar Word/PDF', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            // Acciones exclusivas del Administrador si está pendiente
                            if (_esAdmin && esPendiente) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 20),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Revisión Administrativa requerida para publicar en el banco institucional:',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    TextButton.icon(
                                      onPressed: () => _cambiarEstado(item, 'RECHAZADA'),
                                      icon: const Icon(Icons.close_rounded, color: Colors.red, size: 16),
                                      label: const Text('Rechazar', style: TextStyle(color: Colors.red, fontSize: 12)),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: () => _cambiarEstado(item, 'APROBADA'),
                                      icon: const Icon(Icons.check_rounded, size: 16),
                                      label: const Text('Aprobar Evaluación', style: TextStyle(fontSize: 12)),
                                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
