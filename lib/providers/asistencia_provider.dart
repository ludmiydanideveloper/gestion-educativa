import 'package:flutter/material.dart';
import '../models/alumno_asistencia.dart';
import '../services/supabase_service.dart';

class AsistenciaProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  List<AlumnoAsistencia> _alumnos = [];
  bool _isLoading = false;
  bool _yaGuardadaHoy = false;

  List<AlumnoAsistencia> get alumnos => _alumnos;
  bool get isLoading => _isLoading;

  /// true si al cargar ya existía una planilla registrada para hoy: la vista
  /// pasa a "modo edición" (precargada) y evita una segunda toma.
  bool get yaGuardadaHoy => _yaGuardadaHoy;

  int contar(EstadoAsistencia e) => _alumnos.where((a) => a.estado == e).length;

  /// Vuelve todos los alumnos a "presente" y sale del modo edición, para tomar
  /// la lista de cero (el guardado igual sobrescribe la planilla del día).
  void reiniciarPlanilla() {
    _alumnos = _alumnos
        .map((a) => AlumnoAsistencia(id: a.id, nombre: a.nombre))
        .toList();
    _yaGuardadaHoy = false;
    notifyListeners();
  }

  Future<void> cargarAlumnos({String? cursoId, String? materiaId}) async {
    _isLoading = true;
    _yaGuardadaHoy = false;
    _alumnos = []; // Limpiamos la lista anterior para evitar "Bad state: No element"
    notifyListeners();

    try {
      _alumnos = await _supabaseService.fetchAlumnos(cursoId: cursoId);

      // Precargar la planilla del día si ya se tomó lista.
      if (cursoId != null) {
        final previa = await _supabaseService.obtenerAsistenciaDelDia(
          cursoId: cursoId,
          materiaId: materiaId,
          fecha: DateTime.now(),
        );
        if (previa != null) {
          _yaGuardadaHoy = true;
          final estados = previa['estados'] as Map<String, EstadoAsistencia>;
          _alumnos = _alumnos
              .map((a) => estados.containsKey(a.id)
                  ? a.copyWith(estado: estados[a.id])
                  : a)
              .toList();
        }
      }
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

      // 2. Crear detalles en lote asociados a la cabecera (reemplaza los previos)
      await _supabaseService.insertDetalles(cabeceraId, _alumnos);

      _yaGuardadaHoy = true;
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
