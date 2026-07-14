import 'package:flutter/material.dart';
import '../models/alumno_asistencia.dart';
import '../services/supabase_service.dart';

class AsistenciaProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  List<AlumnoAsistencia> _alumnos = [];
  bool _isLoading = false;

  List<AlumnoAsistencia> get alumnos => _alumnos;
  bool get isLoading => _isLoading;

  Future<void> cargarAlumnos({String? cursoId}) async {
    _isLoading = true;
    _alumnos = []; // Limpiamos la lista anterior para evitar "Bad state: No element"
    notifyListeners();

    try {
      _alumnos = await _supabaseService.fetchAlumnos(cursoId: cursoId);
    } catch (e) {
      debugPrint('Error al cargar alumnos: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void actualizarEstado(String id, EstadoAsistencia nuevoEstado) {
    final index = _alumnos.indexWhere((a) => a.id == id);
    if (index != -1) {
      final alumno = _alumnos[index];
      
      // Si el estado no es tarde ni retiro, limpiamos la hora
      TimeOfDay? nuevaHora = alumno.horaEvento;
      if (nuevoEstado != EstadoAsistencia.tarde && nuevoEstado != EstadoAsistencia.retiro) {
        nuevaHora = null;
      } else if (nuevaHora == null) {
        nuevaHora = TimeOfDay.now();
      }

      _alumnos[index] = alumno.copyWith(
        estado: nuevoEstado,
        horaEvento: nuevaHora,
      );
      notifyListeners();
    }
  }

  void actualizarHora(String id, TimeOfDay? nuevaHora) {
    final index = _alumnos.indexWhere((a) => a.id == id);
    if (index != -1) {
      _alumnos[index] = _alumnos[index].copyWith(
        horaEvento: nuevaHora,
      );
      notifyListeners();
    }
  }

  /// Ejecuta secuencialmente la creación de la cabecera y el detalle en Supabase
  Future<bool> guardarAsistencia({
    String? cursoId,
    String? materiaId,
    String tipoAsistencia = 'PRECEPTOR_DIARIA',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Crear cabecera y obtener el ID autogenerado con separación de materia vs preceptor
      final cabeceraId = await _supabaseService.insertCabecera(
        cursoId: cursoId ?? SupabaseService.cursoIdMock,
        fecha: DateTime.now(),
        docenteId: SupabaseService.docenteIdMock,
        materiaId: materiaId,
        tipoAsistencia: materiaId != null ? 'POR_MATERIA' : tipoAsistencia,
      );

      // 2. Crear detalles en lote asociados a la cabecera
      await _supabaseService.insertDetalles(cabeceraId, _alumnos);
      
      return true;
    } catch (e) {
      debugPrint('Error al guardar la planilla en Supabase: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
