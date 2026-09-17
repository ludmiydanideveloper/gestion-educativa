import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/chat_proyecto_dialog.dart';

/// Proyectos institucionales donde el docente figura como involucrado.
/// Solo lectura + chat interno — crear/editar/subir archivos sigue siendo
/// exclusivo de Dirección desde el Panel de Administración.
class PanelMisProyectos extends StatefulWidget {
  const PanelMisProyectos({super.key});

  @override
  State<PanelMisProyectos> createState() => _PanelMisProyectosState();
}

class _PanelMisProyectosState extends State<PanelMisProyectos> {
  final _service = SupabaseService();
  bool _loading = true;
  List<Map<String, dynamic>> _proyectos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      _proyectos = await _service.obtenerMisProyectos();
    } catch (e) {
      debugPrint('Error cargando mis proyectos: $e');
      _proyectos = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _labelEstado(String e) {
    switch (e) {
      case 'PLANIFICADO':
        return 'Planificado';
      case 'EN_CURSO':
        return 'En curso';
      case 'FINALIZADO':
        return 'Finalizado';
      case 'SUSPENDIDO':
        return 'Suspendido';
      default:
        return e;
    }
  }

  Future<void> _verArchivos(Map<String, dynamic> p) async {
    final docs = await _service.obtenerDocsProyecto(p['id'].toString());
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Archivos — ${p['nombre']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 380,
          child: docs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Sin archivos.', style: TextStyle(color: Colors.grey)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: docs
                      .map((d) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.insert_drive_file_rounded, size: 20),
                            title: Text('${d['nombre']}', style: const TextStyle(fontSize: 13)),
                            trailing: IconButton(
                              icon: const Icon(Icons.download_rounded, size: 18),
                              onPressed: () async {
                                try {
                                  final url = await _service.urlFirmadaStorage('proyectos', d['storage_path'].toString());
                                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ))
                      .toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: AppDrawer.buildLeading(context),
        leadingWidth: AppDrawer.buildLeadingWidth(context),
        title: const Text('Mis Proyectos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _cargar),
        ],
      ),
      drawer: const AppDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _proyectos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.groups_2_rounded, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Todavía no te sumaron como involucrado a ningún proyecto institucional.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _proyectos.length,
                  itemBuilder: (context, index) {
                    final p = _proyectos[index];
                    final estado = (p['estado'] ?? 'EN_CURSO').toString();
                    final color = estado == 'FINALIZADO'
                        ? Colors.green
                        : estado == 'SUSPENDIDO'
                            ? Colors.red
                            : estado == 'PLANIFICADO'
                                ? Colors.blueGrey
                                : Colors.blue;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: color.withAlpha(70))),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(p['nombre'] ?? 'Proyecto', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                Chip(
                                  label: Text(_labelEstado(estado), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                                  backgroundColor: color.withAlpha(25),
                                  side: BorderSide.none,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            if ((p['descripcion'] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('${p['descripcion']}', style: const TextStyle(fontSize: 13)),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              'Responsable: ${p['responsable'] ?? '—'}'
                              '${p['fecha_inicio'] != null ? ' · ${p['fecha_inicio'].toString().split('T').first}' : ''}'
                              '${p['fecha_fin'] != null ? ' a ${p['fecha_fin'].toString().split('T').first}' : ''}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => mostrarChatProyecto(
                                    context,
                                    proyectoId: p['id'].toString(),
                                    nombreProyecto: (p['nombre'] ?? 'Proyecto').toString(),
                                  ),
                                  icon: const Icon(Icons.forum_rounded, size: 16),
                                  label: const Text('Chat', style: TextStyle(fontSize: 12)),
                                ),
                                TextButton.icon(
                                  onPressed: () => _verArchivos(p),
                                  icon: const Icon(Icons.folder_rounded, size: 16),
                                  label: const Text('Archivos', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
