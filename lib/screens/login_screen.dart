import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
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

  static const List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.groups_rounded,
      'text': 'Gestión integral de la comunidad educativa',
    },
    {
      'icon': Icons.fact_check_rounded,
      'text': 'Asistencia, calendario y seguimiento pedagógico',
    },
    {
      'icon': Icons.insights_rounded,
      'text': 'Reportes y rendimiento en tiempo real',
    },
  ];

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

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1.4]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 21.0),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
      border: border(const Color(0xFFE2E8F0)),
      enabledBorder: border(const Color(0xFFE2E8F0)),
      focusedBorder: border(AppTheme.primaryColor, 1.8),
      errorBorder: border(Colors.redAccent),
      focusedErrorBorder: border(Colors.redAccent, 1.8),
    );
  }

  Widget _buildBrandLogo({double size = 76.0}) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 18.0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: BrandLogo(height: size),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Icon(icon, color: Colors.white, size: 20.0),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withAlpha(230),
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Panel izquierdo con degradé institucional, marca y propuesta de valor.
  // Solo se muestra en pantallas anchas (web de escritorio).
  Widget _buildBrandPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.secondaryColor,
            AppTheme.primaryColor,
            Color(0xFF081C34),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70.0,
            left: -60.0,
            child: _softCircle(220.0),
          ),
          Positioned(
            bottom: -90.0,
            right: -70.0,
            child: _softCircle(260.0),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBrandLogo(),
                  const SizedBox(height: 28.0),
                  const Text(
                    'SGE Gestión Educativa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    'Plataforma integral para la gestión académica, '
                    'administrativa y pedagógica de tu institución.',
                    style: TextStyle(
                      color: Colors.white.withAlpha(220),
                      fontSize: 15.0,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 40.0),
                  ..._features.map(
                    (f) => _buildFeatureItem(f['icon'] as IconData, f['text'] as String),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withAlpha(28),
            Colors.white.withAlpha(0),
          ],
        ),
      ),
    );
  }

  // Encabezado compacto con degradé, usado solo en pantallas angostas (mobile web).
  Widget _buildMobileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24.0, 36.0, 24.0, 56.0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.secondaryColor,
            AppTheme.primaryColor,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildBrandLogo(size: 60.0),
            const SizedBox(height: 16.0),
            const Text(
              'SGE Gestión Educativa',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bienvenido/a',
            style: TextStyle(
              fontSize: 26.0,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8.0),
          const Text(
            'Ingresá con tu cuenta institucional para continuar.',
            style: TextStyle(
              fontSize: 14.0,
              height: 1.4,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 32.0),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
              color: AppTheme.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 15.0,
            ),
            decoration: _fieldDecoration(
              label: 'Correo electrónico',
              icon: Icons.mail_outline_rounded,
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
          const SizedBox(height: 18.0),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(
              color: AppTheme.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 15.0,
            ),
            decoration: _fieldDecoration(
              label: 'Contraseña',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.textMuted,
                  size: 20.0,
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
          const SizedBox(height: 30.0),
          SizedBox(
            height: 54.0,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.primaryColor.withAlpha(150),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
                elevation: 0,
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
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continuar',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16.0,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 8.0),
                        Icon(Icons.arrow_forward_rounded, size: 20.0),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8.0),
        ],
      ),
    );
  }

  Widget _buildAnimatedForm() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16.0),
            child: child,
          ),
        );
      },
      child: _buildFormContent(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(flex: 5, child: _buildBrandPanel()),
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAnimatedForm(),
                      const SizedBox(height: 24.0),
                      const BrandFrankiaFooter(isDark: false),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _buildMobileHeader(),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -28.0),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28.0),
                  topRight: Radius.circular(28.0),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAnimatedForm(),
                    const SizedBox(height: 16.0),
                    const BrandFrankiaFooter(isDark: false),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 900.0;
          return isWide ? _buildWideLayout() : _buildNarrowLayout();
        },
      ),
    );
  }
}
