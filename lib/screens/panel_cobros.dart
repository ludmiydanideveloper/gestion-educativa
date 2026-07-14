import 'package:flutter/material.dart';
import '../services/financiero_service.dart';

class PanelCobros extends StatefulWidget {
  const PanelCobros({super.key});

  @override
  State<PanelCobros> createState() => _PanelCobrosState();
}

class _PanelCobrosState extends State<PanelCobros> {
  final _formKey = GlobalKey<FormState>();
  final _financieroService = FinancieroService();
  
  final _cuentaIdController = TextEditingController();
  final _montoController = TextEditingController();
  final _observacionesController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingCuentas = true;
  List<Map<String, dynamic>> _cuentas = [];
  String? _cuentaSeleccionada;

  // ID de prueba por defecto
  static const String cuentaPruebaId = '7d50d7af-3658-4209-aee5-4e146ed97d81';

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
  }

  @override
  void dispose() {
    _cuentaIdController.dispose();
    _montoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _cargarCuentas() async {
    setState(() {
      _isLoadingCuentas = true;
    });
    try {
      final cuentas = await _financieroService.obtenerCuentasCorrientes();
      setState(() {
        _cuentas = cuentas;
        // Si la cuenta de prueba está en la lista, la seleccionamos por defecto.
        final tienePrueba = cuentas.any((c) => c['cuenta_id'] == cuentaPruebaId);
        if (tienePrueba) {
          _cuentaSeleccionada = cuentaPruebaId;
          _cuentaIdController.text = cuentaPruebaId;
        } else if (cuentas.isNotEmpty) {
          _cuentaSeleccionada = cuentas.first['cuenta_id'] as String?;
          _cuentaIdController.text = _cuentaSeleccionada ?? '';
        } else {
          _cuentaSeleccionada = 'manual';
        }
      });
    } catch (e) {
      debugPrint('Error al cargar cuentas corrientes: $e');
      setState(() {
        _cuentaSeleccionada = 'manual';
      });
    } finally {
      setState(() {
        _isLoadingCuentas = false;
      });
    }
  }

  Future<void> _registrarCobro() async {
    if (!_formKey.currentState!.validate()) return;

    final cuentaId = _cuentaIdController.text.trim();
    final monto = double.tryParse(_montoController.text.trim());
    final observaciones = _observacionesController.text.trim();

    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor, ingrese un monto válido mayor a 0.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final exito = await _financieroService.registrarPagoManual(
        cuentaId: cuentaId,
        montoPago: monto,
        observaciones: observaciones,
      );

      if (!mounted) return;

      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    'Cobro registrado con éxito en el Ledger Contable.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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
        // Limpiar formulario
        _montoController.clear();
        _observacionesController.clear();
        if (_cuentaSeleccionada == 'manual') {
          _cuentaIdController.clear();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error contable: El balance del asiento no cerró en cero.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar el pago: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Panel de Cobros',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar Cuentas',
            onPressed: _cargarCuentas,
          ),
        ],
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: _isLoadingCuentas
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner explicativo M3
                    Card(
                      elevation: 0,
                      color: colorScheme.primaryContainer.withAlpha(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                        side: BorderSide(
                          color: colorScheme.primary.withAlpha(51),
                          width: 1.0,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.payment_rounded, color: colorScheme.primary, size: 36.0),
                            const SizedBox(width: 16.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Punto de Venta / Cobros en Caja',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    'Registra el cobro manual a cuentas de familias. Esto genera de forma atómica un Crédito en la cuenta corriente familiar y un Débito en la Caja Escolar.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Selector de cuenta o campo manual
                    Text(
                      'Cuenta de la Familia',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 8.0),
                    DropdownButtonFormField<String>(
                      value: _cuentaSeleccionada,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.people_alt_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      ),
                      isExpanded: true,
                      items: [
                        ..._cuentas.map((c) {
                          final grupo = c['fin_grupos_familiares'] as Map<String, dynamic>?;
                          final nombreGrupo = grupo?['nombre_grupo'] ?? 'Sin Nombre';
                          final dni = c['documento_fiscal'] ?? '';
                          final id = c['cuenta_id'] as String;
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              '$nombreGrupo (DNI: $dni)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                        const DropdownMenuItem<String>(
                          value: 'manual',
                          child: Text('Ingresar UUID manualmente...'),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _cuentaSeleccionada = val;
                          if (val != null && val != 'manual') {
                            _cuentaIdController.text = val;
                          } else {
                            _cuentaIdController.clear();
                          }
                        });
                      },
                    ),
                    
                    if (_cuentaSeleccionada == 'manual') ...[
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _cuentaIdController,
                        decoration: InputDecoration(
                          labelText: 'UUID de la Cuenta',
                          hintText: 'Ej: 7d50d7af-3658-4209-aee5-4e146ed97d81',
                          prefixIcon: const Icon(Icons.vpn_key_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingrese el UUID de la cuenta';
                          }
                          // Validación básica de formato UUID
                          final regExp = RegExp(
                            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                          );
                          if (!regExp.hasMatch(value.trim())) {
                            return 'Formato de UUID inválido';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 24.0),

                    // Campo Monto
                    Text(
                      'Monto a Cobrar',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _montoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Monto (\$)',
                        hintText: 'Ej: 50000',
                        prefixIcon: const Icon(Icons.attach_money_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingrese el monto';
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null) {
                          return 'Ingrese un número válido';
                        }
                        if (parsed <= 0) {
                          return 'El monto debe ser mayor a 0';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24.0),

                    // Campo Observaciones
                    Text(
                      'Observaciones Internas',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _observacionesController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Detalles del cobro',
                        hintText: 'Ej: Pago en efectivo ventanilla',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 56.0),
                          child: Icon(Icons.comment_rounded),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingrese una observación';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32.0),

                    // Botón de Acción
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _registrarCobro,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20.0,
                              height: 20.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isLoading ? 'Registrando Transacción...' : 'Registrar Cobro',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
