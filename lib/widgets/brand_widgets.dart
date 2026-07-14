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
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3057).withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0F3057).withAlpha(40), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_rounded, size: height * 0.6, color: const Color(0xFF0F3057)),
          const SizedBox(width: 8),
          Text(
            'SGE',
            style: TextStyle(
              fontSize: height * 0.45,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F3057),
            ),
          ),
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
