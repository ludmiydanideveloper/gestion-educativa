import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
      _evaluaciones = await _service.obtenerBancoEvaluaciones(
        materiaId: widget.materiaId,
        cursoId: widget.cursoId,
      );
    } catch (e) {
      debugPrint('Error cargando banco de evaluaciones: $e');
      _evaluaciones = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _descargar(Map<String, dynamic> item) async {
    final path = item['storage_path']?.toString();
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta evaluación no tiene archivo adjunto.')),
      );
      return;
    }
    try {
      final url = await _service.urlFirmadaStorage('banco-evaluaciones', path);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el archivo.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: $e')),
        );
      }
    }
  }

  Future<void> _subirPropuesta() async {
    final tituloCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String tipoSel = 'Parcial Trimestral';
    final user = Supabase.instance.client.auth.currentUser;
    final nombreDocente = user?.userMetadata?['nombre'] as String? ?? user?.email ?? 'Docente';
    List<int>? archivoBytes;
    String? archivoNombre;
    bool subiendo = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
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
                  initialValue: tipoSel,
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
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final res = await FilePicker.platform.pickFiles(
                      withData: true,
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'doc', 'docx'],
                    );
                    if (res != null && res.files.isNotEmpty) {
                      setDlg(() {
                        archivoBytes = res.files.first.bytes;
                        archivoNombre = res.files.first.name;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.primaryContainer.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(ctx).colorScheme.primary.withAlpha(100)),
                    ),
                    child: Row(
                      children: [
                        Icon(archivoNombre == null ? Icons.attach_file_rounded : Icons.check_circle_rounded,
                            color: Theme.of(ctx).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            archivoNombre ?? 'Adjuntar archivo (.pdf / .doc / .docx)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: subiendo ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton.icon(
              icon: subiendo
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Subir'),
              onPressed: subiendo
                  ? null
                  : () async {
                      if (tituloCtrl.text.trim().isEmpty) return;
                      setDlg(() => subiendo = true);
                      try {
                        final fila = await _service.subirEvaluacionBanco(
                          materiaId: widget.materiaId,
                          cursoId: widget.cursoId,
                          titulo: tituloCtrl.text.trim(),
                          descripcion: descCtrl.text.trim(),
                          tipo: tipoSel,
                          bytes: archivoBytes,
                          fileName: archivoNombre,
                          aprobarAlSubir: _esAdmin,
                        );
                        if (!_esAdmin) {
                          _service.obtenerAuthIdsAdministracion().then((adminIds) {
                            _service.notificarSistema(
                              asunto: '📋 Evaluación pendiente de aprobación: ${tituloCtrl.text.trim()}',
                              texto: '$nombreDocente subió la evaluación "${tituloCtrl.text.trim()}" (${widget.nombreAsignatura}) para su revisión y aprobación.',
                              destinatariosAuthIds: adminIds,
                            );
                          });
                        }
                        if (mounted) setState(() => _evaluaciones.insert(0, fila));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_esAdmin
                                  ? '✅ Evaluación agregada y APROBADA en el banco institucional.'
                                  : '📤 Evaluación enviada a revisión. El Administrador recibirá una notificación para aprobarla.'),
                              backgroundColor: _esAdmin ? Colors.green : Colors.blue,
                            ),
                          );
                        }
                      } catch (e) {
                        setDlg(() => subiendo = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(Map<String, dynamic> item, String nuevoEstado) async {
    setState(() {
      item['estado'] = nuevoEstado;
    });
    try {
      if (item['id'] != null) {
        await _service.cambiarEstadoEvaluacionBanco(item['id'].toString(), nuevoEstado);
      }
    } catch (e) {
      debugPrint('Error cambiando estado de evaluación: $e');
    }
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
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_rounded, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text('Subido por: ${item['subido_por'] ?? 'Docente'}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                    ),
                                  ],
                                ),
                                OutlinedButton.icon(
                                  onPressed: (item['storage_path'] != null && item['storage_path'].toString().isNotEmpty)
                                      ? () => _descargar(item)
                                      : null,
                                  icon: const Icon(Icons.download_rounded, size: 16),
                                  label: Text(
                                      (item['storage_path'] != null && item['storage_path'].toString().isNotEmpty)
                                          ? 'Descargar archivo'
                                          : 'Sin archivo',
                                      style: const TextStyle(fontSize: 12)),
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
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 20),
                                        const SizedBox(width: 10),
                                        const Flexible(
                                          child: Text(
                                            'Revisión Administrativa requerida para publicar en el banco institucional:',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _cambiarEstado(item, 'RECHAZADA'),
                                          icon: const Icon(Icons.close_rounded, color: Colors.red, size: 16),
                                          label: const Text('Rechazar', style: TextStyle(color: Colors.red, fontSize: 12)),
                                        ),
                                        FilledButton.icon(
                                          onPressed: () => _cambiarEstado(item, 'APROBADA'),
                                          icon: const Icon(Icons.check_rounded, size: 16),
                                          label: const Text('Aprobar Evaluación', style: TextStyle(fontSize: 12)),
                                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                        ),
                                      ],
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
