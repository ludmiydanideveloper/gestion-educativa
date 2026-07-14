import 'package:flutter/material.dart';

enum EstadoAsistencia {
  presente,
  ausente,
  tarde,
  retiro;

  String get label {
    switch (this) {
      case EstadoAsistencia.presente:
        return 'Presente';
      case EstadoAsistencia.ausente:
        return 'Ausente';
      case EstadoAsistencia.tarde:
        return 'Tarde';
      case EstadoAsistencia.retiro:
        return 'Retiro';
    }
  }
}

class AlumnoAsistencia {
  final String id;
  final String nombre;
  final EstadoAsistencia estado;
  final TimeOfDay? horaEvento;

  const AlumnoAsistencia({
    required this.id,
    required this.nombre,
    this.estado = EstadoAsistencia.presente,
    this.horaEvento,
  });

  AlumnoAsistencia copyWith({
    String? id,
    String? nombre,
    EstadoAsistencia? estado,
    TimeOfDay? horaEvento,
  }) {
    return AlumnoAsistencia(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      estado: estado ?? this.estado,
      horaEvento: horaEvento ?? this.horaEvento,
    );
  }

  @override
  String toString() {
    final horaStr = horaEvento != null 
        ? ' (${horaEvento!.hour.toString().padLeft(2, '0')}:${horaEvento!.minute.toString().padLeft(2, '0')})' 
        : '';
    return '$nombre: ${estado.label}$horaStr';
  }
}
