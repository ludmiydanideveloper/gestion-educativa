import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/alerta.dart';
import '../services/supabase_service.dart';

class PanelAlertas extends StatefulWidget {
  const PanelAlertas({super.key});

  @override
  State<PanelAlertas> createState() => _PanelAlertasState();
}

class _PanelAlertasState extends State<PanelAlertas> {
  late final Stream<List<Map<String, dynamic>>> _alertasStream;
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    // Persistimos el stream en el estado del widget para evitar reconexiones en rebuilds.
    // Escucha alertas en tiempo real con estado PENDIENTE, ordenadas por fecha de creación.
    _alertasStream = Supabase.instance.client
        .from('acad_alertas')
        .stream(primaryKey: ['alerta_id'])
        .eq('estado', 'PENDIENTE')
        .order('fecha_creacion');
  }

  Future<void> _resolverAlerta(Alerta alerta) async {
    try {
      await _supabaseService.marcarAlertaResuelta(alerta.alertaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text('Alerta para el alumno resolutiva marcada como RESUELTA.'),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            margin: const EdgeInsets.all(16.0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al resolver alerta: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Panel de Alertas Académicas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _alertasStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error de comunicación en tiempo real: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            );
          }

          final rawData = snapshot.data ?? [];
          if (rawData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 64.0,
                    color: colorScheme.onSurfaceVariant.withAlpha(127),
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'No hay alertas pendientes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'El alumnado se mantiene bajo los límites reglamentarios.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withAlpha(178),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final alertas = rawData.map((json) => Alerta.fromJson(json)).toList();

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: alertas.length,
            itemBuilder: (context, index) {
              final alerta = alertas[index];
              final esCritica = alerta.gravedad == 'CRITICA';
              
              // Formateo simple de fecha
              final fecha = alerta.fechaCreacion;
              final fechaStr = "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} a las ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')} hs";

              return Dismissible(
                key: Key(alerta.alertaId),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _resolverAlerta(alerta),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24.0),
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Resolver',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8.0),
                      Icon(Icons.check_rounded, color: Colors.white),
                    ],
                  ),
                ),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    side: BorderSide(
                      color: esCritica 
                          ? Colors.red.withAlpha(51) 
                          : Colors.orange.withAlpha(51),
                      width: 1.0,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Borde de Gravedad Destacado (Rojo para Crítica, Naranja para Media/Alta)
                        Container(
                          width: 6.0,
                          color: esCritica ? Colors.red : Colors.orange,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Tipo de alerta e Icono
                                    Row(
                                      children: [
                                        Icon(
                                          esCritica 
                                              ? Icons.warning_amber_rounded 
                                              : Icons.info_outline_rounded,
                                          color: esCritica ? Colors.red : Colors.orange,
                                          size: 20.0,
                                        ),
                                        const SizedBox(width: 8.0),
                                        Text(
                                          alerta.tipoAlerta,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: esCritica ? Colors.red.shade800 : Colors.orange.shade800,
                                            fontSize: 13.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Fecha
                                    Text(
                                      fechaStr,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12.0),
                                // Mensaje de la Alerta (Generado por el Trigger)
                                Text(
                                  alerta.mensaje,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                const SizedBox(height: 12.0),
                                // Fila de Estado e Interacciones de botón
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                      decoration: BoxDecoration(
                                        color: esCritica 
                                            ? Colors.red.shade50 
                                            : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(20.0),
                                      ),
                                      child: Text(
                                        alerta.gravedad,
                                        style: TextStyle(
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.bold,
                                          color: esCritica 
                                              ? Colors.red.shade800 
                                              : Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                    IconButton.filledTonal(
                                      onPressed: () => _resolverAlerta(alerta),
                                      icon: const Icon(Icons.done_all_rounded, size: 18.0),
                                      tooltip: 'Marcar como gestionada',
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.green.shade50,
                                        foregroundColor: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
