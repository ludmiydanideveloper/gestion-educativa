import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mensaje.dart';
import '../services/supabase_service.dart';

class DetalleMensaje extends StatefulWidget {
  final Mensaje mensaje;

  const DetalleMensaje({
    super.key,
    required this.mensaje,
  });

  @override
  State<DetalleMensaje> createState() => _DetalleMensajeState();
}

class _DetalleMensajeState extends State<DetalleMensaje> {
  final _supabaseService = SupabaseService();
  bool _firmaCompletada = false;
  bool _firmando = false;

  @override
  void initState() {
    super.initState();
    _marcarLeidoAutomatico();
  }

  // Regla de Negocio Crítica: Marcado asíncrono e invisible de lectura en initState
  void _marcarLeidoAutomatico() {
    if (!widget.mensaje.esLeido) {
      _supabaseService.marcarMensajeComoLeido(widget.mensaje.destinatarioId).then((_) {
        debugPrint('Mensaje ${widget.mensaje.mensajeId} marcado como leído en base de datos.');
      }).catchError((error) {
        debugPrint('Error silencioso al marcar como leído: $error');
      });
    }
  }

  void _simularFirmaDigital() {
    setState(() {
      _firmando = true;
    });

    // Simulamos un retraso para autenticación biométrica/criptográfica
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _firmando = false;
          _firmaCompletada = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.verified_user_rounded, color: Colors.white),
                SizedBox(width: 12.0),
                Text('Acuse de Recibo con Firma Digital Registrado Exitosamente'),
              ],
            ),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Obtener el rol del usuario autenticado actual de Supabase
    final user = Supabase.instance.client.auth.currentUser;
    final rol = user?.userMetadata?['rol'] as String?;
    final esFamilia = rol == 'ALUMNO' || rol == 'PADRE';
    
    final fecha = widget.mensaje.fechaCreacion.toLocal();
    final fechaStr = "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} a las ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')} hs";

    final cuerpoTexto = widget.mensaje.cuerpo['texto']?.toString() ?? 'Sin contenido';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Comunicado'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Asunto del Mensaje
            Text(
              widget.mensaje.asunto,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12.0),
            
            // Metadatos: Fecha y Emisor
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16.0,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    fechaStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24.0),
            const Divider(height: 1.0),
            const SizedBox(height: 24.0),

            // Cuerpo del Comunicado
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withAlpha(76),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cuerpoTexto,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: colorScheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32.0),

            // Sección de Firma Digital si el comunicado lo requiere y el usuario es de la familia
            if (widget.mensaje.requiereFirma && esFamilia) ...[
              Card(
                elevation: 0,
                color: _firmaCompletada 
                    ? Colors.green.shade50
                    : colorScheme.errorContainer.withAlpha(25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  side: BorderSide(
                    color: _firmaCompletada 
                        ? Colors.green.shade300
                        : colorScheme.error.withAlpha(102),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _firmaCompletada ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                            color: _firmaCompletada ? Colors.green.shade800 : colorScheme.error,
                            size: 24.0,
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Text(
                              _firmaCompletada 
                                  ? 'Acuse de recibo firmado digitalmente'
                                  : 'Este comunicado requiere firma del tutor legal',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _firmaCompletada ? Colors.green.shade800 : colorScheme.onErrorContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        _firmaCompletada 
                            ? 'Firma registrada con éxito en el servidor de auditoría escolar.'
                            : 'Al hacer clic en "Firmar Notificación", registrará su acuse de recibo y conformidad legal.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _firmaCompletada ? Colors.green.shade700 : colorScheme.onSurfaceVariant,
                            ),
                      ),
                      if (!_firmaCompletada) ...[
                        const SizedBox(height: 16.0),
                        ElevatedButton.icon(
                          onPressed: _firmando ? null : _simularFirmaDigital,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            foregroundColor: colorScheme.onError,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                          ),
                          icon: _firmando 
                              ? const SizedBox(
                                  width: 18.0,
                                  height: 18.0,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.draw_rounded),
                          label: Text(_firmando ? 'Procesando firma...' : 'Firmar Notificación'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
            ],
          ],
        ),
      ),
    );
  }
}
