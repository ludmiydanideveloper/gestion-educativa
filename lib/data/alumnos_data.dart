/// Lista real de alumnos del Instituto Adventista de Baradero 2026.
/// Extraída de las planillas oficiales del colegio.

class AlumnoData {
  final String nombre;
  final int numero; // Número de lista

  const AlumnoData(this.numero, this.nombre);
}

class CursoAlumnos {
  final String curso;
  final List<AlumnoData> alumnos;

  const CursoAlumnos({required this.curso, required this.alumnos});
}

class AlumnosData {
  static const List<CursoAlumnos> cursos = [
    // ─── 1° AÑO ES (32 alumnos) ─────────────────────────────────────────
    CursoAlumnos(curso: '1° SEC', alumnos: [
      AlumnoData(1, 'ABADIE SANTINO'),
      AlumnoData(2, 'BAIER MIRKO GAEL'),
      AlumnoData(3, 'BOBROWSKI VELAZQUEZ IAN FRANCO'),
      AlumnoData(4, 'BONAHORA NOA SOFIA'),
      AlumnoData(5, 'BRONTES CATALINA'),
      AlumnoData(6, 'CALVA MATIAS'),
      AlumnoData(7, 'CASTRO VEGA URIEL SANTINO'),
      AlumnoData(8, 'CENTURION FRANCESCA FABIANA'),
      AlumnoData(9, 'DE LA COLINA NICOLE SELENE'),
      AlumnoData(10, 'ELIAS AMMA ISABELLA'),
      AlumnoData(11, 'HABEGGER LIZ'),
      AlumnoData(12, 'HERMO FACUNDO'),
      AlumnoData(13, 'JUAREZ ELIAN NAHUEL'),
      AlumnoData(14, 'KRAUS KILLIAN ERIK'),
      AlumnoData(15, 'LEAL MAITENA JAZMIN'),
      AlumnoData(16, 'MAS VALENTINO VICTOR'),
      AlumnoData(17, 'MATIAS JAZMIN'),
      AlumnoData(18, 'NOVELLA CORRES PIERO'),
      AlumnoData(19, 'OCHOA FRANCISCO ALBERTO'),
      AlumnoData(20, 'OTTO SOFIA MICAELA'),
      AlumnoData(21, 'PAGLINO QUIROGA MALENA'),
      AlumnoData(22, 'RIELF EYLEN'),
      AlumnoData(23, 'RIVADENEYRA INDI'),
      AlumnoData(24, 'RODRIGUEZ ORIANA'),
      AlumnoData(25, 'RODRIGUEZ ZOE'),
      AlumnoData(26, 'SANCHEZ RENATA'),
      AlumnoData(27, 'SARMIENTO LUCAS CONSTANTINO'),
      AlumnoData(28, 'SCHVEMMER RENATA'),
      AlumnoData(29, 'TORRES MATEO GABRIEL'),
      AlumnoData(30, 'TRAVERSO FRANCESCA'),
      AlumnoData(31, 'VERGARA ESTEBAN DANIEL'),
      AlumnoData(32, 'VIZCONTI AMBAR'),
    ]),

    // ─── 2° AÑO ES (23 alumnos) ─────────────────────────────────────────
    CursoAlumnos(curso: '2° SEC', alumnos: [
      AlumnoData(1, 'ARLIA OTERMIN ELIAS'),
      AlumnoData(2, 'AVILA DYLAN TADEO'),
      AlumnoData(3, 'BATISTUTTI ROMERO ALVARO VALENTIN'),
      AlumnoData(4, 'BRIZUELA BENJAMIN WALTER'),
      AlumnoData(5, 'CABALLERO BALTAZAR DAVID'),
      AlumnoData(6, 'CARRERAS CIRO'),
      AlumnoData(7, 'GOMEZ NATASHA ISABELLA'),
      AlumnoData(8, 'GONZALEZ CAMACHO AMPARO MAGALI'),
      AlumnoData(9, 'HABEGGER ELISA'),
      AlumnoData(10, 'IBARROLA BRIANA IRINA'),
      AlumnoData(11, 'MAYER LUISIANA HAYDEE'),
      AlumnoData(12, 'MENDEZ ENCINA JUANA'),
      AlumnoData(13, 'MORALES KIARA BELEN'),
      AlumnoData(14, 'OLIVA MELO MATEO BENJAMIN'),
      AlumnoData(15, 'RIVADENEIRA JUAN SEBASTIAN'),
      AlumnoData(16, 'ROBLES VEGA NAHIARA MIA'),
      AlumnoData(17, 'SALVALICH OLIVIA'),
      AlumnoData(18, 'SANTOS MORENA'),
      AlumnoData(19, 'SCHWARZ ZOE'),
      AlumnoData(20, 'SVOLA VIOLETA'),
      AlumnoData(21, 'VIERA THIAGO EMMANUEL'),
      AlumnoData(22, 'VILLARRUEL ZOE PILAR'),
      AlumnoData(23, 'ZUÑIGA MOREL THIAGO EMMANUEL'),
    ]),

    // ─── 3° AÑO ES (23 alumnos) ─────────────────────────────────────────
    CursoAlumnos(curso: '3° SEC', alumnos: [
      AlumnoData(1, 'AVANCINI GORAN'),
      AlumnoData(2, 'BELLO MIQUEAS AMIEL'),
      AlumnoData(3, 'BODY MATEO'),
      AlumnoData(4, 'BOCCARDO ALMA'),
      AlumnoData(5, 'BONAHORA ISABELLA VALENTINA'),
      AlumnoData(6, 'BRANCATISANO ABRIL TIZIANA'),
      AlumnoData(7, 'CASTILLO RIFFO JAZMIN QUIMEY'),
      AlumnoData(8, 'COLAME JUAN BAUTISTA'),
      AlumnoData(9, 'DEL BEN NICOLAS ANGEL'),
      AlumnoData(10, 'FERNANDEZ HEREDIA AUGUSTO MISAEL'),
      AlumnoData(11, 'FUNES FACUNDO NAHUEL'),
      AlumnoData(12, 'GUO LEANTO'),
      AlumnoData(13, 'LOPEZ JUAN MANUEL'),
      AlumnoData(14, 'NIDERHAUS SIMON'),
      AlumnoData(15, 'NOBREGA THIAGO JOAQUIN'),
      AlumnoData(16, 'NUÑEZ SANTINO JULIAN'),
      AlumnoData(17, 'PERA SEQUEIRA SEBASTIAN'),
      AlumnoData(18, 'RIOS FILIPO'),
      AlumnoData(19, 'RODRIGUEZ TIZIANA ESTRELLA'),
      AlumnoData(20, 'ROMERO THIAGO NAHUEL'),
      AlumnoData(21, 'SCHWEMMER ZOE JAZMIN'),
      AlumnoData(22, 'TORRES BENJAMIN'),
      AlumnoData(23, 'VELEZ LARA NATALIE'),
    ]),

    // ─── 4° AÑO ES (18 alumnos) ─────────────────────────────────────────
    CursoAlumnos(curso: '4° SEC', alumnos: [
      AlumnoData(1, 'ARTIMIAK SPIES ASLAN'),
      AlumnoData(2, 'BRONTES JUAN PABLO'),
      AlumnoData(3, 'CORONEL FEDERICO'),
      AlumnoData(4, 'FOSSATI GIULANA MARIA'),
      AlumnoData(5, 'GOMEZ SANTIAGO NICOLAS'),
      AlumnoData(6, 'JAIME JONATHAN EMANUEL'),
      AlumnoData(7, 'LIZARRAGA GRIGONI LAUTARO LEANDRO'),
      AlumnoData(8, 'LOPEZ DA SILVA EVA'),
      AlumnoData(9, 'MACHADO THOMAS'),
      AlumnoData(10, 'MORENO LUPE'),
      AlumnoData(11, 'OLIVA MELO LARA MILAGROS'),
      AlumnoData(12, 'SALDIVIA JAZMIN AYELEN'),
      AlumnoData(13, 'SALDIVIA VALENTINO NEREO'),
      AlumnoData(14, 'SCHIRO FAUSTINO'),
      AlumnoData(15, 'SEGOVIA ZOE YAZMIN'),
      AlumnoData(16, 'SPELLER MALENA VICTORIA'),
      AlumnoData(17, 'VELASQUEZ ALMA VALENTINA'),
      AlumnoData(18, 'VELEZ GAITAN MORENA AILIN'),
    ]),

    // ─── 5° AÑO ES (17 alumnos) ─────────────────────────────────────────
    CursoAlumnos(curso: '5° SEC', alumnos: [
      AlumnoData(1, 'BATISTUTTI ROMERO ALEJO IGNACIO'),
      AlumnoData(2, 'BAEZ MORENA'),
      AlumnoData(3, 'CACERES REINHARDT DAYRA ANAHY'),
      AlumnoData(4, 'CARDOZO TIZIANA'),
      AlumnoData(5, 'COLAME JUAN IGNACIO'),
      AlumnoData(6, 'FRANCO MARTINA'),
      AlumnoData(7, 'GENTILINI ELIAS IGNACIO'),
      AlumnoData(8, 'GOMEZ MARCOS NATANAEL'),
      AlumnoData(9, 'LOPEZ DA SILVA ESTER ABIGAIL'),
      AlumnoData(10, 'MORALES AZUL'),
      AlumnoData(11, 'MARTINEZ LOLA'),
      AlumnoData(12, 'RAMIREZ AREBALO MAXIMILIANO'),
      AlumnoData(13, 'RETAMAL JUAN JONAS'),
      AlumnoData(14, 'RODRIGUEZ LEANDRO'),
      AlumnoData(15, 'ROMERO EMANUEL'),
      AlumnoData(16, 'TORREIRA CARMELO MAITENA SIMONA'),
      AlumnoData(17, 'VOGEL JUAN BAUTISTA'),
    ]),

    // ─── 6° AÑO ES (16 alumnos) ─────────────────────────────────────────
    CursoAlumnos(curso: '6° SEC', alumnos: [
      AlumnoData(1, 'BONAHORA MIA NAHIR'),
      AlumnoData(2, 'CABALLERO JAVIER ZAIR'),
      AlumnoData(3, 'CUFRE ALEJO LUJAN'),
      AlumnoData(4, 'FRANCHETTO JUANA BELEN'),
      AlumnoData(5, 'GALLARDO JEREMIAS GASTON'),
      AlumnoData(6, 'HAXHI AILEN'),
      AlumnoData(7, 'JAIME NOELIA ABIGAIL'),
      AlumnoData(8, 'LOPEZ MAIA ANTONELLA'),
      AlumnoData(9, 'MAYER ARABELL EILEEN'),
      AlumnoData(10, 'MORALES VALENTINO NICOLAS'),
      AlumnoData(11, 'NEYRA BRANDON'),
      AlumnoData(12, 'PERTICONE LARA'),
      AlumnoData(13, 'PEZZATI BAUTISTA'),
      AlumnoData(14, 'RIOS NAHIARA'),
      AlumnoData(15, 'SVOLA AGUSTIN DANIEL'),
      AlumnoData(16, 'VIEYRA AMELIA'),
    ]),
  ];

  /// Total de alumnos en toda la escuela
  static int get totalAlumnos =>
      cursos.fold(0, (sum, c) => sum + c.alumnos.length);

  /// Busca un curso por nombre flexible
  static CursoAlumnos? buscarCurso(String nombre) {
    final n = nombre.toUpperCase().replaceAll(' ', '').replaceAll('°', '');
    for (final c in cursos) {
      final cn = c.curso.toUpperCase().replaceAll(' ', '').replaceAll('°', '');
      if (cn == n || n.contains(cn) || cn.contains(n)) return c;
    }
    return null;
  }

  /// Resumen rápido: cantidad de alumnos por curso
  static Map<String, int> get resumenPorCurso =>
      {for (final c in cursos) c.curso: c.alumnos.length};
}
