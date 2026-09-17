import 'dart:async';
import 'package:flutter/material.dart';
import '../models/alerta.dart';
import '../services/supabase_service.dart';

class PanelAlertas extends StatefulWidget {
  const PanelAlertas({super.key});

  @override
  State<PanelAlertas> createState() => _PanelAlertasState();
}

class _PanelAlertasState extends State<PanelAlertas> {
  final _supabaseService = SupabaseService();
  bool _loading = true;
  List<Alerta> _alertas = [];
  List<Map<String, dynamic>> _movimientos = [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _cargar();
    // Este proyecto no tiene Realtime habilitado en Supabase (ninguna tabla
    // está en la publicación supabase_realtime), así que se refresca con un
    // poll liviano mientras la pantalla está abierta en vez de un stream.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _cargar());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    if (_alertas.isEmpty && _movimientos.isEmpty) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _supabaseService.obtenerAlertasPendientes(),
        _supabaseService.obtenerMovimientosStaff(),
      ]);
      if (!mounted) return;
      setState(() {
        _alertas = results[0].map((json) => Alerta.fromJson(json)).toList();
        _movimientos = results[1];
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatearFechaHora(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm a las $hh:$min hs';
  }

  /// El asunto queda 'Movimiento Docente: Actividad Creada (...)' — separar
  /// el rótulo de categoría del detalle para mostrarlo más prolijo.
  (String, String) _partirAsunto(String asunto) {
    final sinPrefijo = asunto.replaceFirst(RegExp(r'^Movimiento[^:]*:\s*'), '');
    final categoria = asunto.contains(':') ? asunto.substring(0, asunto.indexOf(':')) : 'Movimiento';
    return (categoria, sinPrefijo.isEmpty ? asunto : sinPrefijo);
  }

  Future<void> _resolverAlerta(Alerta alerta) async {
    setState(() => _alertas.removeWhere((a) => a.alertaId == alerta.alertaId));
    try {
      await _supabaseService.marcarAlertaResuelta(alerta.alertaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12.0),
                const Expanded(
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
      // Revertir: la alerta sigue pendiente si falló el guardado.
      if (mounted) {
        setState(() => _alertas = [..._alertas, alerta]..sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion)));
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Panel de Alertas Académicas',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          scrolledUnderElevation: 1,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar',
              onPressed: _loading ? null : _cargar,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Alertas (${_alertas.length})'),
              Tab(text: 'Movimientos (${_movimientos.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAlertasBody(colorScheme),
            _buildMovimientosBody(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertasBody(ColorScheme colorScheme) {
    return _loading
          ? const Center(child: CircularProgressIndicator())
          : _alertas.isEmpty
              ? Center(
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
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    itemCount: _alertas.length,
                    itemBuilder: (context, index) {
                      final alerta = _alertas[index];
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
                  ),
                );
  }

  Widget _buildMovimientosBody(ColorScheme colorScheme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_movimientos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history_rounded,
                size: 64.0,
                color: colorScheme.onSurfaceVariant.withAlpha(127),
              ),
              const SizedBox(height: 16.0),
              Text(
                'Sin movimientos registrados todavía',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4.0),
              Text(
                'Acá aparecen las notas, asistencias, incidencias y documentos que carga el personal.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withAlpha(178),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: _movimientos.length,
        itemBuilder: (context, index) {
          final m = _movimientos[index];
          final (categoria, detalle) = _partirAsunto((m['asunto'] ?? '').toString());
          final cuerpo = m['cuerpo'];
          final texto = cuerpo is Map ? (cuerpo['texto'] ?? '').toString() : '';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.0),
              side: BorderSide(color: colorScheme.outlineVariant.withAlpha(100)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer.withAlpha(60),
                child: Icon(Icons.bolt_rounded, color: colorScheme.primary, size: 20),
              ),
              title: Text(detalle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (texto.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text(texto, style: const TextStyle(fontSize: 12)),
                    ),
                  Text(
                    '$categoria · ${_formatearFechaHora(m['fecha_creacion']?.toString())}',
                    style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              isThreeLine: texto.isNotEmpty,
            ),
          );
        },
      ),
    );
  }
}
