class Alerta {
  final String alertaId;
  final String alumnoId;
  final String tipoAlerta;
  final String gravedad;
  final String mensaje;
  final String estado;
  final DateTime fechaCreacion;

  Alerta({
    required this.alertaId,
    required this.alumnoId,
    required this.tipoAlerta,
    required this.gravedad,
    required this.mensaje,
    required this.estado,
    required this.fechaCreacion,
  });

  factory Alerta.fromJson(Map<String, dynamic> json) {
    return Alerta(
      alertaId: json['alerta_id'] as String,
      alumnoId: json['alumno_id'] as String,
      tipoAlerta: json['tipo_alerta'] as String,
      gravedad: json['gravedad'] as String,
      mensaje: json['mensaje'] as String,
      estado: json['estado'] as String,
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alerta_id': alertaId,
      'alumno_id': alumnoId,
      'tipo_alerta': tipoAlerta,
      'gravedad': gravedad,
      'mensaje': mensaje,
      'estado': estado,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }
}
