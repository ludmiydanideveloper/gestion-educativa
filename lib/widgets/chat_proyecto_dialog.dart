import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Abre el chat interno de un proyecto institucional: lo pueden usar tanto
/// Dirección (ADMIN/PRECEPTOR) como los docentes marcados como involucrados
/// — la política RLS de proy_mensajes es la que decide quién puede entrar.
Future<void> mostrarChatProyecto(
  BuildContext context, {
  required String proyectoId,
  required String nombreProyecto,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ChatProyectoSheet(proyectoId: proyectoId, nombreProyecto: nombreProyecto),
  );
}

class _ChatProyectoSheet extends StatefulWidget {
  final String proyectoId;
  final String nombreProyecto;

  const _ChatProyectoSheet({required this.proyectoId, required this.nombreProyecto});

  @override
  State<_ChatProyectoSheet> createState() => _ChatProyectoSheetState();
}

class _ChatProyectoSheetState extends State<_ChatProyectoSheet> {
  final _service = SupabaseService();
  final _textoCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _mensajes = [];
  bool _cargando = true;
  bool _enviando = false;
  Timer? _poll;

  String? get _miAuthId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _cargar(scrollAlFinal: true);
    // Sin websockets en este proyecto: un poll liviano mientras el chat está
    // abierto alcanza para que se sienta "vivo" sin sumar infraestructura.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _cargar());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _textoCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool scrollAlFinal = false}) async {
    try {
      final msgs = await _service.obtenerMensajesProyecto(widget.proyectoId);
      if (!mounted) return;
      final huboNuevos = msgs.length != _mensajes.length;
      setState(() {
        _mensajes = msgs;
        _cargando = false;
      });
      if ((scrollAlFinal || huboNuevos) && _scrollCtrl.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _enviar() async {
    final texto = _textoCtrl.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      await _service.enviarMensajeProyecto(proyectoId: widget.proyectoId, texto: texto);
      _textoCtrl.clear();
      await _cargar(scrollAlFinal: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String _hora(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final alto = MediaQuery.of(context).size.height * 0.75;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: alto,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.forum_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chat del proyecto',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text(widget.nombreProyecto,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _mensajes.isEmpty
                      ? Center(
                          child: Text(
                            'Todavía no hay mensajes.\nEscribí el primero.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: _mensajes.length,
                          itemBuilder: (context, i) {
                            final m = _mensajes[i];
                            final esPropio = m['autor_auth_id'] == _miAuthId;
                            return Align(
                              alignment: esPropio ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: esPropio ? colorScheme.primary : Colors.grey.shade200,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(14),
                                    topRight: const Radius.circular(14),
                                    bottomLeft: Radius.circular(esPropio ? 14 : 2),
                                    bottomRight: Radius.circular(esPropio ? 2 : 14),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!esPropio)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Text(
                                          (m['autor_nombre'] ?? 'Alguien').toString(),
                                          style: TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.primary),
                                        ),
                                      ),
                                    Text(
                                      (m['texto'] ?? '').toString(),
                                      style: TextStyle(color: esPropio ? Colors.white : Colors.black87, fontSize: 14),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _hora(m['created_at']?.toString()),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: esPropio ? Colors.white70 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textoCtrl,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _enviar(),
                        decoration: InputDecoration(
                          hintText: 'Escribí un mensaje...',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _enviando ? null : _enviar,
                      icon: _enviando
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
