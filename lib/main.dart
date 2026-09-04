import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/asistencia_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_preceptor.dart';
import 'screens/portal_familia.dart';
import 'theme/app_theme.dart';

/// URL y clave del proyecto Supabase.
///
/// Se pasan al compilar para no versionar credenciales:
///
///   flutter build web \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=<clave anon public>
///
/// La clave DEBE ser la "anon public" (Supabase > Settings > API), NUNCA la
/// "service_role": esa saltea por completo las políticas RLS y quedaría
/// publicada en el navegador de cada usuario.
///
/// Hasta ahora la clave estaba escrita acá y era de service_role, así que
/// cualquiera que abriera la app tenía acceso total a la base.
const String _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://qiwwmlysqidwnywmrwko.supabase.co',
);

const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() async {
  // Garantizar inicialización correcta de bindings de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseAnonKey.isEmpty) {
    runApp(const _FaltaConfiguracionApp());
    return;
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => AsistenciaProvider(),
      child: const MyApp(),
    ),
  );
}

/// Pantalla que se muestra cuando falta la clave de Supabase, en lugar de
/// arrancar contra una credencial escrita en el código.
class _FaltaConfiguracionApp extends StatelessWidget {
  const _FaltaConfiguracionApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.key_off_rounded, size: 56, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Falta configurar la clave de Supabase',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Compilá la app pasando la clave "anon public" del proyecto '
                    '(Supabase > Settings > API):',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const SelectableText(
                      'flutter build web \\\n'
                      '  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n'
                      '  --dart-define=SUPABASE_ANON_KEY=<clave anon public>',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No uses la clave service_role: ignora las políticas RLS y '
                    'le da acceso completo a la base a cualquiera que abra la app.',
                    style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SGE gestion educativa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'),
        Locale('es', ''),
      ],
      locale: const Locale('es', 'AR'),
      // AuthGate maneja la redirección automática basada en el estado de la sesión
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  bool _isLoading = true;
  Session? _session;

  @override
  void initState() {
    super.initState();

    // 1. Verificar la sesión actual de forma síncrona/inmediata al iniciar
    _session = Supabase.instance.client.auth.currentSession;
    _isLoading = false;

    // 2. Escuchar en tiempo real los cambios del estado de autenticación (onAuthStateChange)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _session = data.session;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Redirección reactiva según sesión y rol del usuario
    if (_session != null) {
      final user = _session!.user;
      final rol = user.userMetadata?['rol'] as String?;

      if (rol == 'ALUMNO' || rol == 'PADRE') {
        return const PortalFamilia();
      } else {
        // Preceptores, docentes y directivos van al Dashboard
        return const DashboardPreceptor();
      }
    } else {
      return const LoginScreen();
    }
  }
}
