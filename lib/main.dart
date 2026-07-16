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

void main() async {
  // Garantizar inicialización correcta de bindings de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase con tus credenciales configuradas
  await Supabase.initialize(
    url: 'https://qiwwmlysqidwnywmrwko.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpd3dtbHlzcWlkd255d21yd2tvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTI5NTc3NiwiZXhwIjoyMDk2ODcxNzc2fQ.q2yxNRrJF-Bgcn2uZ_Eiu8fXqTqsYyZVCL7mA3509w8',
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => AsistenciaProvider(),
      child: const MyApp(),
    ),
  );
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
