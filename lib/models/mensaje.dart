class Mensaje {
  final String destinatarioId;
  final String mensajeId;
  final String usuarioId;
  final DateTime? fechaLectura;
  final bool archivado;

  // Joined columns from com_mensajes
  final String emisorId;
  final String asunto;
  final Map<String, dynamic> cuerpo;
  final bool requiereFirma;
  final DateTime fechaCreacion;

  Mensaje({
    required this.destinatarioId,
    required this.mensajeId,
    required this.usuarioId,
    this.fechaLectura,
    required this.archivado,
    required this.emisorId,
    required this.asunto,
    required this.cuerpo,
    required this.requiereFirma,
    required this.fechaCreacion,
  });

  bool get esLeido => fechaLectura != null;

  factory Mensaje.fromJson(Map<String, dynamic> json) {
    final cabecera = json['com_mensajes'] as Map<String, dynamic>;
    
    // El cuerpo puede venir serializado como Map o como otra estructura JSON
    final cuerpoData = cabecera['cuerpo'] is Map 
        ? Map<String, dynamic>.from(cabecera['cuerpo'] as Map) 
        : <String, dynamic>{'texto': cabecera['cuerpo'].toString()};

    return Mensaje(
      destinatarioId: json['destinatario_id'] as String,
      mensajeId: json['mensaje_id'] as String,
      usuarioId: json['usuario_id'] as String,
      fechaLectura: json['fecha_lectura'] != null 
          ? DateTime.parse(json['fecha_lectura'] as String) 
          : null,
      archivado: json['archivado'] as bool? ?? false,
      emisorId: cabecera['emisor_id'] as String,
      asunto: cabecera['asunto'] as String,
      cuerpo: cuerpoData,
      requiereFirma: cabecera['requiere_firma'] as bool? ?? false,
      fechaCreacion: DateTime.parse(cabecera['fecha_creacion'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'destinatario_id': destinatarioId,
      'mensaje_id': mensajeId,
      'usuario_id': usuarioId,
      'fecha_lectura': fechaLectura?.toIso8601String(),
      'archivado': archivado,
      'com_mensajes': {
        'emisor_id': emisorId,
        'asunto': asunto,
        'cuerpo': cuerpo,
        'requiere_firma': requiereFirma,
        'fecha_creacion': fechaCreacion.toIso8601String(),
      }
    };
  }
}
