import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double height;
  final bool showText;
  final MainAxisAlignment mainAxisAlignment;

  const BrandLogo({
    super.key,
    this.height = 80.0,
    this.showText = false,
    this.mainAxisAlignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        // Intento de carga de imagen desde assets (logo.png / logo.jpg / logo.jfif)
        Image.asset(
          'assets/images/logo.png',
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/images/logo.jpg',
              height: height,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/images/logo.jfif',
                  height: height,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildFallbackLogo(context);
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFallbackLogo(BuildContext context) {
    // Logo generado con widgets: escudo + ícono + texto
    final double sz = height;
    return SizedBox(
      height: sz,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Escudo / emblema
          Container(
            width: sz * 0.75,
            height: sz,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1565C0), Color(0xFF0D3B6E)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(sz * 0.15),
                topRight: Radius.circular(sz * 0.15),
                bottomLeft: Radius.circular(sz * 0.35),
                bottomRight: Radius.circular(sz * 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withAlpha(80),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_rounded, color: Colors.white, size: sz * 0.38),
                SizedBox(height: sz * 0.04),
                Text(
                  'SGE',
                  style: TextStyle(
                    color: const Color(0xFFFDD835),
                    fontSize: sz * 0.22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          if (showText) ...[
            SizedBox(width: sz * 0.12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SGE',
                  style: TextStyle(
                    fontSize: sz * 0.28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0D3B6E),
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Gestión Educativa',
                  style: TextStyle(
                    fontSize: sz * 0.14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1565C0),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class BrandFrankiaFooter extends StatelessWidget {
  final bool isDark;
  final double scale;

  const BrandFrankiaFooter({
    super.key,
    this.isDark = false,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'by ',
                style: TextStyle(
                  fontSize: 13 * scale,
                  color: subtextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    'frankia',
                    style: TextStyle(
                      fontSize: 20 * scale,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  Positioned(
                    top: 1,
                    right: -5,
                    child: Container(
                      width: 6 * scale,
                      height: 6 * scale,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA3E635), // Verde brillante de Frankia
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA3E635).withAlpha(180),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 3 * scale),
          Text(
            'DESARROLLO DE SOFTWARE & INNOVACIÓN DIGITAL',
            style: TextStyle(
              fontSize: 8.5 * scale,
              fontWeight: FontWeight.w700,
              color: subtextColor,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
