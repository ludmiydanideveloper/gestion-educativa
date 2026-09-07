import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';

/// Portal docente del gabinete EOE para un curso.
///
/// El docente ve a los alumnos de su curso con adecuación curricular activa,
/// consulta la ficha y los documentos del gabinete, agrega notas a la bitácora
/// de acompañamiento y puede subir una evaluación original para que el EOE la
/// adecúe. Todo persiste (eoe_ficha / eoe_bitacora / eoe_documentos).
class PanelEoeDocente extends StatefulWidget {
  final String cursoId;
  final String identificadorDivision;

  const PanelEoeDocente({
    super.key,
    required this.cursoId,
    required this.identificadorDivision,
  });

  @override
  State<PanelEoeDocente> createState() => _PanelEoeDocenteState();
}

class _PanelEoeDocenteState extends State<PanelEoeDocente> {
  final _service = SupabaseService();
  bool _loading = true;
  List<Map<String, dynamic>> _fichas = [];
  Map<String, dynamic>? _selected;

  final _notaCtrl = TextEditingController();
  bool _savingNota = false;

  List<Map<String, dynamic>> _bitacora = [];
  List<Map<String, dynamic>> _documentos = [];
  bool _loadingDetalle = false;

  @override
  void initState() {
    super.initState();
    _cargarFichas();
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarFichas() async {
    setState(() => _loading = true);
    try {
      final fichas = await _service.obtenerFichasEoe(cursoId: widget.cursoId);
      setState(() {
        _fichas = fichas;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error cargando fichas EOE: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _seleccionar(Map<String, dynamic> ficha) async {
    setState(() {
      _selected = ficha;
      _loadingDetalle = true;
      _bitacora = [];
      _documentos = [];
    });
    final legajoId = ficha['legajo_id'].toString();
    final bit = await _service.obtenerBitacoraEoe(legajoId);
    final docs = await _service.obtenerDocumentosEoe(legajoId);
    if (!mounted) return;
    setState(() {
      _bitacora = bit;
      _documentos = docs;
      _loadingDetalle = false;
    });
  }

  Future<void> _agregarNota() async {
    if (_selected == null || _notaCtrl.text.trim().isEmpty) return;
    setState(() => _savingNota = true);
    try {
      await _service.agregarNotaBitacoraEoe(
        legajoId: _selected!['legajo_id'].toString(),
        nota: _notaCtrl.text.trim(),
      );
      _notaCtrl.clear();
      await _seleccionar(_selected!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Nota agregada a la bitácora de acompañamiento.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la nota: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNota = false);
    }
  }

  Future<void> _subirEvaluacionOriginal() async {
    if (_selected == null) return;
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    final f = res.files.first;
    try {
      await _service.subirDocumentoEoe(
        legajoId: _selected!['legajo_id'].toString(),
        categoria: 'EVAL_ORIGINAL',
        bytes: f.bytes!,
        fileName: f.name,
        observaciones: 'Subida por el docente para adecuación del gabinete.',
      );
      await _seleccionar(_selected!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📤 Evaluación enviada al gabinete para su adecuación.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _descargar(Map<String, dynamic> doc) async {
    final path = doc['storage_path']?.toString();
    if (path == null || path.isEmpty) return;
    try {
      final url = await _service.urlFirmadaStorage('eoe', path);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Gabinete EOE - ${widget.identificadorDivision}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _cargarFichas,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Lista de alumnos con adecuación
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: colorScheme.outlineVariant.withAlpha(80))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Alumnos con Adecuación Curricular (${_fichas.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        Expanded(
                          child: _fichas.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'No hay alumnos con adecuación curricular en este curso.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _fichas.length,
                                  itemBuilder: (context, index) {
                                    final al = _fichas[index];
                                    final isSelected =
                                        _selected?['legajo_id'] == al['legajo_id'];
                                    return ListTile(
                                      selected: isSelected,
                                      selectedTileColor: colorScheme.primaryContainer.withAlpha(30),
                                      leading: CircleAvatar(
                                        backgroundColor: colorScheme.secondary.withAlpha(20),
                                        child: Icon(Icons.person_rounded, color: colorScheme.secondary),
                                      ),
                                      title: Text(
                                        al['nombre_completo'] ?? 'Alumno',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        'Adecuación: ${al['tipo_adecuacion'] ?? "General"}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                                      onTap: () => _seleccionar(al),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Detalle
                Expanded(
                  flex: 3,
                  child: _selected == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_ind_rounded, size: 64, color: colorScheme.secondary.withAlpha(60)),
                              const SizedBox(height: 12),
                              const Text(
                                'Seleccione un alumno para ver su ficha EOE',
                                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : _buildDetalle(colorScheme),
                ),
              ],
            ),
    );
  }

  Widget _buildDetalle(ColorScheme colorScheme) {
    final al = _selected!;
    final form = Map<String, dynamic>.from(al['datos_formulario'] as Map? ?? {});

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            al['nombre_completo'] ?? 'Alumno',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.primary),
          ),
          const SizedBox(height: 16),

          // Ficha de adecuación
          Card(
            elevation: 0,
            color: colorScheme.primaryContainer.withAlpha(25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.primary.withAlpha(40)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Colors.indigo),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pautas de Adecuación Curricular (${al['tipo_adecuacion'] ?? "General"})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (al['detalles'] ?? '').toString().isEmpty
                        ? 'Sin especificaciones cargadas por el gabinete.'
                        : al['detalles'].toString(),
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                  if (form.isNotEmpty) ...[
                    const Divider(height: 20),
                    ...form.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text.rich(TextSpan(children: [
                              TextSpan(
                                  text: '${_labelCampo(e.key)}: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              TextSpan(text: e.value.toString(), style: const TextStyle(fontSize: 12)),
                            ])),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _loadingDetalle
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      // Documentos del gabinete
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Documentos del Gabinete',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          TextButton.icon(
                            onPressed: _subirEvaluacionOriginal,
                            icon: const Icon(Icons.upload_file_rounded, size: 16),
                            label: const Text('Subir evaluación', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_documentos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Sin documentos cargados todavía.',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        )
                      else
                        ..._documentos.map((d) => Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Icon(_iconoCategoria(d['categoria']), size: 20, color: colorScheme.primary),
                                title: Text(d['nombre'] ?? 'Documento', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${_labelCategoria(d['categoria'])} · ${d['estado'] ?? ''}'
                                  '${(d['observaciones_eoe'] ?? '').toString().isNotEmpty ? '\n${d['observaciones_eoe']}' : ''}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                isThreeLine: (d['observaciones_eoe'] ?? '').toString().isNotEmpty,
                                trailing: (d['storage_path'] != null && d['storage_path'].toString().isNotEmpty)
                                    ? IconButton(
                                        icon: const Icon(Icons.download_rounded, size: 18),
                                        onPressed: () => _descargar(d),
                                      )
                                    : null,
                              ),
                            )),

                      const SizedBox(height: 16),
                      const Text('Bitácora de Acompañamiento EOE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _notaCtrl,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Registrar evolución, pauta o incidencia...',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _savingNota ? null : _agregarNota,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: _savingNota
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Agregar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_bitacora.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Sin notas en la bitácora todavía.',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        )
                      else
                        ..._bitacora.map((item) => Card(
                              elevation: 0,
                              color: Colors.grey.shade50,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${item['autor_nombre'] ?? 'Autor'} · ${item['autor_rol'] ?? ''}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                                        ),
                                        Text(
                                          (item['fecha'] ?? '').toString(),
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(item['nota'] ?? '', style: const TextStyle(fontSize: 12, height: 1.3)),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _labelCampo(String k) {
    switch (k) {
      case 'diagnostico':
        return 'Diagnóstico';
      case 'profesional':
        return 'Profesional tratante';
      case 'vigencia':
        return 'Vigencia';
      case 'apoyos':
        return 'Apoyos';
      case 'observaciones':
        return 'Observaciones';
      default:
        return k[0].toUpperCase() + k.substring(1);
    }
  }

  String _labelCategoria(String? c) {
    switch (c) {
      case 'INFORME':
        return 'Informe';
      case 'PAUTAS':
        return 'Pautas';
      case 'EVAL_ORIGINAL':
        return 'Evaluación original';
      case 'EVAL_ADECUADA':
        return 'Evaluación adecuada';
      default:
        return c ?? 'Documento';
    }
  }

  IconData _iconoCategoria(String? c) {
    switch (c) {
      case 'EVAL_ADECUADA':
        return Icons.verified_rounded;
      case 'EVAL_ORIGINAL':
        return Icons.description_rounded;
      case 'PAUTAS':
        return Icons.rule_rounded;
      default:
        return Icons.folder_shared_rounded;
    }
  }
}
