import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/brand_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabaseService = SupabaseService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _supabaseService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // Tras el login exitoso, main.dart detectará el cambio de sesión y redirigirá al dashboard.
    } on AuthException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error inesperado de autenticación: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        margin: const EdgeInsets.all(16.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1565C0), // azul escolar
              Color(0xFF0D3B6E), // azul marino
              Color(0xFF01579B), // azul medio
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo en la parte superior del fondo oscuro (estilo Disney+)
                    const BrandLogo(height: 85.0),
                    const SizedBox(height: 10.0),
                    const Text(
                      'SGE Gestión Educativa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28.0),

                    // Tarjeta con borde redondeado, sombra suave
                    Card(
                      elevation: 12.0,
                      shadowColor: Colors.black.withAlpha(80),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                  fontSize: 22.0,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0D3B6E),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                'Ingresá con tu cuenta institucional.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.4,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 28.0),

                              // Campo Email (contenedor relleno gris claro con esquinas redondeadas)
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15.0,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Correo electrónico',
                                  hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: const BorderSide(color: Colors.red, width: 1.0),
                                  ),
                                ),
                                enabled: !_isLoading,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Por favor ingresa tu correo';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                    return 'Ingresa un correo electrónico válido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16.0),

                              // Campo Contraseña
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15.0,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Contraseña',
                                  hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: const BorderSide(color: Colors.red, width: 1.0),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                enabled: !_isLoading,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor ingresa tu contraseña';
                                  }
                                  if (value.length < 6) {
                                    return 'La contraseña debe tener al menos 6 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28.0),

                              // Botón principal azul institucional
                              ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1565C0),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.0),
                                  ),
                                  elevation: 2,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22.0,
                                        width: 22.0,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Continuar',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16.0,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28.0),
                    const BrandFrankiaFooter(isDark: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
