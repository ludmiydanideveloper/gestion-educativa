import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../services/print_helper.dart';

/// Repositorio de documentos institucionales GENERALES — no confundir con
/// el Repositorio Pedagógico (que es por materia y lo sube el docente).
/// Acá sube Dirección material de referencia para todo el personal, ej. una
/// guía para completar el Libro de Temas.
class PanelRepositorioDocumentos extends StatefulWidget {
  const PanelRepositorioDocumentos({super.key});

  @override
  State<PanelRepositorioDocumentos> createState() => _PanelRepositorioDocumentosState();
}

class _PanelRepositorioDocumentosState extends State<PanelRepositorioDocumentos> {
  final _service = SupabaseService();
  bool _loading = true;
  List<Map<String, dynamic>> _documentos = [];
  String _searchQuery = '';

  bool get _puedeGestionar {
    final rol = Supabase.instance.client.auth.currentUser?.userMetadata?['rol'] as String?;
    return rol == 'ADMIN' || rol == 'PRECEPTOR' || rol == 'DIRECTIVO';
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      _documentos = await _service.obtenerDocumentosInstitucionales();
    } catch (e) {
      debugPrint('Error cargando repositorio institucional: $e');
      _documentos = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _abrirModalSubirDocumento() {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    List<int>? archivoBytes;
    String? archivoNombre;
    bool subiendo = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.upload_file_rounded, color: Color(0xFF6A4C9C)),
                  SizedBox(width: 8),
                  Text('Subir Documento'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Para todo el personal: guías, instructivos, circulares de referencia.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Documento',
                        hintText: 'Ej. Guía para completar el Libro de Temas',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final res = await FilePicker.platform.pickFiles(withData: true);
                        if (res != null && res.files.isNotEmpty) {
                          setModalState(() {
                            archivoBytes = res.files.first.bytes;
                            archivoNombre = res.files.first.name;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6A4C9C).withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF6A4C9C).withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            Icon(archivoNombre == null ? Icons.attach_file_rounded : Icons.check_circle_rounded,
                                color: const Color(0xFF6A4C9C)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                archivoNombre ?? 'Adjuntar archivo',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
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
                TextButton(
                  onPressed: subiendo ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A4C9C)),
                  onPressed: subiendo
                      ? null
                      : () async {
                          if (nombreCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ingresá un nombre para el documento')),
                            );
                            return;
                          }
                          if (archivoBytes == null || archivoNombre == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Adjuntá un archivo')),
                            );
                            return;
                          }
                          setModalState(() => subiendo = true);
                          try {
                            await _service.subirDocumentoInstitucional(
                              nombre: nombreCtrl.text.trim(),
                              descripcion: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                              bytes: archivoBytes!,
                              fileName: archivoNombre!,
                            );
                            if (context.mounted) Navigator.pop(context);
                            await _cargar();
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Documento cargado al repositorio con éxito'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            setModalState(() => subiendo = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: subiendo
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Subir Archivo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _descargar(Map<String, dynamic> doc) async {
    try {
      final url = await _service.urlFirmadaStorage('institucional', doc['storage_path'].toString());
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: $e')),
        );
      }
    }
  }

  Future<void> _eliminar(Map<String, dynamic> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar documento'),
        content: Text('¿Eliminar "${doc['nombre']}"? Esta acción no se puede deshacer.'),
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
      await _service.eliminarDocumentoInstitucional(doc['id'].toString());
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  void _imprimirListaDocumentos() {
    final rowsHtml = _documentos.map((doc) {
      final fecha = (doc['created_at'] ?? '').toString().split('T').first;
      return '''
        <tr>
          <td>${doc['nombre']}</td>
          <td>${doc['descripcion'] ?? ''}</td>
          <td>${doc['subido_por_nombre'] ?? ''}</td>
          <td>$fecha</td>
        </tr>
      ''';
    }).join('');

    final tableHtml = '''
      <h2>Repositorio de Documentos Institucionales</h2>
      <table>
        <thead>
          <tr>
            <th>Documento</th>
            <th>Descripción</th>
            <th>Subido por</th>
            <th>Fecha</th>
          </tr>
        </thead>
        <tbody>
          $rowsHtml
        </tbody>
      </table>
    ''';

    PrintHelper.imprimirHTML(
      titulo: 'Repositorio de Documentos',
      htmlContentBody: tableHtml,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _documentos.where((doc) {
      final q = _searchQuery.toLowerCase();
      return doc['nombre'].toString().toLowerCase().contains(q) ||
          (doc['descripcion'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repositorio de Documentos', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Imprimir listado de documentos',
            onPressed: _imprimirListaDocumentos,
          ),
        ],
      ),
      floatingActionButton: _puedeGestionar
          ? FloatingActionButton.extended(
              onPressed: _abrirModalSubirDocumento,
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Subir Documento', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar documentos...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              _documentos.isEmpty
                                  ? 'Todavía no hay documentos cargados.'
                                  : 'No hay documentos que coincidan con la búsqueda.',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              final fecha = (doc['created_at'] ?? '').toString().split('T').first;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blueGrey.shade50,
                                    child: const Icon(Icons.description_rounded, color: Colors.blueGrey),
                                  ),
                                  title: Text(doc['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    '${(doc['descripcion'] ?? '').toString().isNotEmpty ? '${doc['descripcion']}\n' : ''}'
                                    'Por: ${doc['subido_por_nombre'] ?? 'Dirección'} · $fecha',
                                  ),
                                  isThreeLine: (doc['descripcion'] ?? '').toString().isNotEmpty,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.download_rounded),
                                        tooltip: 'Descargar',
                                        onPressed: () => _descargar(doc),
                                      ),
                                      if (_puedeGestionar)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                          tooltip: 'Eliminar',
                                          onPressed: () => _eliminar(doc),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
