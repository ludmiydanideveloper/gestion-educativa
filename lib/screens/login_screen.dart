import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Icon(icon, color: Colors.white, size: 20.0),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withAlpha(235),
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
                shadows: [
                  Shadow(color: Colors.black.withAlpha(90), blurRadius: 6.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Panel de marca: carrusel de fotos de la escuela con un velo que solo
  // oscurece la parte de abajo (donde va el texto), para que la foto se siga
  // viendo arriba. Solo se usa en pantallas anchas (web de escritorio).
  Widget _buildBrandPanel() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _SchoolCarousel(),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.42, 1.0],
              colors: [
                Colors.transparent,
                const Color(0xFF081C34).withAlpha(70),
                const Color(0xFF081C34).withAlpha(235),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
                    color: Colors.white.withAlpha(225),
                    fontSize: 15.0,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32.0),
                ..._features.map(
                  (f) => _buildFeatureItem(f['icon'] as IconData, f['text'] as String),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Encabezado compacto con el carrusel, usado solo en pantallas angostas (mobile web).
  Widget _buildMobileHeader() {
    return SizedBox(
      height: 240.0,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _SchoolCarousel(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
                colors: [
                  Colors.transparent,
                  const Color(0xFF081C34).withAlpha(60),
                  const Color(0xFF081C34).withAlpha(210),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 18.0),
                child: Text(
                  'SGE Gestión Educativa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    shadows: [
                      Shadow(color: Colors.black.withAlpha(100), blurRadius: 8.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: BrandLogo(height: 84.0),
          ),
          const SizedBox(height: 26.0),
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

  // Arma el contenido de forma que, cuando la pantalla es alta, el pie de
  // Frankia quede pegado abajo del todo; en pantallas bajas, simplemente
  // se puede hacer scroll y queda después del formulario.
  Widget _buildPinnedFooterArea({
    required EdgeInsets padding,
    double maxContentWidth = double.infinity,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double minHeight = (constraints.maxHeight - padding.vertical).clamp(0.0, double.infinity);
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: _buildAnimatedForm(),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 16.0),
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: const BrandFrankiaFooter(isDark: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(flex: 6, child: _buildBrandPanel()),
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: _buildPinnedFooterArea(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
              maxContentWidth: 400.0,
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
              child: _buildPinnedFooterArea(
                padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 16.0),
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

/// Carrusel de fotos de la escuela para el panel de marca del login.
///
/// Busca archivos `carrusel_1.jpg` … `carrusel_6.jpg` (o .jpeg/.png/.webp) en
/// `assets/images/carrusel/`. Si no se subió ninguna foto todavía, muestra un
/// degradé institucional de respaldo en vez de romper la pantalla.
class _SchoolCarousel extends StatefulWidget {
  const _SchoolCarousel();

  @override
  State<_SchoolCarousel> createState() => _SchoolCarouselState();
}

class _SchoolCarouselState extends State<_SchoolCarousel> {
  static const int _maxSlides = 6;
  static const List<String> _extensions = ['jpg', 'jpeg', 'png', 'webp'];

  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;
  List<String> _images = const [];
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolveAvailableImages();
  }

  Future<void> _resolveAvailableImages() async {
    final List<String> found = [];
    for (int i = 1; i <= _maxSlides; i++) {
      for (final ext in _extensions) {
        final path = 'assets/images/carrusel/carrusel_$i.$ext';
        try {
          await rootBundle.load(path);
          found.add(path);
          break;
        } catch (_) {
          // Ese archivo no fue provisto: se ignora en silencio.
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _images = found;
      _resolved = true;
    });

    if (found.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted || !_pageController.hasClients) return;
        final next = (_currentPage + 1) % _images.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _fallback() {
    return const DecoratedBox(
      decoration: BoxDecoration(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved || _images.isEmpty) {
      return _fallback();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: _images.length,
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemBuilder: (context, index) {
            return Image.asset(_images[index], fit: BoxFit.cover);
          },
        ),
        if (_images.length > 1)
          Positioned(
            bottom: 18.0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_images.length, (i) {
                final bool active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  width: active ? 18.0 : 6.0,
                  height: 6.0,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(active ? 255 : 130),
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
