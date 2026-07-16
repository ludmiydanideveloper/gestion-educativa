import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta de Colores Oficial (Saturada y armonizada con el Logo SGEducativa - Niño leyendo)
  static const Color primaryColor = Color(0xFF0F3057); // Azul marino profundo del logo
  static const Color secondaryColor = Color(0xFF1E3A8A); // Azul institucional complementario
  static const Color scaffoldBackground = Color(0xFFF8FAFC); // Gris neutro extra claro
  static const Color surfaceColor = Colors.white;
  static const Color borderSubtle = Color(0xFFE2E8F0); // Borde sutil gris claro
  static const Color textMain = Color(0xFF0F172A); // Texto principal oscuro
  static const Color textMuted = Color(0xFF64748B); // Texto secundario mutado

  static ThemeData get lightTheme {
    const Color primaryContainer = Color(0xFFDCE8F5);
    const Color onPrimaryContainer = Color(0xFF081C34);
    const Color secondaryContainer = Color(0xFFDBEAFE);
    const Color onSecondaryContainer = Color(0xFF1E3A8A);

    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        surface: surfaceColor,
        onSurface: textMain,
        outline: borderSubtle,
        outlineVariant: borderSubtle,
      ),
      // Tipografía principal
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.light().textTheme.copyWith(
              bodyLarge: const TextStyle(color: textMain),
              bodyMedium: const TextStyle(color: textMain),
              titleLarge: const TextStyle(color: textMain, fontWeight: FontWeight.bold),
              titleMedium: const TextStyle(color: textMain, fontWeight: FontWeight.w600),
            ),
      ),
      // Tema de App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMain),
        actionsIconTheme: IconThemeData(color: textMain),
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Tema de Tarjetas
      cardTheme: const CardThemeData(
        color: surfaceColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12.0)),
          side: BorderSide(
            color: borderSubtle,
            width: 1.0,
          ),
        ),
      ),
      // Tema de los Campos de Entrada de Texto
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
      ),
      // Tema de los Botones Elevados (ElevatedButton)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 22.0),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
      // Tema de Botones Delineados (OutlinedButton)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 22.0),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
      // Tema de Botones de Texto (TextButton)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
      // Tema de SegmentedButton (Vistas / Pestañas en paneles)
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF334155); // Pizarra formal formal / oscuro legible
            }
            return Colors.white;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white; // Siempre blanco puro al estar seleccionado
            }
            return const Color(0xFF475569); // Gris pizarra en no seleccionado
          }),
          iconColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return const Color(0xFF64748B);
          }),
          textStyle: WidgetStateProperty.all<TextStyle>(
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
          side: WidgetStateProperty.all<BorderSide>(
            const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
          ),
        ),
      ),
      // Tema de Chips (Filtros en paneles)
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF334155),
        secondarySelectedColor: const Color(0xFF334155),
        disabledColor: const Color(0xFFF1F5F9),
        labelStyle: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w500, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        brightness: Brightness.light,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        checkmarkColor: Colors.white,
      ),
      // Tema de los Divider
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1.0,
        space: 16.0,
      ),
      // Tema de Drawer
      drawerTheme: const DrawerThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
      ),
    );
  }
}
