import 'package:flutter/material.dart';
import '../services/financiero_service.dart';

class EstadoCuenta extends StatefulWidget {
  const EstadoCuenta({super.key});

  @override
  State<EstadoCuenta> createState() => _EstadoCuentaState();
}

class _EstadoCuentaState extends State<EstadoCuenta> {
  final _financieroService = FinancieroService();
  
  bool _isLoading = true;
  String? _cuentaId;
  double _saldo = 0.0;
  List<Map<String, dynamic>> _movimientos = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _cargarEstadoCuenta();
  }

  Future<void> _cargarEstadoCuenta() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Obtener la cuenta de la familia logueada
      final cuentaId = await _financieroService.obtenerMiCuentaId();
      if (cuentaId == null) {
        setState(() {
          _errorMessage = 'No se encontró una cuenta corriente vinculada a su usuario.';
          _isLoading = false;
        });
        return;
      }

      // 2. Obtener saldo y movimientos en paralelo
      final resultados = await Future.wait([
        _financieroService.obtenerSaldoActual(cuentaId),
        _financieroService.obtenerHistorialMovimientos(cuentaId),
      ]);

      setState(() {
        _cuentaId = cuentaId;
        _saldo = resultados[0] as double;
        _movimientos = resultados[1] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error al cargar el estado de cuenta: $e');
      setState(() {
        _errorMessage = 'Ocurrió un error al cargar su información financiera: $e';
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    final isNegative = amount < 0;
    final absVal = amount.abs();
    final parts = absVal.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    final buffer = StringBuffer();
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
      count++;
    }
    final reversedInteger = buffer.toString().split('').reversed.join('');
    // Retorna en formato: $ -15,000.00 o $ 15,000.00
    return "\$ ${isNegative ? '-' : ''}$reversedInteger.$decimalPart";
  }

  String _formatDate(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return "$day/$month/$year $hour:$minute hs";
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Estado de Cuenta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _cargarEstadoCuenta,
          ),
        ],
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 64.0),
                        const SizedBox(height: 16.0),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.error, fontSize: 16.0),
                        ),
                        const SizedBox(height: 24.0),
                        ElevatedButton.icon(
                          onPressed: _cargarEstadoCuenta,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarEstadoCuenta,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      // BANNER SUPERIOR DE SALDO
                      _buildBalanceBanner(colorScheme),
                      
                      const SizedBox(height: 32.0),
                      
                      // HISTORIAL DE MOVIMIENTOS
                      Text(
                        'Historial de Cuenta Corriente',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16.0),

                      if (_movimientos.isEmpty)
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            side: BorderSide(
                              color: colorScheme.outlineVariant.withAlpha(127),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 48.0,
                                  color: colorScheme.onSurfaceVariant.withAlpha(127),
                                ),
                                const SizedBox(height: 16.0),
                                const Text(
                                  'Sin movimientos registrados',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4.0),
                                const Text(
                                  'No se registran cargos ni pagos en esta cuenta.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _movimientos.length,
                          itemBuilder: (context, index) {
                            final mov = _movimientos[index];
                            final double monto = double.tryParse(mov['monto'].toString()) ?? 0.0;
                            final fechaCreacion = mov['fecha_creacion'].toString();
                            
                            final trans = mov['fin_transacciones'] as Map<String, dynamic>?;
                            final tipoEvento = trans?['tipo_evento'] ?? 'EVENTO';
                            final observaciones = trans?['observaciones'] ?? '';

                            // En fin_movimientos:
                            // Monto positivo = Débito / Cargo (Rojo, la familia debe pagar esto)
                            // Monto negativo = Crédito / Pago (Verde, la familia pagó o se le aplicó crédito)
                            final esCargo = monto > 0;
                            final colorSemantico = esCargo ? Colors.red.shade700 : Colors.green.shade700;
                            final icon = esCargo ? Icons.arrow_outward_rounded : Icons.call_received_rounded;

                            // Formateo del tipo de evento para legibilidad
                            String displayTipo = tipoEvento;
                            if (tipoEvento == 'EMISION_FACTURA') {
                              displayTipo = 'Cargo / Factura';
                            } else if (tipoEvento == 'PAGO_RECIBIDO') {
                              displayTipo = 'Pago Registrado';
                            } else if (tipoEvento == 'AJUSTE_CREDITO') {
                              displayTipo = 'Ajuste de Crédito';
                            } else if (tipoEvento == 'AJUSTE_DEBITO') {
                              displayTipo = 'Ajuste de Débito';
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: colorSemantico.withAlpha(20),
                                    child: Icon(icon, color: colorSemantico, size: 18.0),
                                  ),
                                  title: Text(
                                    displayTipo,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (observaciones.isNotEmpty) ...[
                                        const SizedBox(height: 4.0),
                                        Text(
                                          observaciones,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                                fontSize: 13.0,
                                              ),
                                        ),
                                      ],
                                      const SizedBox(height: 6.0),
                                      Text(
                                        _formatDate(fechaCreacion),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: colorScheme.onSurfaceVariant.withAlpha(150),
                                              fontSize: 11.0,
                                            ),
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    _formatCurrency(monto),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.0,
                                      color: colorSemantico,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBalanceBanner(ColorScheme colorScheme) {
    final esDeuda = _saldo > 0;
    final esSaldoAFavor = _saldo < 0;

    Color bannerColor;
    Color borderColor;
    Color textColor;
    String statusTitle;
    String description;

    if (esDeuda) {
      bannerColor = const Color(0xFFFEF2F2); // Soft Red
      borderColor = const Color(0xFFFCA5A5);
      textColor = const Color(0xFF991B1B);
      statusTitle = 'Deuda a la fecha';
      description = 'Usted posee un saldo pendiente de pago con la institución.';
    } else if (esSaldoAFavor) {
      bannerColor = const Color(0xFFF0FDF4); // Soft Green
      borderColor = const Color(0xFF86EFAC);
      textColor = const Color(0xFF166534);
      statusTitle = 'Saldo a favor';
      description = 'Usted ha realizado pagos por adelantado o cuenta con un saldo a favor.';
    } else {
      bannerColor = const Color(0xFFF8FAFC); // Neutral Slate Gray
      borderColor = const Color(0xFFE2E8F0);
      textColor = const Color(0xFF0F172A);
      statusTitle = 'Cuenta al día';
      description = 'No registra saldos pendientes en este ciclo lectivo.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            statusTitle.toUpperCase(),
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: textColor.withAlpha(200),
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            _formatCurrency(_saldo),
            style: TextStyle(
              fontSize: 34.0,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16.0),
          Divider(color: borderColor.withAlpha(127)),
          const SizedBox(height: 8.0),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.0,
              color: textColor.withAlpha(220),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
