import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';

/// Repositorio Pedagógico visto desde la materia del docente: sube
/// planificación / contrato pedagógico / criterios de evaluación. Dirección
/// (ADMIN/PRECEPTOR) revisa desde el Panel de Administración y aprueba u
/// observa — pero si un directivo entra por acá también puede hacerlo.
class PanelPedagogicoMateria extends StatefulWidget {
  final String materiaId;
  final String cursoId;
  final String nombreAsignatura;

  const PanelPedagogicoMateria({
    super.key,
    required this.materiaId,
    required this.cursoId,
    required this.nombreAsignatura,
  });

  @override
  State<PanelPedagogicoMateria> createState() => _PanelPedagogicoMateriaState();
}

class _PanelPedagogicoMateriaState extends State<PanelPedagogicoMateria> {
  final _service = SupabaseService();
  bool _loading = true;
  bool _esAdmin = false;
  List<Map<String, dynamic>> _docs = [];

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final rol = user?.userMetadata?['rol'] as String? ?? 'DOCENTE';
    _esAdmin = rol == 'ADMIN' || rol == 'PRECEPTOR';
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      _docs = await _service.obtenerDocsPedagogicos(
        cursoId: widget.cursoId,
        materiaId: widget.materiaId,
      );
    } catch (e) {
      debugPrint('Error cargando repositorio pedagógico: $e');
      _docs = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _subir(String tipo, String label) async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    final f = res.files.first;
    try {
      await _service.subirDocPedagogico(
        cursoId: widget.cursoId,
        materiaId: widget.materiaId,
        tipo: tipo,
        bytes: f.bytes!,
        fileName: f.name,
      );
      await _cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label subido. Queda pendiente de revisión de Dirección.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _descargar(Map<String, dynamic> d) async {
    final path = d['storage_path']?.toString();
    if (path == null || path.isEmpty) return;
    try {
      final url = await _service.urlFirmadaStorage('pedagogico', path);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el archivo.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar: $e')),
      );
    }
  }

  Future<void> _eliminar(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar documento'),
        content: Text('¿Eliminar "${d['nombre']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.eliminarDocPedagogico(d['id'].toString());
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  Future<void> _cambiarEstado(Map<String, dynamic> d, String estado) async {
    try {
      await _service.actualizarDocPedagogico(id: d['id'].toString(), estado: estado);
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _observar(Map<String, dynamic> d) {
    final ctrl = TextEditingController(text: (d['observaciones'] ?? '').toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Observar documento'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Qué hay que corregir'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _service.actualizarDocPedagogico(
                  id: d['id'].toString(),
                  estado: 'OBSERVADO',
                  observaciones: ctrl.text.trim(),
                );
                await _cargar();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  String _labelTipo(dynamic t) {
    switch ((t ?? '').toString()) {
      case 'PLANIFICACION':
        return 'Planificación';
      case 'CONTRATO':
        return 'Contrato pedagógico';
      case 'CRITERIOS':
        return 'Criterios de evaluación';
      default:
        return 'Documento';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Repositorio Pedagógico — ${widget.nombreAsignatura}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(50),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Subí la planificación, el contrato pedagógico y los criterios de evaluación de esta materia. '
                    'Dirección los revisa y los aprueba u observa.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _subir('PLANIFICACION', 'Planificación'),
                      icon: const Icon(Icons.description_rounded, size: 16),
                      label: const Text('Subir planificación', style: TextStyle(fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _subir('CONTRATO', 'Contrato pedagógico'),
                      icon: const Icon(Icons.handshake_rounded, size: 16),
                      label: const Text('Subir contrato pedagógico', style: TextStyle(fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _subir('CRITERIOS', 'Criterios de evaluación'),
                      icon: const Icon(Icons.rule_rounded, size: 16),
                      label: const Text('Subir criterios de evaluación', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_docs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.folder_open_rounded, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('Todavía no hay documentos cargados para esta materia.',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  ..._docs.map(_buildDocCard),
              ],
            ),
    );
  }

  Widget _buildDocCard(Map<String, dynamic> d) {
    final estado = (d['estado'] ?? 'PENDIENTE').toString();
    final color = estado == 'APROBADO'
        ? Colors.green
        : estado == 'OBSERVADO'
            ? Colors.orange
            : Colors.blueGrey;
    final esPropio = d['subido_por_auth'] == Supabase.instance.client.auth.currentUser?.id;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withAlpha(100)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.insert_drive_file_rounded, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['nombre'] ?? 'Documento',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('${_labelTipo(d['tipo'])} · ${d['subido_por_nombre'] ?? ''}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                  child: Text(estado, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
            if ((d['observaciones'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('📝 ${d['observaciones']}', style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if ((d['storage_path'] ?? '').toString().isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _descargar(d),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Descargar', style: TextStyle(fontSize: 12)),
                  ),
                if (_esAdmin) ...[
                  TextButton.icon(
                    onPressed: () => _cambiarEstado(d, 'APROBADO'),
                    icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                    label: const Text('Aprobar', style: TextStyle(fontSize: 12, color: Colors.green)),
                  ),
                  TextButton.icon(
                    onPressed: () => _observar(d),
                    icon: const Icon(Icons.error_rounded, size: 16, color: Colors.orange),
                    label: const Text('Observar', style: TextStyle(fontSize: 12, color: Colors.orange)),
                  ),
                ],
                if (_esAdmin || esPropio)
                  TextButton.icon(
                    onPressed: () => _eliminar(d),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                    label: const Text('Eliminar', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
