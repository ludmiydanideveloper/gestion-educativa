class PrintHelper {
  static void imprimirBoletin({
    required String studentName,
    required String dni,
    required String cursoName,
    required List<Map<String, dynamic>> materias,
    required List<Map<String, dynamic>> calificaciones,
    required List<Map<String, dynamic>> categorias,
    String? observaciones,
  }) {
    throw UnsupportedError('La impresión solo está soportada en Web.');
  }

  static void imprimirAsistencia({
    required String studentName,
    required String dni,
    required String cursoName,
    required List<Map<String, dynamic>> asistencias,
  }) {
    throw UnsupportedError('La impresión solo está soportada en Web.');
  }

  static void imprimirHTML({required String titulo, required String htmlContentBody}) {
    throw UnsupportedError('La impresión solo está soportada en Web.');
  }

  static void imprimirTrayectoriaYAnalitico({
    required String studentName,
    required String dni,
    required String cursoActual,
    required List<Map<String, dynamic>> trayectoria,
    required List<Map<String, dynamic>> materiasAdeudadas,
  }) {
    throw UnsupportedError('La impresión solo está soportada en Web.');
  }

  static void imprimirConstanciaAlumnoRegular({
    required String studentName,
    required String dni,
    required String cursoName,
    String? codigoVerificacion,
  }) {
    throw UnsupportedError('La impresión solo está soportada en Web.');
  }

  static void imprimirFaltasPorMateria({
    required String cursoName,
    required String materiaName,
    required List<Map<String, dynamic>> alumnosFaltas,
  }) {
    throw UnsupportedError('La impresión solo está soportada en Web.');
  }

  static void seleccionarArchivoWeb({
    required Function(String nombreArchivo, String formato, String base64Data) onArchivoSeleccionado,
    required Function(String error) onError,
  }) {
    throw UnsupportedError('La selección de archivos solo está soportada en Web.');
  }

  static void abrirArchivoWeb(String base64Data) {
    throw UnsupportedError('Abrir archivos solo está soportado en Web.');
  }
}

