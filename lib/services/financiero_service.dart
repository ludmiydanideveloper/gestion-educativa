import 'package:supabase_flutter/supabase_flutter.dart';

class FinancieroService {
  final SupabaseClient _client = Supabase.instance.client;

  // UUID estático de prueba para la "Caja Escolar" (Cuenta interna de la institución)
  static const String cajaEscolarId = 'c0000000-0000-0000-0000-000000000000';

  /// Registra un pago manual de forma atómica aplicando el principio de Partida Doble contable.
  /// Inserta una cabecera de transacción y luego realiza un bulk insert de dos movimientos:
  /// - Un Crédito (monto negativo) en la cuenta corriente de la familia.
  /// - Un Débito (monto positivo) en la cuenta de la Caja Escolar.
  Future<bool> registrarPagoManual({
    required String cuentaId,
    required double montoPago,
    required String observaciones,
  }) async {
    try {
      // 1. Insertar la cabecera del asiento contable
      final transaccionRes = await _client.from('fin_transacciones').insert({
        'tipo_evento': 'PAGO_RECIBIDO',
        'observaciones': observaciones,
        'fecha_ejecucion': DateTime.now().toUtc().toIso8601String(),
      }).select('transaccion_id').single();

      final transaccionId = transaccionRes['transaccion_id'] as String;

      // 2. Realizar el bulk insert de los movimientos contables
      // Al enviarse en una única consulta REST a PostgREST, se ejecutan en una sola transacción,
      // permitiendo que el Constraint Trigger diferido (Partida Doble) valide el balance en el commit.
      await _client.from('fin_movimientos').insert([
        {
          'transaccion_id': transaccionId,
          'cuenta_id': cuentaId,
          'monto': -montoPago, // Crédito: disminuye la deuda del cliente (salida/derecho)
        },
        {
          'transaccion_id': transaccionId,
          'cuenta_id': cajaEscolarId,
          'monto': montoPago, // Débito: ingresa el dinero a la caja de la escuela (entrada/activo)
        }
      ]);

      return true;
    } catch (e) {
      // Si el trigger de partida doble es violado o ocurre otro error, se abortará la transacción.
      print('Error al registrar el pago manual contable: $e');
      return false;
    }
  }

  /// Obtiene el saldo actual consolidado de la cuenta corriente familiar.
  /// Suma dinámicamente los montos de todos sus movimientos históricos.
  Future<double> obtenerSaldoActual(String cuentaId) async {
    try {
      final response = await _client
          .from('fin_movimientos')
          .select('monto')
          .eq('cuenta_id', cuentaId);

      double saldo = 0.0;
      for (final row in response) {
        final montoStr = row['monto']?.toString();
        if (montoStr != null) {
          saldo += double.tryParse(montoStr) ?? 0.0;
        }
      }
      return saldo;
    } catch (e) {
      print('Error al obtener el saldo actual de la cuenta: $e');
      return 0.0;
    }
  }

  /// Obtiene el cuenta_id de la familia del usuario autenticado actual.
  Future<String?> obtenerMiCuentaId() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      
      final response = await _client
          .from('fin_cuentas_corrientes')
          .select('cuenta_id')
          .maybeSingle();
      
      if (response != null) {
        return response['cuenta_id'] as String?;
      }
      return null;
    } catch (e) {
      print('Error al obtener cuenta_id de la familia: $e');
      return null;
    }
  }

  /// Obtiene el historial de movimientos de una cuenta corriente.
  Future<List<Map<String, dynamic>>> obtenerHistorialMovimientos(String cuentaId) async {
    try {
      final response = await _client
          .from('fin_movimientos')
          .select('''
            movimiento_id,
            monto,
            fecha_creacion,
            fin_transacciones (
              tipo_evento,
              observaciones,
              fecha_ejecucion
            )
          ''')
          .eq('cuenta_id', cuentaId)
          .order('fecha_creacion', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener historial de movimientos: $e');
      return [];
    }
  }

  /// Obtiene todas las cuentas corrientes familiares (para el panel administrativo).
  Future<List<Map<String, dynamic>>> obtenerCuentasCorrientes() async {
    try {
      final response = await _client
          .from('fin_cuentas_corrientes')
          .select('''
            cuenta_id,
            documento_fiscal,
            fin_grupos_familiares (
              nombre_grupo
            )
          ''');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener cuentas corrientes: $e');
      return [];
    }
  }
}
