import 'dart:ui' show Color;

/// Datos reales de horarios IABAR 2026 extraídos de la grilla oficial.

class HorarioBloque {
  final String hora;
  final String materia;
  final String? profesor;

  const HorarioBloque(this.hora, this.materia, [this.profesor]);
}

class HorarioDia {
  final String dia;
  final List<HorarioBloque> bloques;

  const HorarioDia(this.dia, this.bloques);
}

class HorarioCurso {
  final String curso;
  final String totalModulos;
  final String horaEntrada;
  final String horaSalida; // Salida más tardía del curso
  final List<HorarioDia> dias;

  const HorarioCurso({
    required this.curso,
    required this.totalModulos,
    required this.horaEntrada,
    required this.horaSalida,
    required this.dias,
  });
}

class HorariosData {
  static const List<HorarioCurso> cursos = [
    // ─── 1° SEC (24 módulos) ───────────────────────────────────────────────
    HorarioCurso(
      curso: '1° SEC',
      totalModulos: '24 módulos',
      horaEntrada: '7:00',
      horaSalida: '14:10',
      dias: [
        HorarioDia('Lunes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada', 'Daniel Gomez'),
          HorarioBloque('7:40 - 8:40', 'P. del Lenguaje', 'Jenica Romero'),
          HorarioBloque('8:45 - 9:45', 'P. del Lenguaje', 'Jenica Romero'),
          HorarioBloque('9:55 - 10:55', 'Cs. Naturales', 'Danilo Gomez'),
          HorarioBloque('11:00 - 12:00', 'Cs. Naturales', 'Danilo Gomez'),
          HorarioBloque('12:10 - 13:10', 'Ed. Física', 'Julio Lesson'),
          HorarioBloque('13:10 - 14:10', 'TIC', 'A asignar'),
        ]),
        HorarioDia('Martes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada', 'Daniel Gomez'),
          HorarioBloque('7:40 - 8:40', 'Construcción de la Ciudadanía', 'Maria Funes'),
          HorarioBloque('8:45 - 9:45', 'Construcción de la Ciudadanía', 'Maria Funes'),
          HorarioBloque('9:55 - 10:55', 'Cs. Sociales', 'A asignar'),
          HorarioBloque('11:00 - 12:00', 'Ed. Artística Música', 'A asignar'),
          HorarioBloque('12:40 - 13:40', 'Ed. Artística Música', 'A asignar'),
          HorarioBloque('13:40 - 14:10', 'Ed. Física', 'Julio Lesson'),
        ]),
        HorarioDia('Miércoles', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada', 'Daniel Gomez'),
          HorarioBloque('7:40 - 8:40', 'P. del Lenguaje', 'Jenica Romero'),
          HorarioBloque('8:45 - 9:45', 'Matemática', 'Florencia Viero'),
          HorarioBloque('9:55 - 10:55', 'Cs. Sociales', 'A asignar'),
          HorarioBloque('11:00 - 12:00', 'Inglés', 'A asignar'),
          HorarioBloque('12:40 - 13:40', 'Ed. Artística Música', 'A asignar'),
          HorarioBloque('13:40 - 14:10', 'Ed. Física', 'Julio Lesson'),
        ]),
        HorarioDia('Jueves', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada', 'Daniel Gomez'),
          HorarioBloque('7:40 - 8:40', 'Cs. Naturales', 'Danilo Gomez'),
          HorarioBloque('8:45 - 9:45', 'Cs. Naturales', 'Danilo Gomez'),
          HorarioBloque('9:55 - 10:55', 'P. del Lenguaje', 'Jenica Romero'),
          HorarioBloque('11:00 - 12:00', 'Cs. Sociales', 'A asignar'),
          HorarioBloque('12:40 - 13:40', 'Matemática', 'Florencia Viero'),
        ]),
        HorarioDia('Viernes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada', 'Daniel Gomez'),
          HorarioBloque('7:40 - 8:40', 'Cs. Sociales', 'A asignar'),
          HorarioBloque('8:45 - 9:45', 'Cs. Sociales', 'A asignar'),
          HorarioBloque('9:55 - 10:55', 'P. del Lenguaje', 'Jenica Romero'),
          HorarioBloque('11:00 - 12:00', 'Matemática', 'Florencia Viero'),
          HorarioBloque('12:40 - 13:40', 'Matemática', 'Florencia Viero'),
        ]),
      ],
    ),

    // ─── 2° SEC (24 módulos) ───────────────────────────────────────────────
    HorarioCurso(
      curso: '2° SEC',
      totalModulos: '24 módulos',
      horaEntrada: '7:00',
      horaSalida: '13:10',
      dias: [
        HorarioDia('Lunes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Inglés'),
          HorarioBloque('8:45 - 9:45', 'Inglés'),
          HorarioBloque('9:55 - 10:55', 'Matemática'),
          HorarioBloque('11:00 - 12:00', 'Geografía'),
          HorarioBloque('12:10 - 13:10', 'Biología 3ero'),
        ]),
        HorarioDia('Martes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Historia'),
          HorarioBloque('8:45 - 9:45', 'Historia'),
          HorarioBloque('9:55 - 10:55', 'Ed. Artística Música'),
          HorarioBloque('11:00 - 12:00', 'Ed. Artística Música'),
          HorarioBloque('12:10 - 13:10', 'Biología 3ero'),
        ]),
        HorarioDia('Miércoles', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Matemática'),
          HorarioBloque('8:45 - 9:45', 'P. del Lenguaje'),
          HorarioBloque('9:55 - 10:55', 'P. del Lenguaje'),
          HorarioBloque('11:00 - 12:00', 'Geografía'),
          HorarioBloque('12:10 - 13:10', 'Ed. Física'),
        ]),
        HorarioDia('Jueves', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'P. del Lenguaje'),
          HorarioBloque('8:45 - 9:45', 'P. del Lenguaje'),
          HorarioBloque('9:55 - 10:55', 'Matemática'),
          HorarioBloque('11:00 - 12:00', 'Geografía'),
          HorarioBloque('13:10 - 14:10', 'TIC'),
        ]),
        HorarioDia('Viernes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'P. del Lenguaje'),
          HorarioBloque('8:45 - 9:45', 'Físico-Química'),
          HorarioBloque('9:55 - 10:55', 'Físico-Química'),
          HorarioBloque('11:00 - 12:00', 'Físico-Química'),
        ]),
      ],
    ),

    // ─── 3° SEC (24 módulos) ───────────────────────────────────────────────
    HorarioCurso(
      curso: '3° SEC',
      totalModulos: '24 módulos',
      horaEntrada: '7:00',
      horaSalida: '13:10',
      dias: [
        HorarioDia('Lunes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'P. del Lenguaje'),
          HorarioBloque('8:45 - 9:45', 'P. del Lenguaje'),
          HorarioBloque('9:55 - 10:55', 'Geografía'),
          HorarioBloque('11:00 - 12:00', 'Historia'),
          HorarioBloque('12:10 - 13:10', 'Ed. Física'),
        ]),
        HorarioDia('Martes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'P. del Lenguaje'),
          HorarioBloque('8:45 - 9:45', 'P. del Lenguaje'),
          HorarioBloque('9:55 - 10:55', 'Geografía'),
          HorarioBloque('11:00 - 12:00', 'Matemática'),
          HorarioBloque('12:10 - 13:10', 'Ed. Física'),
        ]),
        HorarioDia('Miércoles', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'H. Sagrada'),
          HorarioBloque('8:45 - 9:45', 'Ed. Artística'),
          HorarioBloque('9:55 - 10:55', 'Ed. Artística'),
          HorarioBloque('11:00 - 12:00', 'Historia'),
          HorarioBloque('12:10 - 13:10', 'Ed. Física'),
        ]),
        HorarioDia('Jueves', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Biología'),
          HorarioBloque('8:45 - 9:45', 'Inglés'),
          HorarioBloque('9:55 - 10:55', 'Matemática'),
          HorarioBloque('11:00 - 12:00', 'Matemática'),
          HorarioBloque('12:10 - 13:10', 'Matemática'),
        ]),
        HorarioDia('Viernes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Inglés'),
          HorarioBloque('8:45 - 9:45', 'Físico-Química'),
          HorarioBloque('9:55 - 10:55', 'Construcción de la Ciudadanía'),
          HorarioBloque('11:00 - 12:00', 'Construcción de la Ciudadanía'),
          HorarioBloque('13:10 - 14:10', 'TIC'),
        ]),
      ],
    ),

    // ─── 4° SEC (26 módulos) ───────────────────────────────────────────────
    HorarioCurso(
      curso: '4° SEC',
      totalModulos: '26 módulos',
      horaEntrada: '7:00',
      horaSalida: '14:10',
      dias: [
        HorarioDia('Lunes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'SyA'),
          HorarioBloque('8:45 - 9:45', 'SyA'),
          HorarioBloque('9:55 - 10:55', 'Literatura'),
          HorarioBloque('11:00 - 12:00', 'Literatura'),
          HorarioBloque('12:10 - 13:10', 'Geografía'),
          HorarioBloque('13:10 - 14:10', 'Geografía'),
        ]),
        HorarioDia('Martes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'TEO'),
          HorarioBloque('8:45 - 9:45', 'TEO'),
          HorarioBloque('9:55 - 10:55', 'Inglés'),
          HorarioBloque('11:00 - 12:00', 'Inglés'),
          HorarioBloque('12:10 - 13:10', 'Geografía'),
          HorarioBloque('13:10 - 14:10', 'NTICX'),
        ]),
        HorarioDia('Miércoles', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'SIC'),
          HorarioBloque('8:45 - 9:45', 'SIC'),
          HorarioBloque('9:55 - 10:55', 'Matemática'),
          HorarioBloque('11:00 - 12:00', 'Literatura'),
          HorarioBloque('12:10 - 13:10', 'NTICX'),
        ]),
        HorarioDia('Jueves', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Int. a la Física'),
          HorarioBloque('8:45 - 9:45', 'Int. a la Física'),
          HorarioBloque('9:55 - 10:55', 'Biología'),
          HorarioBloque('11:00 - 12:00', 'Literatura'),
          HorarioBloque('12:10 - 13:10', 'Historia'),
        ]),
        HorarioDia('Viernes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Matemática'),
          HorarioBloque('8:45 - 9:45', 'Matemática'),
          HorarioBloque('9:55 - 10:55', 'Historia'),
          HorarioBloque('11:00 - 12:00', 'Historia'),
          HorarioBloque('13:10 - 14:10', 'Ed. Física'),
        ]),
      ],
    ),

    // ─── 5° SEC (27 módulos) ───────────────────────────────────────────────
    HorarioCurso(
      curso: '5° SEC',
      totalModulos: '27 módulos',
      horaEntrada: '7:00',
      horaSalida: '14:10',
      dias: [
        HorarioDia('Lunes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Int. a la Química'),
          HorarioBloque('8:45 - 9:45', 'Int. a la Química'),
          HorarioBloque('9:55 - 10:55', 'Elementos de Admin.'),
          HorarioBloque('11:00 - 12:00', 'Elementos de Admin.'),
          HorarioBloque('12:10 - 13:10', 'Literatura'),
          HorarioBloque('13:10 - 14:10', 'Literatura'),
        ]),
        HorarioDia('Martes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'H. Sagrada'),
          HorarioBloque('8:45 - 9:45', 'Geografía'),
          HorarioBloque('9:55 - 10:55', 'SIC'),
          HorarioBloque('11:00 - 12:00', 'SIC'),
          HorarioBloque('12:10 - 13:10', 'Inglés'),
          HorarioBloque('13:10 - 14:10', 'Ed. Física'),
        ]),
        HorarioDia('Miércoles', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'H. Sagrada'),
          HorarioBloque('8:45 - 9:45', 'Gestión Org.'),
          HorarioBloque('9:55 - 10:55', 'SIC'),
          HorarioBloque('11:00 - 12:00', 'SIC'),
          HorarioBloque('12:10 - 13:10', 'Inglés'),
        ]),
        HorarioDia('Jueves', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'H. Sagrada'),
          HorarioBloque('8:45 - 9:45', 'Historia'),
          HorarioBloque('9:55 - 10:55', 'Derecho'),
          HorarioBloque('11:00 - 12:00', 'Derecho'),
          HorarioBloque('12:10 - 13:10', 'Matemática'),
        ]),
        HorarioDia('Viernes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Política y Ciudadanía'),
          HorarioBloque('8:45 - 9:45', 'Política y Ciudadanía'),
          HorarioBloque('9:55 - 10:55', 'Matemática'),
          HorarioBloque('11:00 - 12:00', 'Matemática'),
          HorarioBloque('13:10 - 14:10', 'Ed. Física'),
        ]),
      ],
    ),

    // ─── 6° SEC (24 módulos) ───────────────────────────────────────────────
    HorarioCurso(
      curso: '6° SEC',
      totalModulos: '24 módulos',
      horaEntrada: '7:00',
      horaSalida: '14:10',
      dias: [
        HorarioDia('Lunes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Literatura'),
          HorarioBloque('8:45 - 9:45', 'Literatura'),
          HorarioBloque('9:55 - 10:55', 'Proy. Org.'),
          HorarioBloque('11:00 - 12:00', 'Economía Pol.'),
          HorarioBloque('12:10 - 13:10', 'Economía Pol.'),
          HorarioBloque('13:10 - 14:10', 'Ed. Física'),
        ]),
        HorarioDia('Martes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Inglés'),
          HorarioBloque('8:45 - 9:45', 'Inglés'),
          HorarioBloque('9:55 - 10:55', 'Filosofía'),
          HorarioBloque('11:00 - 12:00', 'Proy. Org.'),
        ]),
        HorarioDia('Miércoles', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Arte'),
          HorarioBloque('8:45 - 9:45', 'Arte'),
          HorarioBloque('9:55 - 10:55', 'Filosofía'),
          HorarioBloque('11:00 - 12:00', 'Proy. Org.'),
        ]),
        HorarioDia('Jueves', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Matemática'),
          HorarioBloque('8:45 - 9:45', 'Matemática'),
          HorarioBloque('9:55 - 10:55', 'Matemática'),
          HorarioBloque('11:00 - 12:00', 'Economía Pol.'),
          HorarioBloque('12:10 - 13:10', 'Literatura 4to ES'),
        ]),
        HorarioDia('Viernes', [
          HorarioBloque('7:00 - 7:40', 'H. Sagrada'),
          HorarioBloque('7:40 - 8:40', 'Matemática'),
          HorarioBloque('8:45 - 9:45', 'Matemática'),
          HorarioBloque('9:55 - 10:55', 'Trabajo y Ciudadanía'),
          HorarioBloque('11:00 - 12:00', 'Trabajo y Ciudadanía'),
          HorarioBloque('12:10 - 13:10', 'Economía Pol.'),
          HorarioBloque('13:10 - 14:10', 'Ed. Física'),
        ]),
      ],
    ),
  ];

  /// Devuelve el horario del curso que coincida con el nombre dado.
  /// Busca de forma flexible: "1° SEC", "1 SEC", "1°SEC", etc.
  static HorarioCurso? buscarPorNombre(String nombre) {
    final n = nombre.toUpperCase().replaceAll(' ', '').replaceAll('°', '');
    for (final c in cursos) {
      final cn = c.curso.toUpperCase().replaceAll(' ', '').replaceAll('°', '');
      if (cn == n || n.contains(cn) || cn.contains(n)) return c;
    }
    return null;
  }

  /// Colores de materias para el display visual
  static Color colorMateria(String materia) {
    final m = materia.toLowerCase();
    if (m.contains('matemá') || m.contains('matema')) return const Color(0xFF2563EB);
    if (m.contains('lengua') || m.contains('lenguaje') || m.contains('literatura')) return const Color(0xFF7C3AED);
    if (m.contains('inglés') || m.contains('ingles')) return const Color(0xFF059669);
    if (m.contains('historia')) return const Color(0xFFB45309);
    if (m.contains('geografía') || m.contains('geografia')) return const Color(0xFF0891B2);
    if (m.contains('física') || m.contains('fisica') || m.contains('físico') || m.contains('fisico')) return const Color(0xFFDC2626);
    if (m.contains('química') || m.contains('quimica') || m.contains('biolog')) return const Color(0xFF16A34A);
    if (m.contains('ed. física') || m.contains('ed. fisica')) return const Color(0xFFF97316);
    if (m.contains('sagrada') || m.contains('religion') || m.contains('religión')) return const Color(0xFF7C3AED);
    if (m.contains('artíst') || m.contains('artis') || m.contains('arte')) return const Color(0xFFEC4899);
    if (m.contains('tic') || m.contains('ntic') || m.contains('sic') || m.contains('tec')) return const Color(0xFF6366F1);
    if (m.contains('ciudadan')) return const Color(0xFF0D9488);
    if (m.contains('economía') || m.contains('economia')) return const Color(0xFF84CC16);
    return const Color(0xFF64748B);
  }
}
