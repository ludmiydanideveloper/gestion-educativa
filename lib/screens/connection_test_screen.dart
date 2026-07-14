import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key});

  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  bool _isLoading = true;
  bool _isConnected = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Realizar una consulta de prueba rápida sobre la tabla core_sedes
      // Seleccionamos la columna nombre_sede limitando el resultado a 1 fila
      final response = await Supabase.instance.client
          .from('core_sedes')
          .select('nombre_sede')
          .limit(1);

      debugPrint('Supabase connection test response: $response');
      
      setState(() {
        _isConnected = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Supabase connection test failed: $e');
      setState(() {
        _isConnected = false;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de Conexión Supabase'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isLoading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    key: const ValueKey('loading'),
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24.0),
                      Text(
                        'Probando conexión con la base de datos...',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  )
                : _isConnected
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        key: const ValueKey('success'),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green.shade700,
                              size: 72.0,
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          Text(
                            '¡Conectado exitosamente a Supabase!',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12.0),
                          const Text(
                            'La consulta DDL y la integridad referencial del esquema EdTech están listas para operar.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32.0),
                          ElevatedButton(
                            onPressed: () {
                              // Navegar al Dashboard del Preceptor como siguiente paso
                              // Navigator.of(context).pushReplacement(...);
                            },
                            child: const Text('Ir al Dashboard'),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        key: const ValueKey('error'),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cancel_rounded,
                              color: Colors.red.shade700,
                              size: 72.0,
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          Text(
                            'Error de Conexión',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade800,
                                ),
                          ),
                          const SizedBox(height: 16.0),
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: SelectableText(
                              _errorMessage,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          ElevatedButton.icon(
                            onPressed: _testConnection,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}
