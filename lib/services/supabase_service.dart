import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/alumno_asistencia.dart';
import '../models/mensaje.dart';
import '../data/alumnos_data.dart';

class SupabaseService {
  // Cliente de Supabase obtenido de la instancia global.
  final SupabaseClient _client = Supabase.instance.client;

  // UUID de Curso y Docente insertados en el seed de la base de datos
  static const String cursoIdMock = '953fc2c3-0737-4ce8-983f-445e67b50f10';
  static const String docenteIdMock = 'b21dde9b-9afe-4c33-8833-ff3b0df8a6d9';

  /// Inicia sesión con email y contraseña utilizando la autenticación nativa de Supabase
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Cierra la sesión activa en el cliente de Supabase
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Actualiza el estado de una alerta a 'RESUELTA' en la tabla acad_alertas
  Future<void> marcarAlertaResuelta(String alertaId) async {
    await _client
        .from('acad_alertas')
        .update({'estado': 'RESUELTA'})
        .eq('alerta_id', alertaId);
  }

  /// Obtiene los detalles de asistencia del alumno autenticado.
  /// Supabase filtra los registros automáticamente vía Row Level Security (RLS)
  /// basándose en el auth.uid() de la sesión.
  Future<List<Map<String, dynamic>>> obtenerMiAsistencia() async {
    final response = await _client
        .from('asistencia_detalle')
        .select('''
          asistencia_detalle_id, 
          valor_inasistencia, 
          tipo, 
          estado_justificacion, 
          url_certificado, 
          asistencia_cabecera (fecha)
        ''');
        
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtiene la bandeja de entrada de comunicados para el usuario actual
  Future<List<Mensaje>> obtenerBandejaEntrada() async {
    final response = await _client
        .from('com_destinatarios')
        .select('''
          destinatario_id,
          mensaje_id,
          usuario_id,
          fecha_lectura,
          archivado,
          com_mensajes (
            emisor_id,
            asunto,
            cuerpo,
            requiere_firma,
            fecha_creacion
          )
        ''')
        .eq('usuario_id', _client.auth.currentUser?.id ?? '')
        .eq('archivado', false);
        
    final list = List<Map<String, dynamic>>.from(response);
    final mensajes = list.map((json) => Mensaje.fromJson(json)).toList();
    
    // Ordenar de manera descendente por fecha de creación en el lado del cliente (Dart)
    mensajes.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    return mensajes;
  }

  /// Marca un mensaje de la bandeja de entrada como leído
  Future<void> marcarMensajeComoLeido(String destinatarioId) async {
    await _client
        .from('com_destinatarios')
        .update({'fecha_lectura': DateTime.now().toUtc().toIso8601String()})
        .eq('destinatario_id', destinatarioId);
  }

  /// Marca todos los mensajes pendientes/no leídos del usuario como leídos
  Future<void> marcarTodosComoLeidos() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('com_destinatarios')
        .update({'fecha_lectura': DateTime.now().toUtc().toIso8601String()})
        .eq('usuario_id', user.id)
        .isFilter('fecha_lectura', null);
  }

  Future<List<AlumnoAsistencia>> fetchAlumnos({String? cursoId}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return _fallbackLocalAlumnos(cursoId);

      String idCurso = cursoId ?? cursoIdMock;

      // Si es el mock o nulo, intentamos resolver el primer curso real de la escuela
      if (cursoId == null || cursoId == cursoIdMock) {
        try {
          final primerCurso = await _client
              .from('acad_cursos')
              .select('curso_id')
              .limit(1)
              .maybeSingle();
          if (primerCurso != null && primerCurso['curso_id'] != null) {
            idCurso = primerCurso['curso_id'] as String;
          }
        } catch (_) {}
      }

      final response = await _client
          .from('acad_inscripciones')
          .select('''
            alumno_id,
            usr_legajo_alumno (
              datos_demograficos
            )
          ''')
          .eq('curso_id', idCurso);

      final list = List<Map<String, dynamic>>.from(response);
      final listAlumnos = list.map((item) {
        final alumno = item['usr_legajo_alumno'] as Map<String, dynamic>?;
        final demo = alumno?['datos_demograficos'] as Map<String, dynamic>?;
        final nombreCompleto = '${demo?['apellido'] ?? ''} ${demo?['nombre'] ?? ''}'.trim();
        return AlumnoAsistencia(
          id: (item['alumno_id'] ?? '').toString(),
          nombre: nombreCompleto.isNotEmpty ? nombreCompleto : 'Alumno Sin Nombre',
        );
      }).toList();

      // Ordenar alfabéticamente
      listAlumnos.sort((a, b) => a.nombre.compareTo(b.nombre));

      if (listAlumnos.isEmpty) {
        return _fallbackLocalAlumnos(cursoId);
      }

      return listAlumnos;
    } catch (e) {
      print('Error al obtener alumnos reales de Supabase: $e');
      return _fallbackLocalAlumnos(cursoId);
    }
  }

  /// Método fallback de carga de alumnos locales offline
  Future<List<AlumnoAsistencia>> _fallbackLocalAlumnos(String? cursoId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Si no hay cursoId, intentamos deducir el curso del docente o preceptor (1° SEC por defecto)
    String divisionName = '1° SEC';
    if (cursoId != null) {
      try {
        final cur = await _client
            .from('acad_cursos')
            .select('identificador_division')
            .eq('curso_id', cursoId)
            .maybeSingle();
        if (cur != null && cur['identificador_division'] != null) {
          divisionName = cur['identificador_division'] as String;
        }
      } catch (_) {}
    }

    final cursoObj = AlumnosData.buscarCurso(divisionName);
    if (cursoObj != null) {
      return cursoObj.alumnos
          .map((a) => AlumnoAsistencia(id: 'local_${a.numero}', nombre: a.nombre))
          .toList();
    }

    // Default ultra fallback
    return AlumnosData.cursos.first.alumnos
        .map((a) => AlumnoAsistencia(id: 'local_${a.numero}', nombre: a.nombre))
        .toList();
  }

  /// Inserta la cabecera de la asistencia diaria y retorna el UUID generado
  Future<String> insertCabecera({
    required String cursoId,
    required DateTime fecha,
    required String docenteId,
    String? materiaId,
    String tipoAsistencia = 'PRECEPTOR_DIARIA',
  }) async {
    String finalDocenteId = docenteId;
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        final docenteData = await _client
            .from('usr_docentes')
            .select('docente_id')
            .eq('auth_id', user.id)
            .maybeSingle();
        if (docenteData != null && docenteData['docente_id'] != null) {
          finalDocenteId = docenteData['docente_id'] as String;
        }
      } catch (e) {
        // En caso de error, se utiliza el mock provisto
        print('Error resolviendo docente_id real: $e');
      }
    }

    final dia = fecha.toIso8601String().substring(0, 10);
    final tipoFinal = materiaId != null ? 'POR_MATERIA' : tipoAsistencia;

    // ¿Ya hay planilla de ese día/curso/tipo? Entonces se REUSA (la toma pasa a
    // ser una edición) en vez de crear una segunda: así no se puede tomar lista
    // dos veces ni chocar con el índice único parcial de asistencia_cabecera.
    try {
      var q = _client
          .from('asistencia_cabecera')
          .select('asistencia_cabecera_id')
          .eq('curso_id', cursoId)
          .eq('fecha', dia)
          .eq('tipo_asistencia', tipoFinal);
      q = materiaId != null
          ? q.eq('materia_id', materiaId)
          : q.isFilter('materia_id', null);
      final existente = await q.maybeSingle();
      if (existente != null) {
        final id = existente['asistencia_cabecera_id'] as String;
        await _client
            .from('asistencia_cabecera')
            .update({'estado': 'APROBADO', 'registrado_por_docente_id': finalDocenteId})
            .eq('asistencia_cabecera_id', id);
        return id;
      }
    } catch (e) {
      print('Aviso: no se pudo verificar planilla previa: $e');
    }

    final response = await _client.from('asistencia_cabecera').insert({
      'curso_id': cursoId,
      'fecha': dia, // Formato YYYY-MM-DD
      'estado': 'APROBADO', // Planilla aprobada
      'registrado_por_docente_id': finalDocenteId,
      'materia_id': materiaId,
      'tipo_asistencia': tipoFinal,
    }).select('asistencia_cabecera_id').single();

    // Notificar a Administración / Dirección sobre la toma de asistencia
    obtenerAuthIdsAdministracion().then((adminIds) {
      notificarSistema(
        asunto: 'Movimiento Escolar: Toma de Asistencia ($dia)',
        texto: 'Se ha registrado la planilla de asistencia ($tipoFinal) en el curso.',
        destinatariosAuthIds: adminIds,
      );
    });

    return response['asistencia_cabecera_id'] as String;
  }

  /// Inserta de forma masiva (bulk insert) todos los detalles de asistencia.
  /// Primero borra los detalles previos de esa cabecera, así volver a guardar
  /// (editar) la planilla reemplaza en vez de duplicar filas.
  Future<void> insertDetalles(String cabeceraId, List<AlumnoAsistencia> alumnos) async {
    await _client
        .from('asistencia_detalle')
        .delete()
        .eq('asistencia_cabecera_id', cabeceraId);

    final detalles = alumnos.map((alumno) {
      return {
        'asistencia_cabecera_id': cabeceraId,
        'alumno_id': alumno.id,
        'valor_inasistencia': _obtenerValorInasistencia(alumno.estado),
        'tipo': _obtenerTipoInasistencia(alumno.estado),
        'estado_justificacion': 'NINGUNO',
        'url_certificado': null,
      };
    }).toList();

    await _client.from('asistencia_detalle').insert(detalles);
  }

  /// Registra una incidencia de conducta en la base de datos
  Future<void> registrarIncidencia({
    required String alumnoId,
    required String tipoIncidencia,
    required String severidad,
    required String descripcion,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final docenteData = await _client
        .from('usr_docentes')
        .select('docente_id')
        .eq('auth_id', user.id)
        .single();
    
    final docenteId = docenteData['docente_id'];

    await _client.from('aca_conducta').insert({
      'alumno_id': alumnoId,
      'docente_id': docenteId,
      'tipo_incidencia': tipoIncidencia,
      'severidad': severidad,
      'descripcion': descripcion,
    });

    // Notificar a Administración / Equipo Directivo
    obtenerAuthIdsAdministracion().then((adminIds) {
      notificarSistema(
        asunto: 'Movimiento de Convivencia: $tipoIncidencia ($severidad)',
        texto: descripcion,
        destinatariosAuthIds: adminIds,
      );
    });
  }

  /// Borra los registros de CONDUCTA DIARIA de una fecha para los alumnos dados.
  /// Se llama antes de volver a guardar la planilla del día: sin esto, guardar
  /// dos veces el mismo día duplica las filas y altera la nota RITE de conducta
  /// (un "Mal" contado dos veces baja 3 puntos en vez de 1,5).
  /// Solo toca filas cuya descripción arranca con "Conducta diaria:", así que
  /// las sanciones e incidencias reales quedan intactas.
  Future<void> limpiarConductaDiaria({
    required List<String> alumnoIds,
    required DateTime fecha,
  }) async {
    if (alumnoIds.isEmpty) return;
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final desde = dia.toIso8601String();
    final hasta = dia.add(const Duration(days: 1)).toIso8601String();
    try {
      await _client
          .from('aca_conducta')
          .delete()
          .inFilter('alumno_id', alumnoIds)
          .like('descripcion', 'Conducta diaria:%')
          .gte('fecha', desde)
          .lt('fecha', hasta);
    } catch (e) {
      print('Error al limpiar conducta diaria previa: $e');
    }
  }

  // Mapeo algorítmico del valor decimal de la falta según estado
  double _obtenerValorInasistencia(EstadoAsistencia estado) {
    switch (estado) {
      case EstadoAsistencia.presente:
        return 0.00;
      case EstadoAsistencia.ausente:
        return 1.00;
      case EstadoAsistencia.tarde:
        return 0.25;
      case EstadoAsistencia.retiro:
        return 0.50;
    }
  }

  // Mapeo del tipo de asistencia correspondiente en la base de datos
  String _obtenerTipoInasistencia(EstadoAsistencia estado) {
    switch (estado) {
      case EstadoAsistencia.presente:
        return 'PRESENTE';
      case EstadoAsistencia.ausente:
        return 'AUSENTE';
      case EstadoAsistencia.tarde:
        return 'TARDE';
      case EstadoAsistencia.retiro:
        return 'RETIRO_ANTICIPADO';
    }
  }

  /// Inverso de [_obtenerTipoInasistencia]: reconstruye el estado a partir del
  /// texto guardado, para poder precargar una planilla ya registrada.
  EstadoAsistencia estadoAsistenciaDesdeTipo(String? tipo) {
    switch ((tipo ?? '').toUpperCase()) {
      case 'AUSENTE':
        return EstadoAsistencia.ausente;
      case 'TARDE':
        return EstadoAsistencia.tarde;
      case 'RETIRO_ANTICIPADO':
      case 'RETIRO':
        return EstadoAsistencia.retiro;
      default:
        return EstadoAsistencia.presente;
    }
  }

  /// Devuelve la planilla de asistencia ya cargada para ese día (o null).
  /// `{ 'cabeceraId': String, 'estados': Map<alumnoId, EstadoAsistencia> }`.
  Future<Map<String, dynamic>?> obtenerAsistenciaDelDia({
    required String cursoId,
    String? materiaId,
    required DateTime fecha,
  }) async {
    final dia = fecha.toIso8601String().substring(0, 10);
    try {
      var q = _client
          .from('asistencia_cabecera')
          .select('asistencia_cabecera_id')
          .eq('curso_id', cursoId)
          .eq('fecha', dia);
      if (materiaId != null) {
        q = q.eq('materia_id', materiaId).eq('tipo_asistencia', 'POR_MATERIA');
      } else {
        q = q.eq('tipo_asistencia', 'PRECEPTOR_DIARIA');
      }
      final cab = await q.maybeSingle();
      if (cab == null) return null;
      final cabeceraId = cab['asistencia_cabecera_id'] as String;

      final det = await _client
          .from('asistencia_detalle')
          .select('alumno_id, tipo')
          .eq('asistencia_cabecera_id', cabeceraId);

      final estados = <String, EstadoAsistencia>{
        for (final d in det)
          (d['alumno_id'] as String): estadoAsistenciaDesdeTipo(d['tipo'] as String?)
      };
      return {'cabeceraId': cabeceraId, 'estados': estados};
    } catch (e) {
      print('Error al obtener asistencia del día: $e');
      return null;
    }
  }

  /// Obtiene las categorías de calificaciones con sus ponderaciones
  Future<List<Map<String, dynamic>>> obtenerCategoriasCalificaciones() async {
    final response = await _client
        .from('aca_categorias_nota')
        .select('id, nombre, peso_porcentaje')
        .order('nombre', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtiene el docente_id correspondiente al usuario autenticado actual
  Future<String> obtenerDocenteIdActual() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    
    final docenteData = await _client
        .from('usr_docentes')
        .select('docente_id')
        .eq('auth_id', user.id)
        .single();
    return docenteData['docente_id'] as String;
  }

  /// Crea una nueva actividad académica para una materia.
  /// [categoriaId]: opcional — si es null la nota no pertenece a ninguna categoría/grupo.
  /// [tipoActividad]: 'NOTA' (default) | 'TAREA' | 'CLASE' | 'INFO' | 'CONDUCTA'.
  /// [pesoPorc]: peso opcional en % para el modo "Porcentaje por Actividad".
  Future<Map<String, dynamic>> crearActividad({
    required String materiaId,
    String? categoriaId,          // ahora opcional
    required String titulo,
    required DateTime fecha,
    double? pesoPorc,
    String tipoActividad = 'NOTA',
  }) async {
    final docenteId = await obtenerDocenteIdActual();

    final data = <String, dynamic>{
      'docente_id': docenteId,
      'materia_id': materiaId,
      'categoria_id': categoriaId,   // puede ser null
      'titulo': titulo,
      'fecha': fecha.toIso8601String().substring(0, 10),
      'tipo_actividad': tipoActividad,
    };
    if (pesoPorc != null) data['peso_porcentaje_actividad'] = pesoPorc;

    final response = await _client.from('aca_actividades').insert(data).select().single();
    
    // Notificar a Administración sobre creación de actividad pedagógica
    obtenerAuthIdsAdministracion().then((adminIds) {
      notificarSistema(
        asunto: 'Movimiento Docente: Actividad Creada ($titulo)',
        texto: 'Se ha cargado la actividad académica programada para el día ${fecha.toIso8601String().substring(0, 10)}.',
        destinatariosAuthIds: adminIds,
      );
    });

    return Map<String, dynamic>.from(response);
  }

  /// Obtiene todas las actividades creadas para una materia específica,
  /// incluyendo el peso individual por actividad (modo Porcentaje).
  Future<List<Map<String, dynamic>>> obtenerActividades(String materiaId) async {
    final response = await _client
        .from('aca_actividades')
        .select('id, docente_id, materia_id, categoria_id, titulo, fecha, peso_porcentaje_actividad, aca_categorias_nota(nombre, peso_porcentaje)')
        .eq('materia_id', materiaId)
        .order('fecha', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Guarda o actualiza una calificación para un alumno y actividad
  Future<void> upsertCalificacion({
    required String actividadId,
    required String alumnoId,
    required double? notaNumerica,
  }) async {
    try {
      final existing = await _client
          .from('aca_calificaciones')
          .select('id')
          .eq('actividad_id', actividadId)
          .eq('alumno_id', alumnoId)
          .maybeSingle();

      if (existing != null) {
        await _client
            .from('aca_calificaciones')
            .update({'nota_numerica': notaNumerica})
            .eq('id', existing['id']);
      } else {
        await _client.from('aca_calificaciones').insert({
          'actividad_id': actividadId,
          'alumno_id': alumnoId,
          'nota_numerica': notaNumerica,
        });
      }
    } catch (e) {
      // Fallback
      await _client.from('aca_calificaciones').upsert({
        'actividad_id': actividadId,
        'alumno_id': alumnoId,
        'nota_numerica': notaNumerica,
      }, onConflict: 'actividad_id,alumno_id');
    }

    // Notificar a Administración sobre carga o actualización de calificación
    obtenerAuthIdsAdministracion().then((adminIds) {
      notificarSistema(
        asunto: 'Movimiento Docente: Carga/Actualización de Calificación',
        texto: 'Se ha registrado o modificado una calificación en la planilla académica del alumno.',
        destinatariosAuthIds: adminIds,
      );
    });
  }


  /// Obtiene todas las calificaciones de una lista de actividades
  /// Para el panel de administración: todos los movimientos (actividades) de una
  /// materia con sus calificaciones y el docente que las cargó, para auditar lo
  /// que hace cada profesor en su planilla.
  Future<Map<String, dynamic>> obtenerMovimientosMateria(String materiaId) async {
    try {
      final actividades = await obtenerActividades(materiaId);
      final ids = actividades.map((a) => a['id'] as String).toList();
      final califs = await obtenerCalificacionesPorActividades(ids);

      // Nombres de los docentes que crearon actividades.
      final docenteIds = actividades
          .map((a) => a['docente_id'])
          .where((d) => d != null)
          .toSet()
          .toList();
      final Map<String, String> nombreDocente = {};
      if (docenteIds.isNotEmpty) {
        final docs = await _client
            .from('usr_docentes')
            .select('docente_id, nombre, apellido')
            .inFilter('docente_id', docenteIds);
        for (final d in docs) {
          final n = [d['apellido'], d['nombre']]
              .where((x) => x != null && x.toString().isNotEmpty)
              .join(', ');
          nombreDocente[d['docente_id'] as String] = n.isEmpty ? 'Docente' : n;
        }
      }

      final califPorActividad = <String, List<Map<String, dynamic>>>{};
      for (final c in califs) {
        califPorActividad
            .putIfAbsent(c['actividad_id'] as String, () => [])
            .add(c);
      }

      final movimientos = actividades.map((a) {
        final notas = califPorActividad[a['id']] ?? [];
        final cat = a['aca_categorias_nota'] as Map?;
        return {
          'id': a['id'],
          'titulo': a['titulo'],
          'fecha': a['fecha'],
          'categoria': cat?['nombre'] ?? '—',
          'docente': nombreDocente[a['docente_id']] ?? 'Docente',
          'notas_cargadas': notas.where((n) => n['nota_numerica'] != null).length,
          'calificaciones': notas,
        };
      }).toList();

      return {'movimientos': movimientos};
    } catch (e) {
      print('Error al obtener movimientos de materia: $e');
      return {'movimientos': []};
    }
  }

  Future<List<Map<String, dynamic>>> obtenerCalificacionesPorActividades(List<String> actividadIds) async {
    if (actividadIds.isEmpty) return [];
    
    final response = await _client
        .from('aca_calificaciones')
        .select('id, actividad_id, alumno_id, nota_numerica')
        .inFilter('actividad_id', actividadIds);
        
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtiene todas las materias si el usuario es preceptor/admin, o solo las suyas si es docente
  Future<List<Map<String, dynamic>>> obtenerMateriasParaRol() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    
    try {
      final docenteData = await _client
          .from('usr_docentes')
          .select('docente_id, ddjj_cargos')
          .eq('auth_id', user.id)
          .maybeSingle();
          
      if (docenteData != null) {
        final cargos = docenteData['ddjj_cargos']?.toString() ?? '';
        final isPreceptorOrAdmin = cargos.contains('PRECEPTOR') || cargos.contains('ADMIN');
        
        if (isPreceptorOrAdmin) {
          final response = await _client
              .from('acad_materias')
              .select('materia_id, nombre_asignatura, curso_id');
          return List<Map<String, dynamic>>.from(response);
        } else {
          final docenteId = docenteData['docente_id'] as String;
          final response = await _client
              .from('acad_materias')
              .select('materia_id, nombre_asignatura, curso_id')
              .eq('docente_titular_id', docenteId);
          return List<Map<String, dynamic>>.from(response);
        }
      }
      return [];
    } catch (e) {
      print('Error al obtener materias: $e');
      return [];
    }
  }

  /// Calcula el Promedio RITE para un alumno.
  /// Agrupa las notas por categoría, calcula el promedio de cada categoría,
  /// lo multiplica por su peso y retorna la nota final ponderada.
  double? calcularPromedioRite({
    required List<Map<String, dynamic>> actividades,
    required List<Map<String, dynamic>> calificaciones,
    required List<Map<String, dynamic>> categorias,
    required String alumnoId,
  }) {
    // 1. Filtrar las calificaciones del alumno
    final calificacionesAlumno = calificaciones
        .where((c) => c['alumno_id'] == alumnoId && c['nota_numerica'] != null)
        .toList();

    if (calificacionesAlumno.isEmpty) return null;

    // 2. Agrupar notas por categoria_id
    final Map<String, List<double>> notasPorCategoria = {};
    
    for (final calif in calificacionesAlumno) {
      final actId = calif['actividad_id'];
      // Buscar la actividad correspondiente para saber su categoria
      final act = actividades.firstWhere((a) => a['id'] == actId, orElse: () => {});
      if (act.isNotEmpty) {
        final rawTitulo = act['titulo']?.toString() ?? '';
        if (rawTitulo.startsWith('[INFO]') || rawTitulo.startsWith('[CONDUCTA]')) continue;

        final catId = act['categoria_id'];
        final nota = (calif['nota_numerica'] as num).toDouble();
        notasPorCategoria.putIfAbsent(catId, () => []).add(nota);
      }
    }

    if (notasPorCategoria.isEmpty) return null;

    double totalPonderado = 0.0;
    double totalPeso = 0.0;
    
    for (final cat in categorias) {
      final catId = cat['id'];
      final peso = (cat['peso_porcentaje'] as num).toDouble();
      final notas = notasPorCategoria[catId];
      if (notas != null && notas.isNotEmpty) {
        final promedioCat = notas.reduce((a, b) => a + b) / notas.length;
        totalPonderado += promedioCat * peso;
        totalPeso += peso;
      }
    }
    
    if (totalPeso == 0.0) return null;
    return totalPonderado / totalPeso;
  }

  /// Obtiene todos los datos para generar el Boletín Completo de Calificaciones y Seguimiento
  /// (todas las materias del curso, sus actividades, sus calificaciones y categorías)
  Future<Map<String, dynamic>> obtenerDatosBoletinCompleto({String? cursoId, List<String>? alumnosIds}) async {
    try {
      var queryMat = _client.from('acad_materias').select('materia_id, nombre_asignatura, curso_id');
      if (cursoId != null) {
        queryMat = queryMat.eq('curso_id', cursoId);
      }
      final materiasRes = await queryMat;
      final materias = List<Map<String, dynamic>>.from(materiasRes);

      if (materias.isEmpty) {
        return {
          'materias': [], 'actividades': [], 'calificaciones': [],
          'categorias': [], 'rubricas': [], 'cierres': [],
          'identificadorDivision': '', 'alumnosDemoData': <String, Map<String, dynamic>>{},
        };
      }

      final materiaIds = materias.map((m) => m['materia_id'] as String).toList();

      // Bug fix: restaurado materia_id en SELECT e inFilter para que catsMat no quede vacío
      final catRes = await _client
          .from('aca_categorias_nota')
          .select('id, materia_id, nombre, peso_porcentaje')
          .inFilter('materia_id', materiaIds);
      final categorias = List<Map<String, dynamic>>.from(catRes);

      final actRes = await _client
          .from('aca_actividades')
          .select('id, materia_id, categoria_id, titulo, fecha')
          .inFilter('materia_id', materiaIds);
      final actividades = List<Map<String, dynamic>>.from(actRes);

      List<Map<String, dynamic>> calificaciones = [];
      if (actividades.isNotEmpty) {
        final actIds = actividades.map((a) => a['id'] as String).toList();
        var queryCalif = _client
            .from('aca_calificaciones')
            .select('id, actividad_id, alumno_id, nota_numerica')
            .inFilter('actividad_id', actIds);
        if (alumnosIds != null && alumnosIds.isNotEmpty) {
          queryCalif = queryCalif.inFilter('alumno_id', alumnosIds);
        }
        final califRes = await queryCalif;
        calificaciones = List<Map<String, dynamic>>.from(califRes);
      }

      var queryRubricas = _client
          .from('aca_rubricas_cualitativas')
          .select('*')
          .inFilter('materia_id', materiaIds);
      if (alumnosIds != null && alumnosIds.isNotEmpty) {
        queryRubricas = queryRubricas.inFilter('alumno_id', alumnosIds);
      }
      final rubricas = List<Map<String, dynamic>>.from(await queryRubricas);

      var queryCierres = _client
          .from('aca_cierres_etapa')
          .select('*')
          .inFilter('materia_id', materiaIds);
      if (alumnosIds != null && alumnosIds.isNotEmpty) {
        queryCierres = queryCierres.inFilter('alumno_id', alumnosIds);
      }
      final cierres = List<Map<String, dynamic>>.from(await queryCierres);

      // Nombre del curso (ej. "1° ES")
      String identificadorDivision = '';
      if (cursoId != null) {
        try {
          final cur = await _client
              .from('acad_cursos')
              .select('identificador_division')
              .eq('curso_id', cursoId)
              .maybeSingle();
          identificadorDivision = cur?['identificador_division']?.toString() ?? '';
        } catch (_) {}
      }

      // DNI y datos demográficos de los alumnos
      final Map<String, Map<String, dynamic>> alumnosDemoData = {};
      if (alumnosIds != null && alumnosIds.isNotEmpty) {
        try {
          final demoRes = await _client
              .from('acad_inscripciones')
              .select('alumno_id, usr_legajo_alumno(datos_demograficos)')
              .inFilter('alumno_id', alumnosIds);
          for (final row in demoRes) {
            final aId = row['alumno_id']?.toString() ?? '';
            final legajo = row['usr_legajo_alumno'] as Map<String, dynamic>?;
            final demo = legajo?['datos_demograficos'] as Map<String, dynamic>?;
            if (aId.isNotEmpty && demo != null) {
              alumnosDemoData[aId] = demo;
            }
          }
        } catch (_) {}
      }

      return {
        'materias': materias,
        'actividades': actividades,
        'calificaciones': calificaciones,
        'categorias': categorias,
        'rubricas': rubricas,
        'cierres': cierres,
        'identificadorDivision': identificadorDivision,
        'alumnosDemoData': alumnosDemoData,
      };
    } catch (e) {
      print('Error al obtener datos del boletín completo: $e');
      return {
        'materias': [], 'actividades': [], 'calificaciones': [],
        'categorias': [], 'rubricas': [], 'cierres': [],
        'identificadorDivision': '', 'alumnosDemoData': <String, Map<String, dynamic>>{},
      };
    }
  }

  /// Obtiene las materias y cursos asignados a un docente mediante la tabla relacional
  Future<List<Map<String, dynamic>>> fetchMateriasPorDocente(String docenteId) async {
    final response = await _client
        .from('acad_docente_materia_curso')
        .select('''
          materia_id,
          curso_id,
          acad_materias (nombre_asignatura),
          acad_cursos (identificador_division)
        ''')
        .eq('docente_id', docenteId);
        
    final list = List<Map<String, dynamic>>.from(response);
    
    // Mapear el formato anidado de Supabase a un formato plano
    return list.map((item) {
      final materia = item['acad_materias'] as Map<String, dynamic>?;
      final curso = item['acad_cursos'] as Map<String, dynamic>?;
      return {
        'materia_id': item['materia_id'] as String,
        'curso_id': item['curso_id'] as String,
        'nombre_asignatura': (materia?['nombre_asignatura'] ?? 'Materia').toString(),
        'identificador_division': (curso?['identificador_division'] ?? 'Curso').toString(),
      };
    }).toList();
  }

  /// Crea un usuario via el RPC admin_create_user (requiere que la migración esté aplicada en Supabase).
  Future<String> adminCreateUser({
    required String email,
    required String password,
    required String rol,
    required String nombre,
    required String apellido,
    required String dni,
    String? cursoId,
  }) async {
    final response = await _client.rpc('admin_create_user', params: {
      'p_email': email,
      'p_password': password,
      'p_rol': rol,
      'p_nombre': nombre,
      'p_apellido': apellido,
      'p_dni': dni,
      'p_curso_id': cursoId,
    });
    return response.toString();
  }

  /// Actualiza los datos de un usuario mediante la Admin API
  Future<void> adminUpdateUser({
    required String userId,
    required String email,
    required String nombre,
    required String apellido,
    required String dni,
  }) async {
    // Intentar con RPC primero; si falla usar la función edge
    try {
      await _client.rpc('admin_update_user', params: {
        'p_user_id': userId,
        'p_email': email,
        'p_nombre': nombre,
        'p_apellido': apellido,
        'p_dni': dni,
      });
    } catch (_) {
      // Fallback: actualizar directamente los registros públicos
      await _client
          .from('usr_legajo_alumno')
          .update({
            'datos_demograficos': {
              'nombre': '$nombre $apellido',
              'nombre_pila': nombre,
              'apellido': apellido,
              'dni': dni,
            }
          })
          .eq('auth_id', userId);
    }
  }

  /// Elimina un usuario via el RPC admin_delete_user
  Future<void> adminDeleteUser(String userId) async {
    try {
      await _client.rpc('admin_delete_user', params: {'p_user_id': userId});
    } catch (_) {
      // Fallback: borrar registros públicos directamente
      await _client.from('usr_docentes').delete().eq('auth_id', userId);
      await _client.from('usr_legajo_alumno').delete().eq('auth_id', userId);
    }
  }

  /// Asocia un alumno al grupo familiar de un tutor
  Future<void> adminLinkStudentToFamily({
    required String studentLegajoId,
    required String familyGrupoId,
  }) async {
    await _client
        .from('usr_legajo_alumno')
        .update({'grupo_id': familyGrupoId})
        .eq('legajo_id', studentLegajoId);
  }

  /// Obtiene la lista de personal. Intenta con RPC, fallback a query directa.
  Future<List<Map<String, dynamic>>> fetchPersonalList() async {
    try {
      final response = await _client.rpc('get_personal_list');
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      // Fallback: query directa a usr_docentes (sin datos_demograficos, esa columna no existe)
      final response = await _client
          .from('usr_docentes')
          .select('docente_id, auth_id, ddjj_cargos');
      return List<Map<String, dynamic>>.from(response).map((d) {
        final cargos = d['ddjj_cargos'] as List? ?? [];
        final cargo = cargos.isNotEmpty ? (cargos.first['cargo'] ?? '') : '';
        return {
          'docente_id': d['docente_id'],
          'auth_id': d['auth_id'],
          'email': '',
          'nombre_completo': 'Personal ($cargo)',
          'ddjj_cargos': d['ddjj_cargos'],
        };
      }).toList();
    }
  }

  /// Obtiene la lista de alumnos. Intenta con RPC, fallback a query directa.
  Future<List<Map<String, dynamic>>> fetchAlumnosList() async {
    List<Map<String, dynamic>> lista = [];
    try {
      final response = await _client.rpc('get_alumnos_list');
      lista = List<Map<String, dynamic>>.from(response);
    } catch (_) {
      // Fallback: query directa
      final response = await _client
          .from('usr_legajo_alumno')
          .select('''
            legajo_id, auth_id, datos_demograficos, grupo_id, rol_financiero,
            acad_inscripciones(curso_id, estado, acad_cursos(identificador_division, curso_id))
          ''')
          .or('rol_financiero.is.null,rol_financiero.neq.RESPONSABLE_PAGO');
      lista = List<Map<String, dynamic>>.from(response).map((la) {
        final demo = la['datos_demograficos'] as Map? ?? {};
        final nombre = demo['nombre'] ?? '${demo['nombre_pila'] ?? ''} ${demo['apellido'] ?? ''}'.trim();
        final inscList = la['acad_inscripciones'] as List?;
        final insc = inscList?.firstWhere((i) => i['estado'] == 'ACTIVO', orElse: () => inscList!.isNotEmpty ? inscList.first : null) as Map?;
        final curso = insc?['acad_cursos'] as Map?;
        return {
          'legajo_id': la['legajo_id'],
          'auth_id': la['auth_id'],
          'email': '',
          'nombre_completo': nombre.isNotEmpty ? nombre : 'Sin Nombre',
          'dni': (demo['dni'] ?? '').toString(),
          'grupo_id': la['grupo_id'],
          'rol_financiero': la['rol_financiero'],
          'curso_nombre': curso?['identificador_division'] ?? 'Sin Curso',
          'curso_id': curso?['curso_id'] ?? insc?['curso_id'],
          'datos_demograficos': demo,
        };
      }).toList();
    }

    return lista.map((al) {
      final demo = Map<String, dynamic>.from(al['datos_demograficos'] as Map? ?? {});
      final hasAd = demo['adecuacion_curricular'] == true || demo['adecuacion_curricular'] == 'true' || al['adecuacion_curricular'] == true;
      return {
        ...al,
        'datos_demograficos': demo,
        'adecuacion_curricular': hasAd,
        'tipo_adecuacion': demo['tipo_adecuacion'] ?? al['tipo_adecuacion'] ?? 'Metodológica',
        'detalles_adecuacion': demo['detalles_adecuacion'] ?? al['detalles_adecuacion'] ?? '',
      };
    }).toList();
  }

  /// Obtiene la lista de tutores/padres. Intenta con RPC, fallback a query directa.
  Future<List<Map<String, dynamic>>> fetchTutoresList() async {
    try {
      final response = await _client.rpc('get_tutores_list');
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      // Fallback: query directa
      final response = await _client
          .from('usr_legajo_alumno')
          .select('''
            legajo_id, auth_id, datos_demograficos, grupo_id, rol_financiero,
            fin_grupos_familiares(nombre_grupo)
          ''')
          .eq('rol_financiero', 'RESPONSABLE_PAGO');
      return List<Map<String, dynamic>>.from(response).map((la) {
        final demo = la['datos_demograficos'] as Map? ?? {};
        final nombre = demo['nombre'] ?? '${demo['nombre_pila'] ?? ''} ${demo['apellido'] ?? ''}'.trim();
        final grupo = la['fin_grupos_familiares'] as Map?;
        return {
          'legajo_id': la['legajo_id'],
          'auth_id': la['auth_id'],
          'email': '',
          'nombre_completo': nombre.isNotEmpty ? nombre : 'Sin Nombre',
          'dni': (demo['dni'] ?? '').toString(),
          'grupo_id': la['grupo_id'],
          'rol_financiero': la['rol_financiero'],
          'grupo_nombre': grupo?['nombre_grupo'] ?? 'Sin Familia',
        };
      }).toList();
    }
  }

  /// Obtiene la lista de cursos
  Future<List<Map<String, dynamic>>> fetchCursos() async {
    final response = await _client
        .from('acad_cursos')
        .select('curso_id, identificador_division')
        .order('identificador_division', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtiene la lista de materias de un curso o todas
  Future<List<Map<String, dynamic>>> fetchMaterias({String? cursoId}) async {
    var query = _client.from('acad_materias').select('materia_id, nombre_asignatura, curso_id');
    if (cursoId != null) {
      query = query.eq('curso_id', cursoId);
    }
    final response = await query.order('nombre_asignatura', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtiene todos los grupos familiares
  Future<List<Map<String, dynamic>>> fetchGruposFamiliares() async {
    final response = await _client
        .from('fin_grupos_familiares')
        .select('grupo_id, nombre_grupo')
        .order('nombre_grupo', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Crea un curso
  Future<void> crearCurso(String nombreCurso) async {
    // Necesitamos sede_id y ciclo_id para acad_cursos
    // Busquemos una sede y ciclo existentes
    final sede = await _client.from('core_sedes').select('sede_id').limit(1).maybeSingle();
    final ciclo = await _client.from('core_ciclos_lectivos').select('ciclo_id').limit(1).maybeSingle();
    
    if (sede == null || ciclo == null) {
      throw Exception('Debe existir al menos una sede y un ciclo lectivo en la base de datos.');
    }
    
    await _client.from('acad_cursos').insert({
      'sede_id': sede['sede_id'],
      'ciclo_id': ciclo['ciclo_id'],
      'identificador_division': nombreCurso,
    });
  }

  /// Crea una materia
  Future<void> crearMateria({
    required String cursoId,
    required String nombreMateria,
    String? docenteId,
  }) async {
    await _client.from('acad_materias').insert({
      'curso_id': cursoId,
      'nombre_asignatura': nombreMateria,
      'docente_titular_id': docenteId,
    });
  }

  /// Vincula un docente con un curso y materia en acad_docente_materia_curso
  Future<void> asignarDocenteMateriaCurso({
    required String docenteId,
    required String materiaId,
    required String cursoId,
  }) async {
    // Primero, si ya tiene asignado el titular en acad_materias, lo actualizamos también
    await _client
        .from('acad_materias')
        .update({'docente_titular_id': docenteId})
        .eq('materia_id', materiaId);

    // Insertar en la tabla intermedia acad_docente_materia_curso
    await _client.from('acad_docente_materia_curso').insert({
      'docente_id': docenteId,
      'materia_id': materiaId,
      'curso_id': cursoId,
    });
  }

  /// Obtiene los detalles de asistencia para un alumno específico
  Future<List<Map<String, dynamic>>> obtenerAsistenciaAlumno(String alumnoId) async {
    final response = await _client
        .from('asistencia_detalle')
        .select('''
          asistencia_detalle_id, 
          valor_inasistencia, 
          tipo, 
          estado_justificacion, 
          asistencia_cabecera (fecha)
        ''')
        .eq('alumno_id', alumnoId);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtiene todas las calificaciones para un alumno específico
  Future<List<Map<String, dynamic>>> obtenerCalificacionesAlumno(String alumnoId) async {
    final response = await _client
        .from('aca_calificaciones')
        .select('''
          id,
          nota_numerica,
          actividad_id,
          aca_actividades (
            id,
            titulo,
            materia_id,
            categoria_id,
            aca_categorias_nota (
              id,
              nombre,
              peso_porcentaje
            )
          )
        ''')
        .eq('alumno_id', alumnoId);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtiene las calificaciones del alumno autenticado actual
  Future<List<Map<String, dynamic>>> obtenerMisCalificaciones() async {
    final response = await _client
        .from('aca_calificaciones')
        .select('''
          id,
          nota_numerica,
          actividad_id,
          aca_actividades (
            id,
            titulo,
            materia_id,
            categoria_id,
            aca_categorias_nota (
              id,
              nombre,
              peso_porcentaje
            )
          )
        ''');
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtiene los datos del alumno autenticado actual (nombre, apellido, dni, curso)
  Future<Map<String, dynamic>> obtenerMiPerfilAlumno() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    
    final response = await _client
        .from('usr_legajo_alumno')
        .select('legajo_id, datos_demograficos')
        .eq('auth_id', user.id)
        .single();
    
    final legajoId = response['legajo_id'] as String;
    final demo = response['datos_demograficos'] as Map<String, dynamic>? ?? {};
    final nombre = demo['nombre_pila'] ?? demo['nombre'] ?? '';
    final apellido = demo['apellido'] ?? '';
    final dni = demo['dni']?.toString() ?? '';

    // Obtener la inscripción activa del alumno
    final insc = await _client
        .from('acad_inscripciones')
        .select('curso_id, acad_cursos(identificador_division)')
        .eq('alumno_id', legajoId)
        .maybeSingle();

    final curso = insc?['acad_cursos'] as Map<String, dynamic>?;
    final cursoId = insc?['curso_id'] as String?;

    return {
      'alumno_id': legajoId,
      'nombre_completo': '$nombre $apellido'.trim().isEmpty ? 'Alumno' : '$nombre $apellido'.trim(),
      'dni': dni,
      'curso_id': cursoId ?? '',
      'curso_name': (curso?['identificador_division'] ?? 'Sin curso').toString(),
    };
  }

  /// Obtiene la lista de hijos vinculados al grupo_id del tutor actual
  Future<List<Map<String, dynamic>>> obtenerHijosTutor() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      // 1. Obtener el grupo_id del tutor autenticado actual
      final tutorData = await _client
          .from('usr_legajo_alumno')
          .select('grupo_id')
          .eq('auth_id', user.id)
          .eq('rol_financiero', 'RESPONSABLE_PAGO')
          .maybeSingle();

      if (tutorData == null || tutorData['grupo_id'] == null) {
        return [];
      }

      final grupoId = tutorData['grupo_id'] as String;

      // 2. Obtener los alumnos (hijos) vinculados a ese grupo_id
      final hijosResponse = await _client
          .from('usr_legajo_alumno')
          .select('''
            legajo_id,
            datos_demograficos,
            acad_inscripciones (
              curso_id,
              acad_cursos (
                identificador_division
              )
            )
          ''')
          .eq('grupo_id', grupoId)
          .neq('rol_financiero', 'RESPONSABLE_PAGO');

      final list = List<Map<String, dynamic>>.from(hijosResponse);
      return list.map((hijo) {
        final inscList = hijo['acad_inscripciones'] as List?;
        final insc = (inscList != null && inscList.isNotEmpty) ? inscList.first as Map<String, dynamic> : null;
        final curso = insc?['acad_cursos'] as Map<String, dynamic>?;
        final cursoId = insc?['curso_id'] as String?;
        final demo = hijo['datos_demograficos'] as Map<String, dynamic>? ?? {};
        final nombre = demo['nombre_pila'] ?? demo['nombre'] ?? '';
        final apellido = demo['apellido'] ?? '';
        final dni = demo['dni']?.toString() ?? '';
        return {
          'legajo_id': hijo['legajo_id'] as String,
          'nombre_completo': '$nombre $apellido'.trim().isEmpty ? 'Alumno sin nombre' : '$nombre $apellido'.trim(),
          'dni': dni,
          'curso_id': cursoId ?? '',
          'curso_name': (curso?['identificador_division'] ?? 'Sin curso').toString(),
        };
      }).toList();
    } catch (e) {
      print('Error al obtener hijos: $e');
      return [];
    }
  }

  /// Obtiene los registros de conducta para un alumno
  Future<List<Map<String, dynamic>>> obtenerConductaAlumno(String alumnoId) async {
    try {
      final response = await _client
          .from('aca_conducta')
          .select('*')
          .eq('alumno_id', alumnoId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Obtiene las materias adeudadas de un alumno
  Future<List<Map<String, dynamic>>> obtenerMateriasAdeudadasAlumno(String alumnoId) async {
    try {
      return await obtenerMateriasAdeudadas(alumnoId);
    } catch (e) {
      return [];
    }
  }

  /// Envía un comunicado masivo a los alumnos y tutores de un curso (o toda la escuela si cursoId es null)
  Future<void> enviarMensajeMasivo({
    required String asunto,
    required String texto,
    required bool requiereFirma,
    String? cursoId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // 1. Insertar el mensaje
    final msg = await _client.from('com_mensajes').insert({
      'emisor_id': user.id,
      'asunto': asunto,
      'cuerpo': {'texto': texto},
      'requiere_firma': requiereFirma,
    }).select('mensaje_id').single();

    final mensajeId = msg['mensaje_id'] as String;

    // 2. Buscar destinatarios
    List<String> targetAuthIds = [];

    if (cursoId != null && cursoId.isNotEmpty) {
      // Alumnos inscritos en el curso
      final enrollments = await _client
          .from('acad_inscripciones')
          .select('alumno_id, usr_legajo_alumno(auth_id, grupo_id)')
          .eq('curso_id', cursoId);

      for (final ins in enrollments) {
        final alumno = ins['usr_legajo_alumno'] as Map<String, dynamic>?;
        if (alumno != null) {
          final studentAuth = alumno['auth_id'] as String?;
          if (studentAuth != null) targetAuthIds.add(studentAuth);

          final grupoId = alumno['grupo_id'] as String?;
          if (grupoId != null) {
            // Padres de la familia
            final parents = await _client
                .from('usr_legajo_alumno')
                .select('auth_id')
                .eq('grupo_id', grupoId)
                .eq('rol_financiero', 'RESPONSABLE_PAGO');
            
            for (final p in parents) {
              final parentAuth = p['auth_id'] as String?;
              if (parentAuth != null) targetAuthIds.add(parentAuth);
            }
          }
        }
      }
    } else {
      // Toda la escuela: todos los usuarios de usr_legajo_alumno (alumnos y padres) y usr_docentes
      final allLegajos = await _client.from('usr_legajo_alumno').select('auth_id');
      final allDocentes = await _client.from('usr_docentes').select('auth_id');

      for (final row in allLegajos) {
        final authId = row['auth_id'] as String?;
        if (authId != null) targetAuthIds.add(authId);
      }
      for (final row in allDocentes) {
        final authId = row['auth_id'] as String?;
        if (authId != null) targetAuthIds.add(authId);
      }
    }

    final uniqueAuthIds = targetAuthIds.toSet().toList();

    // 3. Crear registros en com_destinatarios en lotes (bulk insert)
    if (uniqueAuthIds.isNotEmpty) {
      final dests = uniqueAuthIds.map((authId) {
        return {
          'mensaje_id': mensajeId,
          'usuario_id': authId,
          'emisor_id': user.id,
          'fecha_lectura': null,
          'archivado': false,
        };
      }).toList();

      await _client.from('com_destinatarios').insert(dests);
    }
  }

  /// Obtiene los eventos de calendario de la escuela (curso_id es null) o específicos para el curso_id del alumno.
  /// Si [soloPublicos] es true, filtra eventos marcados como internos ([INTERNO]) o exclusivos de docentes/personal.
  Future<List<Map<String, dynamic>>> obtenerCalendarioPorCurso(String? cursoId, {bool soloPublicos = true, String? materiaId}) async {
    try {
      dynamic query = _client.from('acad_calendario').select('*');
      if (cursoId != null && cursoId.isNotEmpty) {
        // Traer eventos generales (null) o del curso específico
        query = query.or('curso_id.eq.$cursoId,curso_id.is.null');
      } else {
        query = query.isFilter('curso_id', null);
      }
      final response = await query.order('fecha', ascending: true);
      var lista = List<Map<String, dynamic>>.from(response);

      // Si se pide una materia puntual: sólo sus eventos + los del curso que no
      // están atados a otra materia (reuniones/actividades generales del curso).
      // Nunca los TEMARIO (van al Libro de Temas, no a "Fechas Importantes").
      if (materiaId != null && materiaId.isNotEmpty) {
        lista = lista.where((ev) {
          final tipo = (ev['tipo_evento'] ?? '').toString().toUpperCase();
          if (tipo == 'TEMARIO') return false;
          final evMateria = ev['materia_id']?.toString();
          if (evMateria != null && evMateria.isNotEmpty) return evMateria == materiaId;
          return true; // sin materia: evento a nivel curso/escuela
        }).toList();
      }

      if (soloPublicos) {
        return lista.where((ev) {
          final titulo = (ev['titulo'] ?? '').toString().toLowerCase();
          final desc = (ev['descripcion'] ?? '').toString().toLowerCase();
          final visibilidad = (ev['visibilidad'] ?? ev['alcance'] ?? '').toString().toUpperCase();
          if (visibilidad == 'INTERNO' || visibilidad == 'INTERNO_DOCENTE' || visibilidad == 'SOLO_PERSONAL') return false;
          if (titulo.contains('[interno]') || desc.contains('[interno]')) return false;
          if (titulo.contains('reunión de profes') || titulo.contains('reunion de profes') ||
              titulo.contains('reunión docente') || titulo.contains('reunion docente') ||
              titulo.contains('reunión de personal') || titulo.contains('reunion de personal') ||
              titulo.contains('capacitación docente') || titulo.contains('capacitacion docente') ||
              titulo.contains('capacitación institucional') || titulo.contains('jornada docente') ||
              titulo.contains('consejo consultivo')) {
            return false;
          }
          return true;
        }).toList();
      }

      return lista;
    } catch (e) {
      print('Error al obtener calendario: $e');
      return [];
    }
  }

  /// Obtiene todos los eventos de calendario de la institución (para panel docente/preceptor/admin)
  Future<List<Map<String, dynamic>>> obtenerTodosLosEventosCalendario() async {
    try {
      final response = await _client.from('acad_calendario').select('*').order('fecha', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener todos los eventos de calendario: $e');
      return [];
    }
  }

  /// Crea un nuevo evento de calendario y envía notificaciones opcionales.
  Future<void> crearEventoCalendario({
    required String titulo,
    required String descripcion,
    required String fecha,
    required String tipoEvento,
    String? cursoId,
    String? materiaId,
    bool esInterno = false,
    bool notificarPadres = false,
    bool notificarDocentes = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final finalTitulo = esInterno && !titulo.startsWith('[INTERNO]') ? '[INTERNO] $titulo' : titulo;
    final finalDesc = esInterno && !descripcion.startsWith('[INTERNO]') ? '[INTERNO] $descripcion' : descripcion;

    // Se firma el evento con su autor: de eso depende quien puede despues
    // modificarlo o borrarlo.
    String? docenteId;
    try {
      docenteId = await obtenerDocenteIdActual();
    } catch (_) {
      docenteId = null;
    }

    final base = <String, dynamic>{
      'titulo': finalTitulo,
      'descripcion': finalDesc,
      'fecha': fecha,
      'tipo_evento': tipoEvento,
      'curso_id': (cursoId != null && cursoId.isNotEmpty) ? cursoId : null,
      'materia_id': (materiaId != null && materiaId.isNotEmpty) ? materiaId : null,
      'creado_por': user.id,
      'docente_id': docenteId,
    };

    try {
      await _client.from('acad_calendario').insert(base);
    } catch (e) {
      String dbTipo = tipoEvento.toUpperCase();
      if (dbTipo.contains('EVALUAC')) {
        dbTipo = 'EVALUACION';
      } else if (dbTipo.contains('REUNI')) {
        dbTipo = 'REUNION';
      } else {
        dbTipo = 'ACTIVIDAD';
      }

      final conCategoria = <String, dynamic>{
        ...base,
        'descripcion': '$finalDesc [Cat: $tipoEvento]',
        'tipo_evento': dbTipo,
      };

      try {
        await _client.from('acad_calendario').insert(conCategoria);
      } catch (_) {
        // Respaldo por si la migración de autoría/materia todavía no se aplicó:
        // se reintenta sin las columnas nuevas.
        final minimo = Map<String, dynamic>.from(conCategoria)
          ..remove('creado_por')
          ..remove('docente_id')
          ..remove('materia_id');
        await _client.from('acad_calendario').insert(minimo);
      }
    }

    // ── Notificaciones ───────────────────────────────────────────────
    final asunto = 'Nuevo evento escolar: $titulo ($fecha)';
    final texto = 'Se agendó "$titulo" para el $fecha.${descripcion.isNotEmpty ? " $descripcion" : ""}';

    // Siempre notificar a Administración
    obtenerAuthIdsAdministracion().then((adminIds) {
      notificarSistema(asunto: asunto, texto: texto, destinatariosAuthIds: adminIds);
    });

    if (notificarPadres || notificarDocentes) {
      obtenerAuthIdsEventoDestinatarios(cursoId: cursoId, incluirPadres: notificarPadres, incluirDocentes: notificarDocentes).then((ids) {
        if (ids.isNotEmpty) {
          notificarSistema(asunto: asunto, texto: texto, destinatariosAuthIds: ids);
        }
      });
    }
  }

  /// Modifica un evento del calendario. La política de acad_calendario sólo
  /// deja pasar la operación si el evento es del docente autenticado (o si es
  /// personal directivo), así que un intento ajeno vuelve como error.
  Future<void> actualizarEventoCalendario({
    required String eventoId,
    String? titulo,
    String? descripcion,
    String? fecha,
    String? tipoEvento,
  }) async {
    final cambios = <String, dynamic>{};
    if (titulo != null) cambios['titulo'] = titulo;
    if (descripcion != null) cambios['descripcion'] = descripcion;
    if (fecha != null) cambios['fecha'] = fecha;
    if (tipoEvento != null) cambios['tipo_evento'] = tipoEvento;
    if (cambios.isEmpty) return;

    final res = await _client
        .from('acad_calendario')
        .update(cambios)
        .eq('evento_id', eventoId)
        .select('evento_id');

    if ((res as List).isEmpty) {
      throw Exception(
          'No se pudo modificar: sólo puede hacerlo quien creó el evento o la dirección.');
    }
  }

  /// Elimina un evento del calendario, con la misma regla de autoría.
  Future<void> eliminarEventoCalendario(String eventoId) async {
    final res = await _client
        .from('acad_calendario')
        .delete()
        .eq('evento_id', eventoId)
        .select('evento_id');

    if ((res as List).isEmpty) {
      // Distinguir "ya no existe" de "sin permiso" para no confundir al usuario.
      final sigueExistiendo = await _client
          .from('acad_calendario')
          .select('evento_id')
          .eq('evento_id', eventoId)
          .maybeSingle();
      if (sigueExistiendo == null) return; // ya estaba borrado: se considera OK
      throw Exception(
          'No se pudo eliminar: sólo puede hacerlo quien creó el evento o la dirección.');
    }
  }

  /// ¿El usuario actual puede modificar o borrar este evento?
  ///
  /// Refleja la política de la base para no ofrecer botones que después van a
  /// fallar: el autor, o —en los eventos heredados que no tienen autor— un
  /// docente que dicte en ese curso. [cursosDelDocente] son los curso_id que
  /// tiene asignados quien está mirando.
  bool puedeEditarEvento(
    Map<String, dynamic> evento, {
    Iterable<String> cursosDelDocente = const [],
  }) {
    final user = _client.auth.currentUser;
    final uid = user?.id;
    if (uid == null) return false;

    // Dirección / preceptoría pueden tocar cualquier evento (la política RLS
    // lo permite vía es_personal_directivo()).
    final rol = user?.userMetadata?['rol'] as String?;
    if (rol == 'ADMIN' || rol == 'PRECEPTOR') return true;

    final autor = evento['creado_por']?.toString();
    if (autor != null && autor.isNotEmpty) return autor == uid;

    final cursoId = evento['curso_id']?.toString();
    if (cursoId == null || cursoId.isEmpty) return false;
    return cursosDelDocente.contains(cursoId);
  }

  /// Obtiene auth_ids de padres y/o docentes para notificar eventos de calendario.
  Future<List<String>> obtenerAuthIdsEventoDestinatarios({
    String? cursoId,
    bool incluirPadres = false,
    bool incluirDocentes = false,
  }) async {
    final Set<String> ids = {};
    try {
      if (incluirPadres) {
        if (cursoId != null && cursoId.isNotEmpty) {
          // Padres de alumnos inscriptos en el curso
          final inscs = await _client
              .from('acad_inscripciones')
              .select('alumno_id, usr_legajo_alumno(auth_id, grupo_id)')
              .eq('curso_id', cursoId);
          for (final ins in inscs) {
            final alumno = ins['usr_legajo_alumno'] as Map<String, dynamic>?;
            if (alumno == null) continue;
            final grupoId = alumno['grupo_id'] as String?;
            if (grupoId != null) {
              final padres = await _client
                  .from('usr_legajo_alumno')
                  .select('auth_id')
                  .eq('grupo_id', grupoId)
                  .eq('rol_financiero', 'RESPONSABLE_PAGO');
              for (final p in padres) {
                final id = p['auth_id'] as String?;
                if (id != null && id.isNotEmpty) ids.add(id);
              }
            }
          }
        } else {
          // Todos los padres de la escuela
          final todos = await _client
              .from('usr_legajo_alumno')
              .select('auth_id')
              .eq('rol_financiero', 'RESPONSABLE_PAGO');
          for (final p in todos) {
            final id = p['auth_id'] as String?;
            if (id != null && id.isNotEmpty) ids.add(id);
          }
        }
      }

      if (incluirDocentes) {
        final docentes = await _client.from('usr_docentes').select('auth_id');
        for (final d in docentes) {
          final id = d['auth_id'] as String?;
          if (id != null && id.isNotEmpty) ids.add(id);
        }
      }
    } catch (e) {
      print('Error al obtener destinatarios de evento: $e');
    }
    return ids.toList();
  }

  /// Obtiene la lista de docentes y directivos disponibles para que un tutor inicie una conversación
  Future<List<Map<String, dynamic>>> obtenerDestinatariosTutor() async {
    final List<Map<String, dynamic>> destinatariosFijos = [
      {'auth_id': 'admin-maria-funes', 'nombre': 'María Funes', 'rol': 'Directora Institucional'},
      {'auth_id': 'sec-admin', 'nombre': 'Secretaría Institucional y Administración', 'rol': 'Administración / Cobranzas'},
      {'auth_id': 'eoe-equipo', 'nombre': 'Equipo de Orientación Escolar (EOE)', 'rol': 'Orientación Psicopedagógica'},
      {'auth_id': 'prec-martin', 'nombre': 'Preceptor Martín (1° ES / 2° ES)', 'rol': 'Preceptoría'},
      {'auth_id': 'prec-clara', 'nombre': 'Preceptora Clara (3° ES / Ciclo Superior)', 'rol': 'Preceptoría'},
      {'auth_id': 'doc-danilo', 'nombre': 'Prof. Danilo Gómez', 'rol': 'Docente - Matemática (1° ES)'},
      {'auth_id': 'doc-laura', 'nombre': 'Prof. Laura Martínez', 'rol': 'Docente - Ciencias Naturales (1° ES)'},
      {'auth_id': 'doc-jessica', 'nombre': 'Prof. Jessica Romero', 'rol': 'Docente - Prácticas del Lenguaje / Literatura'},
      {'auth_id': 'doc-julio', 'nombre': 'Prof. Julio Lesson', 'rol': 'Docente - Educación Física'},
      {'auth_id': 'doc-florencia', 'nombre': 'Prof. Florencia Viera', 'rol': 'Docente - Matemática / Taller'},
      {'auth_id': 'doc-carlos', 'nombre': 'Prof. Carlos Ruiz', 'rol': 'Docente - Ciencias Sociales / Historia'},
      {'auth_id': 'doc-ciudadania', 'nombre': 'Prof. María Funes', 'rol': 'Docente - Construcción de la Ciudadanía'},
      {'auth_id': 'doc-daniel', 'nombre': 'Prof. Daniel Gómez', 'rol': 'Docente - Historia Sagrada / TIC'},
    ];

    try {
      final response = await _client
          .from('usr_docentes')
          .select('auth_id, datos_demograficos, ddjj_cargos');
      
      final list = List<Map<String, dynamic>>.from(response);
      final Set<String> idsAgregados = destinatariosFijos.map((d) => d['auth_id'] as String).toSet();
      final List<Map<String, dynamic>> result = [...destinatariosFijos];

      for (final doc in list) {
        final authId = doc['auth_id'] as String?;
        if (authId == null || idsAgregados.contains(authId)) continue;

        final demo = doc['datos_demograficos'] as Map<String, dynamic>?;
        final nombre = '${demo?['nombre'] ?? 'Personal'} ${demo?['apellido'] ?? ''}'.trim();
        final cargos = doc['ddjj_cargos']?.toString() ?? '';
        
        String rolDisplay = 'Personal';
        if (cargos.contains('ADMIN') || cargos.contains('DIRECTIVO')) {
          rolDisplay = 'Equipo Directivo';
        } else if (cargos.contains('PRECEPTOR')) {
          rolDisplay = 'Preceptor';
        } else if (cargos.contains('DOCENTE')) {
          rolDisplay = 'Docente';
        }

        result.add({
          'auth_id': authId,
          'nombre': nombre,
          'rol': rolDisplay,
        });
        idsAgregados.add(authId);
      }
      return result;
    } catch (e) {
      print('Error o fallback al obtener destinatarios en Supabase: $e');
      return destinatariosFijos;
    }
  }

  /// Envía un mensaje personal iniciado por el tutor a un miembro del personal
  Future<void> enviarMensajePersonal({
    required String destinatarioAuthId,
    required String asunto,
    required String texto,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // 1. Insertar el mensaje
    final msg = await _client.from('com_mensajes').insert({
      'emisor_id': user.id,
      'asunto': asunto,
      'cuerpo': {'texto': texto},
      'requiere_firma': false,
    }).select('mensaje_id').single();

    final mensajeId = msg['mensaje_id'] as String;

    // 2. Insertar destinatario
    await _client.from('com_destinatarios').insert({
      'mensaje_id': mensajeId,
      'usuario_id': destinatarioAuthId,
      'emisor_id': user.id,
      'fecha_lectura': null,
      'archivado': false,
    });
  }

  /// Envía una notificación automática del sistema a Administración o Directivos
  Future<void> notificarSistema({
    required String asunto,
    required String texto,
    required List<String> destinatariosAuthIds,
    bool requiereFirma = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final msg = await _client.from('com_mensajes').insert({
        'emisor_id': user.id,
        'asunto': asunto,
        'cuerpo': {'texto': texto},
        'requiere_firma': requiereFirma,
      }).select('mensaje_id').single();

      final mensajeId = msg['mensaje_id'] as String;

      final idsUnicos = destinatariosAuthIds.toSet().where((id) => id.isNotEmpty).toList();
      if (idsUnicos.isNotEmpty) {
        final dests = idsUnicos.map((id) => {
          'mensaje_id': mensajeId,
          'usuario_id': id,
          'emisor_id': user.id,
          'fecha_lectura': null,
          'archivado': false,
        }).toList();

        await _client.from('com_destinatarios').insert(dests);
      }
    } catch (e) {
      print('Error en notificarSistema: $e');
    }
  }

  /// Obtiene los IDs de administración, dirección y preceptoría para notificaciones y alertas
  Future<List<String>> obtenerAuthIdsAdministracion() async {
    final List<String> ids = ['sec-admin', 'admin-maria-funes', 'prec-martin', 'prec-clara'];
    try {
      final res = await _client.from('usr_docentes').select('auth_id, ddjj_cargos');
      for (var r in res) {
        final authId = r['auth_id']?.toString() ?? '';
        final cargos = r['ddjj_cargos']?.toString().toUpperCase() ?? '';
        if (authId.isNotEmpty && (cargos.contains('ADMIN') || cargos.contains('DIRECT') || cargos.contains('PRECEPTOR') || authId.contains('admin') || authId.contains('sec-'))) {
          ids.add(authId);
        }
      }
    } catch (e) {
      print('Fallback al obtener IDs de administración: $e');
    }
    return ids.toSet().toList();
  }

  /// Envía un comunicado grupal al Cuaderno Digital para los roles/grupos seleccionados en el calendario
  Future<void> enviarComunicadoGrupal({
    required String asunto,
    required String texto,
    required List<String> destinatariosRoles,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Insertar el mensaje
      final msg = await _client.from('com_mensajes').insert({
        'emisor_id': user.id,
        'asunto': asunto,
        'cuerpo': {'texto': texto},
        'requiere_firma': false,
      }).select('mensaje_id').single();

      final mensajeId = msg['mensaje_id'] as String;
      Set<String> authIds = {};

      // Siempre incluir al emisor
      authIds.add(user.id);

      // 2. Traer auth_id según roles seleccionados
      if (destinatariosRoles.contains('Todos los Docentes')) {
        final res = await _client.from('usr_docentes').select('auth_id');
        for (var r in res) {
          if (r['auth_id'] != null) authIds.add(r['auth_id'].toString());
        }
      }
      if (destinatariosRoles.contains('Preceptores / Administrativos')) {
        // El rol del personal se guarda en usr_docentes.ddjj_cargos
        final res = await _client.from('usr_docentes').select('auth_id, ddjj_cargos');
        for (var r in res) {
          final cargos = r['ddjj_cargos']?.toString().toUpperCase() ?? '';
          if (r['auth_id'] != null &&
              (cargos.contains('PRECEPTOR') || cargos.contains('ADMIN') || cargos.contains('DIRECT'))) {
            authIds.add(r['auth_id'].toString());
          }
        }
      }
      if (destinatariosRoles.contains('Alumnos de 1° SEC') || destinatariosRoles.contains('Alumnos de 2° SEC') || destinatariosRoles.contains('Familias / Tutores')) {
        final res = await _client.from('usr_legajo_alumno').select('auth_id');
        for (var r in res) {
          if (r['auth_id'] != null) authIds.add(r['auth_id'].toString());
        }
      }

      // 3. Insertar en com_destinatarios para cada authId
      final listaInsert = authIds.map((id) => {
        'mensaje_id': mensajeId,
        'usuario_id': id,
        'emisor_id': user.id,
        'fecha_lectura': null,
        'archivado': false,
      }).toList();

      if (listaInsert.isNotEmpty) {
        await _client.from('com_destinatarios').insert(listaInsert);
      }
    } catch (e) {
      print('Error al enviar comunicado grupal: $e');
    }
  }

  /// Obtiene las incidencias de conducta recientes para el dashboard del preceptor
  Future<List<Map<String, dynamic>>> obtenerRecientesIncidencias() async {
    try {
      final response = await _client
          .from('aca_conducta')
          .select('''
            id,
            tipo_incidencia,
            severidad,
            descripcion,
            usr_legajo_alumno (
              datos_demograficos
            )
          ''')
          .limit(10);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener incidencias recientes: $e');
      return [];
    }
  }

  /// Obtiene la lista completa de todas las incidencias de conducta con sus alumnos y cursos
  Future<List<Map<String, dynamic>>> obtenerTodasIncidencias() async {
    try {
      final response = await _client
          .from('aca_conducta')
          .select('''
            id,
            tipo_incidencia,
            severidad,
            descripcion,
            fecha,
            estado,
            accion_tomada,
            usr_legajo_alumno (
              legajo_id,
              datos_demograficos,
              acad_inscripciones (
                curso_id,
                acad_cursos (
                  identificador_division
                )
              )
            )
          ''')
          .order('fecha', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener historial de conducta: $e');
      return [];
    }
  }

  /// Obtiene el historial de conducta de un alumno específico
  Future<List<Map<String, dynamic>>> obtenerHistorialConductaAlumno(String alumnoId) async {
    try {
      final response = await _client
          .from('aca_conducta')
          .select('''
            id,
            tipo_incidencia,
            severidad,
            descripcion,
            fecha,
            usr_legajo_alumno (
              legajo_id,
              datos_demograficos,
              acad_inscripciones (
                curso_id,
                acad_cursos (
                  identificador_division
                )
              )
            )
          ''')
          .eq('alumno_id', alumnoId)
          .order('fecha', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener historial de conducta: $e');
      return [];
    }
  }

  /// Obtiene los registros de conducta diaria filtrados por curso y mes
  Future<List<Map<String, dynamic>>> obtenerConductaMensualCurso(String cursoId) async {
    try {
      final response = await _client
          .from('aca_conducta')
          .select('''
            alumno_id,
            tipo_incidencia,
            descripcion,
            fecha,
            usr_legajo_alumno (
              legajo_id,
              datos_demograficos,
              acad_inscripciones (
                curso_id
              )
            )
          ''');

      final List<Map<String, dynamic>> results = [];
      for (final item in response) {
        final alumno = item['usr_legajo_alumno'] as Map<String, dynamic>?;
        if (alumno == null) continue;
        final inscs = alumno['acad_inscripciones'] as List<dynamic>?;
        if (inscs == null || inscs.isEmpty) continue;
        final inCurso = inscs.any((ins) => ins['curso_id'] == cursoId);
        if (!inCurso) continue;

        final tipo = item['tipo_incidencia'] as String? ?? '';
        final desc = item['descripcion'] as String? ?? '';
        if (tipo == 'Bien' || tipo == 'Regular' || tipo == 'Mal' || tipo == 'Más o menos' || desc.contains('Conducta diaria:')) {
          results.add({
            'alumno_id': item['alumno_id'],
            'tipo_incidencia': tipo == 'Más o menos' ? 'Regular' : tipo,
            'descripcion': desc,
            'fecha': item['fecha'],
          });
        }
      }
      return results;
    } catch (e) {
      print('Error al obtener conducta mensual: $e');
      return [];
    }
  }

  /// Resumen REAL de asistencia del día para toda la escuela.
  /// Usa las planillas del preceptor (PRECEPTOR_DIARIA), que son la toma
  /// oficial diaria. Devuelve conteos + cobertura (cuántos cursos tomaron lista).
  Future<Map<String, dynamic>> obtenerResumenAsistenciaHoy() async {
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final cabs = await _client
          .from('asistencia_cabecera')
          .select('asistencia_cabecera_id, curso_id')
          .eq('fecha', hoy)
          .eq('tipo_asistencia', 'PRECEPTOR_DIARIA');

      final ids = List<Map<String, dynamic>>.from(cabs)
          .map((c) => c['asistencia_cabecera_id'] as String)
          .toList();
      final cursos = List<Map<String, dynamic>>.from(cabs)
          .map((c) => c['curso_id'])
          .toSet();

      int presentes = 0, ausentes = 0, tardes = 0, retiros = 0;
      if (ids.isNotEmpty) {
        final dets = await _client
            .from('asistencia_detalle')
            .select('tipo')
            .inFilter('asistencia_cabecera_id', ids);
        for (final d in dets) {
          switch ((d['tipo'] ?? '').toString().toUpperCase()) {
            case 'PRESENTE':
              presentes++;
              break;
            case 'AUSENTE':
              ausentes++;
              break;
            case 'TARDE':
              tardes++;
              break;
            case 'RETIRO_ANTICIPADO':
            case 'RETIRO':
              retiros++;
              break;
          }
        }
      }

      final totalCursos = await _client.from('acad_cursos').select('curso_id');
      return {
        'presentes': presentes,
        'ausentes': ausentes,
        'tardes': tardes,
        'retiros': retiros,
        'cursos_con_lista': cursos.length,
        'cursos_total': (totalCursos as List).length,
        'fecha': hoy,
      };
    } catch (e) {
      print('Error al obtener resumen de asistencia de hoy: $e');
      return {
        'presentes': 0, 'ausentes': 0, 'tardes': 0, 'retiros': 0,
        'cursos_con_lista': 0, 'cursos_total': 0, 'fecha': hoy,
      };
    }
  }

  /// Faltas acumuladas del mes por alumno, para TODA la escuela.
  /// [mes] 1-12, [anio] opcional (por defecto el año actual).
  /// Devuelve `[{alumno_id, nombre, curso, ausentes, tardes, retiros, faltas}]`
  /// ordenado por faltas desc. Ausente=1, Tarde=0.25, Retiro=0.5.
  Future<List<Map<String, dynamic>>> obtenerFaltasMensualesEscuela({
    required int mes,
    int? anio,
  }) async {
    final y = anio ?? DateTime.now().year;
    final desde = DateTime(y, mes, 1).toIso8601String().substring(0, 10);
    final hasta = DateTime(y, mes + 1, 1).toIso8601String().substring(0, 10);
    try {
      final cabs = await _client
          .from('asistencia_cabecera')
          .select('asistencia_cabecera_id, curso_id')
          .eq('tipo_asistencia', 'PRECEPTOR_DIARIA')
          .gte('fecha', desde)
          .lt('fecha', hasta);
      final cabList = List<Map<String, dynamic>>.from(cabs);
      if (cabList.isEmpty) return [];

      final cursoDeCab = {
        for (final c in cabList) c['asistencia_cabecera_id'] as String: c['curso_id']
      };
      final dets = await _client
          .from('asistencia_detalle')
          .select('alumno_id, tipo, asistencia_cabecera_id')
          .inFilter('asistencia_cabecera_id', cabList.map((c) => c['asistencia_cabecera_id'] as String).toList());

      final alumnos = await fetchAlumnosList();
      final infoAlumno = {
        for (final a in alumnos)
          a['legajo_id'].toString(): {
            'nombre': a['nombre_completo'],
            'curso': a['curso_nombre'],
          }
      };

      final acc = <String, Map<String, dynamic>>{};
      for (final d in dets) {
        final aid = d['alumno_id'].toString();
        final e = acc.putIfAbsent(aid, () => {
              'alumno_id': aid,
              'nombre': infoAlumno[aid]?['nombre'] ?? 'Alumno',
              'curso': infoAlumno[aid]?['curso'] ??
                  cursoDeCab[d['asistencia_cabecera_id']]?.toString() ??
                  '—',
              'ausentes': 0,
              'tardes': 0,
              'retiros': 0,
            });
        switch ((d['tipo'] ?? '').toString().toUpperCase()) {
          case 'AUSENTE':
            e['ausentes'] = (e['ausentes'] as int) + 1;
            break;
          case 'TARDE':
            e['tardes'] = (e['tardes'] as int) + 1;
            break;
          case 'RETIRO_ANTICIPADO':
          case 'RETIRO':
            e['retiros'] = (e['retiros'] as int) + 1;
            break;
        }
      }

      final list = acc.values.map((e) {
        final f = (e['ausentes'] as int) +
            (e['tardes'] as int) * 0.25 +
            (e['retiros'] as int) * 0.5;
        return {...e, 'faltas': f};
      }).where((e) => (e['faltas'] as double) > 0).toList()
        ..sort((a, b) => (b['faltas'] as double).compareTo(a['faltas'] as double));
      return list;
    } catch (e) {
      print('Error al obtener faltas mensuales de la escuela: $e');
      return [];
    }
  }

  /// Registra el temario dictado usando la tabla acad_calendario con un tipo especial.
  /// Requiere haber aplicado temarios_migration.sql (habilita tipo_evento='TEMARIO'
  /// y la columna materia_id). Si la columna todavía no existe, reintenta sin ella.
  Future<void> registrarTemario({
    required String cursoId,
    required String materiaId,
    required String materiaNombre,
    required String tema,
    required String fecha,
  }) async {
    final base = <String, dynamic>{
      'titulo': materiaNombre,
      'descripcion': tema,
      'fecha': fecha,
      'tipo_evento': 'TEMARIO',
      'curso_id': cursoId,
    };
    try {
      await _client.from('acad_calendario').insert({...base, 'materia_id': materiaId});
    } catch (e) {
      // Sólo se reintenta si la base todavía no tiene la columna materia_id.
      // Cualquier otro error (por ejemplo, un temario duplicado para esa fecha)
      // se propaga para que la pantalla lo muestre en vez de guardar de más.
      final msg = e.toString().toLowerCase();
      final faltaColumna = msg.contains('materia_id') &&
          (msg.contains('column') || msg.contains('columna') || msg.contains('schema cache'));
      if (!faltaColumna) rethrow;
      await _client.from('acad_calendario').insert(base);
    }
  }

  /// Actualiza un temario ya cargado (por su evento_id)
  Future<void> actualizarTemario({
    required String eventoId,
    required String tema,
    String? fecha,
  }) async {
    final data = <String, dynamic>{'descripcion': tema};
    if (fecha != null) data['fecha'] = fecha;
    await _client.from('acad_calendario').update(data).eq('evento_id', eventoId);
  }

  /// Obtiene los temarios cargados para un curso específico
  Future<List<Map<String, dynamic>>> obtenerTemarios({String? cursoId, String? materiaId}) async {
    try {
      var query = _client
          .from('acad_calendario')
          .select('*')
          .eq('tipo_evento', 'TEMARIO');
      if (cursoId != null) {
        query = query.eq('curso_id', cursoId);
      }
      if (materiaId != null) {
        query = query.eq('materia_id', materiaId);
      }
      final response = await query.order('fecha', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener temarios: $e');
      // Reintento sin filtro de materia por si la columna aún no está migrada
      if (materiaId != null) return obtenerTemarios(cursoId: cursoId);
      return [];
    }
  }

  /// Obtiene todo el historial de asistencia (cabeceras y detalles) de un curso para la sábana mensual
  Future<List<Map<String, dynamic>>> obtenerAsistenciaMensualCurso(
    String cursoId, {
    String? materiaId,
    String tipoAsistencia = 'PRECEPTOR_DIARIA',
  }) async {
    try {
      var query = _client
          .from('asistencia_cabecera')
          .select('asistencia_cabecera_id, fecha')
          .eq('curso_id', cursoId);
      
      if (materiaId != null) {
        query = query.eq('materia_id', materiaId);
      } else {
        query = query.eq('tipo_asistencia', tipoAsistencia);
      }

      final headers = await query;
      if (headers.isEmpty) return [];

      final headerIds = headers.map((h) => h['asistencia_cabecera_id'] as String).toList();
      
      final details = await _client
          .from('asistencia_detalle')
          .select('alumno_id, tipo, asistencia_cabecera_id')
          .inFilter('asistencia_cabecera_id', headerIds);

      final List<Map<String, dynamic>> results = [];
      for (final det in details) {
        final cab = headers.firstWhere(
          (h) => h['asistencia_cabecera_id'] == det['asistencia_cabecera_id'],
          orElse: () => {},
        );
        if (cab.isEmpty) continue;
        results.add({
          'alumno_id': det['alumno_id'],
          'tipo': det['tipo'],
          'fecha': cab['fecha'],
        });
      }
      return results;
    } catch (e) {
      print('Error al obtener asistencia mensual: $e');
      return [];
    }
  }

  // ─── LIBRO DE ACTAS DIGITALES ────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> obtenerActas({
    String? categoria,
    String? cursoId,
    required String rol,
    String? nombreUsuario,
  }) async {
    try {
      var query = _client.from('acad_actas').select('*');
      if (categoria != null && categoria != 'TODAS') {
        query = query.eq('categoria', categoria);
      }
      if (cursoId != null && cursoId.isNotEmpty && cursoId != 'TODOS') {
        query = query.eq('curso_id', cursoId);
      }
      final list = await query.order('created_at', ascending: false);
      final actas = List<Map<String, dynamic>>.from(list);

      // Si es ADMIN o PRECEPTOR pueden ver todas las actas
      if (rol == 'ADMIN' || rol == 'PRECEPTOR') {
        return actas;
      }

      // Si es DOCENTE u otro rol, no pueden ver actas de ACCIDENTES si no participan explícitamente, y solo ven actas donde se les mencione o de su curso
      return actas.where((acta) {
        final cat = acta['categoria']?.toString() ?? '';
        if (cat == 'ACCIDENTES') {
          if (nombreUsuario != null && (acta['participantes']?.toString().toLowerCase().contains(nombreUsuario.toLowerCase()) ?? false)) {
            return true;
          }
          return false;
        }
        return true;
      }).toList();
    } catch (e) {
      print('Error al obtener actas desde Supabase: $e');
      return [];
    }
  }

  Future<void> crearActa({
    required String titulo,
    required String categoria,
    String? cursoId,
    required String contenido,
    required String participantes,
  }) async {
    try {
      final user = _client.auth.currentUser;
      await _client.from('acad_actas').insert({
        'titulo': titulo,
        'categoria': categoria,
        'curso_id': (cursoId != null && cursoId.isNotEmpty && cursoId != 'TODOS') ? cursoId : null,
        'contenido': contenido,
        'participantes': participantes,
        'firmas': [],
        'creado_por': user?.id,
      });
    } catch (e) {
      print('Error al crear acta en Supabase: $e');
      rethrow;
    }
  }

  Future<void> firmarActa({
    required String actaId,
    required String nombreFirmante,
    required List<String> firmasActuales,
  }) async {
    try {
      final nuevasFirmas = [...firmasActuales, nombreFirmante];
      await _client.from('acad_actas').update({'firmas': nuevasFirmas}).eq('acta_id', actaId);
      obtenerAuthIdsAdministracion().then((adminIds) {
        notificarSistema(
          asunto: 'Firma de Acta Institucional Digital: $nombreFirmante',
          texto: 'Se ha registrado la firma electrónica de "$nombreFirmante" en el libro de actas digitales institucional.',
          destinatariosAuthIds: adminIds,
        );
      });
    } catch (e) {
      print('Error al firmar acta en Supabase: $e');
      rethrow;
    }
  }

  /// Actualiza los detalles de la adecuación curricular del alumno en usr_legajo_alumno
  Future<void> actualizarAdecuacionCurricular({
    required String alumnoId,
    required bool activa,
    required String tipo,
    required String detalles,
  }) async {
    // 1. Obtener datos demográficos actuales para no sobrescribir otra información
    final current = await _client
        .from('usr_legajo_alumno')
        .select('datos_demograficos')
        .eq('legajo_id', alumnoId)
        .maybeSingle();

    final Map<String, dynamic> demo = Map<String, dynamic>.from(current?['datos_demograficos'] as Map? ?? {});
    
    // 2. Modificar las claves de adecuación
    demo['adecuacion_curricular'] = activa;
    demo['tipo_adecuacion'] = tipo;
    demo['detalles_adecuacion'] = detalles;

    // 3. Guardar de nuevo
    await _client
        .from('usr_legajo_alumno')
        .update({'datos_demograficos': demo})
        .eq('legajo_id', alumnoId);
  }

  // ─── EOE / ADECUACIONES CURRICULARES ────────────────────────────────────
  //
  // eoe_ficha / eoe_bitacora / eoe_documentos + bucket 'eoe'
  // (ver eoe_banco_migration.sql). El flag datos_demograficos.adecuacion_curricular
  // se sigue escribiendo para no romper los paneles que ya lo leen.

  String _nombreUsuarioActual() {
    final u = _client.auth.currentUser;
    return (u?.userMetadata?['nombre'] ??
            u?.userMetadata?['first_name'] ??
            u?.email ??
            'Usuario')
        .toString();
  }

  String rolUsuarioActual() {
    final rol = _client.auth.currentUser?.userMetadata?['rol'] as String?;
    return rol ?? 'DOCENTE';
  }

  bool get esDirectivoActual {
    final rol = rolUsuarioActual();
    return rol == 'ADMIN' || rol == 'PRECEPTOR' || rol == 'EOE';
  }

  /// Fichas EOE activas. Si se pasa [cursoId] (portal docente) se limita a ese
  /// curso usando el roster real; sin cursoId (administración) trae todas.
  Future<List<Map<String, dynamic>>> obtenerFichasEoe({String? cursoId}) async {
    // 1. Fichas persistidas
    Map<String, Map<String, dynamic>> porLegajo = {};
    try {
      final res = await _client.from('eoe_ficha').select('*');
      porLegajo = {
        for (final f in List<Map<String, dynamic>>.from(res))
          f['legajo_id'].toString(): f
      };
    } catch (e) {
      debugPrint('eoe_ficha no disponible aún: $e');
    }

    // 2. Roster
    final List<Map<String, dynamic>> base = [];
    if (cursoId != null) {
      final roster = await fetchAlumnos(cursoId: cursoId);
      for (final a in roster) {
        base.add({'legajo_id': a.id, 'nombre_completo': a.nombre, 'dni': '', 'curso_id': cursoId});
      }
    } else {
      final lista = await fetchAlumnosList();
      for (final a in lista) {
        base.add({
          'legajo_id': a['legajo_id'],
          'nombre_completo': a['nombre_completo'],
          'dni': a['dni'] ?? '',
          'curso_id': a['curso_id'],
          'curso_nombre': a['curso_nombre'],
          'demo_activa': a['adecuacion_curricular'] == true,
          'demo_tipo': a['tipo_adecuacion'],
          'demo_detalles': a['detalles_adecuacion'],
        });
      }
    }

    // 3. Merge → sólo activas
    final out = <Map<String, dynamic>>[];
    for (final a in base) {
      final f = porLegajo[a['legajo_id'].toString()];
      final activa = f != null ? (f['activa'] == true) : (a['demo_activa'] == true);
      if (!activa) continue;
      out.add({
        'legajo_id': a['legajo_id'],
        'nombre_completo': a['nombre_completo'],
        'dni': a['dni'] ?? '',
        'curso_id': a['curso_id'],
        'curso_nombre': a['curso_nombre'],
        'tipo_adecuacion': f?['tipo_adecuacion'] ?? a['demo_tipo'] ?? 'Metodológica',
        'detalles': f?['detalles'] ?? a['demo_detalles'] ?? '',
        'datos_formulario':
            Map<String, dynamic>.from(f?['datos_formulario'] as Map? ?? {}),
        'tiene_ficha': f != null,
      });
    }
    out.sort((x, y) => (x['nombre_completo'] ?? '')
        .toString()
        .compareTo((y['nombre_completo'] ?? '').toString()));
    return out;
  }

  /// Alta/edición de la ficha EOE de un alumno ya inscripto.
  Future<void> guardarFichaEoe({
    required String legajoId,
    required bool activa,
    required String tipo,
    required String detalles,
    Map<String, dynamic> datosFormulario = const {},
  }) async {
    final user = _client.auth.currentUser;
    await _client.from('eoe_ficha').upsert({
      'legajo_id': legajoId,
      'activa': activa,
      'tipo_adecuacion': tipo,
      'detalles': detalles,
      'datos_formulario': datosFormulario,
      'actualizado_por': user?.id,
      'actualizado_en': DateTime.now().toIso8601String(),
    }, onConflict: 'legajo_id');

    // Compatibilidad con los paneles que leen el flag del legajo.
    await actualizarAdecuacionCurricular(
      alumnoId: legajoId,
      activa: activa,
      tipo: tipo,
      detalles: detalles,
    );
  }

  Future<List<Map<String, dynamic>>> obtenerBitacoraEoe(String legajoId) async {
    try {
      final res = await _client
          .from('eoe_bitacora')
          .select('*')
          .eq('legajo_id', legajoId)
          .order('fecha', ascending: false)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error obtener bitácora EOE: $e');
      return [];
    }
  }

  Future<void> agregarNotaBitacoraEoe({
    required String legajoId,
    required String nota,
  }) async {
    final user = _client.auth.currentUser;
    final rol = rolUsuarioActual();
    await _client.from('eoe_bitacora').insert({
      'legajo_id': legajoId,
      'autor_auth': user?.id,
      'autor_nombre': _nombreUsuarioActual(),
      'autor_rol': rol == 'ADMIN' || rol == 'PRECEPTOR'
          ? 'ADMIN'
          : (rol == 'EOE' ? 'EOE' : 'DOCENTE'),
      'nota': nota,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerDocumentosEoe(String legajoId,
      {String? categoria}) async {
    try {
      var q = _client.from('eoe_documentos').select('*').eq('legajo_id', legajoId);
      if (categoria != null) q = q.eq('categoria', categoria);
      final res = await q.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error obtener documentos EOE: $e');
      return [];
    }
  }

  /// Sube un archivo al bucket 'eoe' y registra el documento.
  Future<void> subirDocumentoEoe({
    required String legajoId,
    required String categoria,
    required List<int> bytes,
    required String fileName,
    String? observaciones,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final limpio = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$legajoId/$categoria/${ts}_$limpio';

    await _client.storage.from('eoe').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );

    await _client.from('eoe_documentos').insert({
      'legajo_id': legajoId,
      'nombre': fileName,
      'categoria': categoria,
      'storage_path': path,
      'observaciones_eoe': observaciones,
      'estado': categoria == 'EVAL_ADECUADA' ? 'ADECUADA' : 'PENDIENTE',
      'subido_por_auth': _client.auth.currentUser?.id,
      'subido_por_nombre': _nombreUsuarioActual(),
    });
  }

  Future<void> actualizarDocumentoEoe({
    required String id,
    String? observaciones,
    String? estado,
  }) async {
    final cambios = <String, dynamic>{};
    if (observaciones != null) cambios['observaciones_eoe'] = observaciones;
    if (estado != null) cambios['estado'] = estado;
    if (cambios.isEmpty) return;
    await _client.from('eoe_documentos').update(cambios).eq('id', id);
  }

  /// URL firmada (1h) para descargar un archivo de un bucket privado.
  Future<String> urlFirmadaStorage(String bucket, String path) async {
    return _client.storage.from(bucket).createSignedUrl(path, 3600);
  }

  // ─── BANCO DE EVALUACIONES ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerBancoEvaluaciones({
    required String materiaId,
    String? cursoId,
  }) async {
    var q = _client.from('banco_evaluaciones').select('*').eq('materia_id', materiaId);
    if (cursoId != null && cursoId.isNotEmpty) {
      // Incluir las cargadas antes de existir curso_id (curso_id null).
      q = q.or('curso_id.eq.$cursoId,curso_id.is.null');
    }
    final res = await q.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Sube el archivo al bucket 'banco-evaluaciones' y registra la propuesta.
  Future<Map<String, dynamic>> subirEvaluacionBanco({
    required String materiaId,
    required String cursoId,
    required String titulo,
    required String descripcion,
    required String tipo,
    List<int>? bytes,
    String? fileName,
    required bool aprobarAlSubir,
  }) async {
    String? storagePath;
    if (bytes != null && fileName != null) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final limpio = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      storagePath = '$cursoId/$materiaId/${ts}_$limpio';
      await _client.storage.from('banco-evaluaciones').uploadBinary(
            storagePath,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(upsert: true),
          );
    }

    final fila = {
      'materia_id': materiaId,
      'curso_id': cursoId,
      'titulo': titulo,
      'descripcion': descripcion,
      'tipo': tipo,
      'archivo_url': fileName,
      'storage_path': storagePath,
      'estado': aprobarAlSubir ? 'APROBADA' : 'PENDIENTE DE APROBACIÓN',
      'subido_por': _nombreUsuarioActual(),
      'subido_por_auth': _client.auth.currentUser?.id,
    };

    final res = await _client.from('banco_evaluaciones').insert(fila).select().single();
    return Map<String, dynamic>.from(res);
  }

  Future<void> cambiarEstadoEvaluacionBanco(String id, String estado) async {
    await _client.from('banco_evaluaciones').update({'estado': estado}).eq('id', id);
  }

  // ─── REPOSITORIO PEDAGÓGICO (ped_documentos, bucket 'pedagogico') ────────

  Future<List<Map<String, dynamic>>> obtenerDocsPedagogicos({
    String? cursoId,
    String? materiaId,
  }) async {
    try {
      var q = _client.from('ped_documentos').select('*');
      if (cursoId != null) q = q.eq('curso_id', cursoId);
      if (materiaId != null) q = q.eq('materia_id', materiaId);
      final res = await q.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error obtener docs pedagógicos: $e');
      return [];
    }
  }

  Future<void> subirDocPedagogico({
    required String cursoId,
    required String materiaId,
    required String tipo,
    required List<int> bytes,
    required String fileName,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final limpio = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$cursoId/$materiaId/${tipo}_${ts}_$limpio';
    await _client.storage.from('pedagogico').uploadBinary(
        path, Uint8List.fromList(bytes),
        fileOptions: const FileOptions(upsert: true));
    await _client.from('ped_documentos').insert({
      'curso_id': cursoId,
      'materia_id': materiaId,
      'tipo': tipo,
      'nombre': fileName,
      'storage_path': path,
      'estado': 'PENDIENTE',
      'subido_por_auth': _client.auth.currentUser?.id,
      'subido_por_nombre': _nombreUsuarioActual(),
    });
  }

  Future<void> actualizarDocPedagogico({
    required String id,
    String? estado,
    String? observaciones,
  }) async {
    final c = <String, dynamic>{};
    if (estado != null) c['estado'] = estado;
    if (observaciones != null) c['observaciones'] = observaciones;
    if (c.isEmpty) return;
    await _client.from('ped_documentos').update(c).eq('id', id);
  }

  Future<void> eliminarDocPedagogico(String id) async {
    await _client.from('ped_documentos').delete().eq('id', id);
  }

  // ─── PROYECTOS INSTITUCIONALES ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerProyectos() async {
    try {
      final res = await _client
          .from('proy_institucionales')
          .select('*')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error obtener proyectos: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> guardarProyecto({
    String? id,
    required String nombre,
    String? descripcion,
    String? responsable,
    required String estado,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    final data = {
      'nombre': nombre,
      'descripcion': descripcion,
      'responsable': responsable,
      'estado': estado,
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      data['creado_por'] = _client.auth.currentUser?.id;
      final res = await _client.from('proy_institucionales').insert(data).select().single();
      return Map<String, dynamic>.from(res);
    } else {
      final res = await _client
          .from('proy_institucionales')
          .update(data)
          .eq('id', id)
          .select()
          .single();
      return Map<String, dynamic>.from(res);
    }
  }

  Future<void> eliminarProyecto(String id) async {
    await _client.from('proy_institucionales').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> obtenerDocsProyecto(String proyectoId) async {
    try {
      final res = await _client
          .from('proy_documentos')
          .select('*')
          .eq('proyecto_id', proyectoId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  Future<void> subirDocProyecto({
    required String proyectoId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final limpio = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$proyectoId/${ts}_$limpio';
    await _client.storage.from('proyectos').uploadBinary(
        path, Uint8List.fromList(bytes),
        fileOptions: const FileOptions(upsert: true));
    await _client.from('proy_documentos').insert({
      'proyecto_id': proyectoId,
      'nombre': fileName,
      'storage_path': path,
      'subido_por_nombre': _nombreUsuarioActual(),
    });
  }

  // ─── HORARIOS + DISPONIBILIDAD (DDJJ) ──────────────────────────────────

  static int _minutos(String hhmm) {
    final p = hhmm.trim().split(':');
    if (p.length < 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  static bool _seSolapan(String i1, String f1, String i2, String f2) {
    final a1 = _minutos(i1), b1 = _minutos(f1), a2 = _minutos(i2), b2 = _minutos(f2);
    return a1 < b2 && a2 < b1;
  }

  /// Grilla horaria REAL de un curso: cada bloque con materia y docente titular.
  Future<List<Map<String, dynamic>>> obtenerHorarioCurso(String cursoId) async {
    try {
      final bloques = await _client
          .from('acad_horarios')
          .select('horario_id, materia_id, dia_semana, hora_inicio, hora_fin')
          .eq('curso_id', cursoId);
      final materias = await _client
          .from('acad_materias')
          .select('materia_id, nombre_asignatura, docente_titular_id')
          .eq('curso_id', cursoId);
      final matMap = {for (final m in materias) m['materia_id']: m};

      final docIds = materias
          .map((m) => m['docente_titular_id'])
          .where((d) => d != null)
          .toSet()
          .toList();
      Map<dynamic, String> docNombre = {};
      if (docIds.isNotEmpty) {
        final docs = await _client
            .from('usr_docentes')
            .select('docente_id, nombre, apellido')
            .inFilter('docente_id', docIds);
        docNombre = {
          for (final d in docs)
            d['docente_id']: [d['apellido'], d['nombre']]
                .where((x) => x != null && x.toString().isNotEmpty)
                .join(', ')
        };
      }

      return List<Map<String, dynamic>>.from(bloques).map((b) {
        final m = matMap[b['materia_id']];
        return {
          'horario_id': b['horario_id'],
          'materia_id': b['materia_id'],
          'materia': m?['nombre_asignatura'] ?? '—',
          'docente_id': m?['docente_titular_id'],
          'docente': docNombre[m?['docente_titular_id']] ?? 'Sin asignar',
          'dia': (b['dia_semana'] ?? '').toString(),
          'inicio': (b['hora_inicio'] ?? '').toString(),
          'fin': (b['hora_fin'] ?? '').toString(),
        };
      }).toList()
        ..sort((a, b) {
          final d = a['dia'].toString().compareTo(b['dia'].toString());
          return d != 0 ? d : _minutos(a['inicio']).compareTo(_minutos(b['inicio']));
        });
    } catch (e) {
      debugPrint('Error obtener horario curso: $e');
      return [];
    }
  }

  /// Lista simple de docentes para selectores: `[{docente_id, nombre}]`.
  Future<List<Map<String, dynamic>>> obtenerDocentesSimple() async {
    try {
      final res = await _client
          .from('usr_docentes')
          .select('docente_id, nombre, apellido, auth_id');
      final list = List<Map<String, dynamic>>.from(res).map((d) {
        final n = [d['apellido'], d['nombre']]
            .where((x) => x != null && x.toString().trim().isNotEmpty)
            .join(', ');
        return {
          'docente_id': d['docente_id'],
          'nombre': n.isEmpty ? 'Docente' : n,
        };
      }).toList()
        ..sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));
      return list;
    } catch (e) {
      debugPrint('Error obtener docentes simple: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerDisponibilidadDocente(String docenteId) async {
    try {
      final res = await _client
          .from('usr_docentes')
          .select('disponibilidad')
          .eq('docente_id', docenteId)
          .maybeSingle();
      return List<Map<String, dynamic>>.from(res?['disponibilidad'] as List? ?? []);
    } catch (_) {
      return [];
    }
  }

  Future<void> guardarDisponibilidadDocente(
      String docenteId, List<Map<String, dynamic>> franjas) async {
    await _client
        .from('usr_docentes')
        .update({'disponibilidad': franjas}).eq('docente_id', docenteId);
  }

  /// Reasigna el docente titular de una materia, chequeando antes:
  ///  - choque: el nuevo docente ya dicta en otro curso el mismo día/horario
  ///  - disponibilidad: los bloques de la materia caen fuera de lo declarado
  /// Devuelve `{ok, choques:[...], fuera_disponibilidad:[...]}`. Con `forzar:true`
  /// aplica igual.
  Future<Map<String, dynamic>> reasignarDocenteMateria({
    required String materiaId,
    required String nuevoDocenteId,
    bool forzar = false,
  }) async {
    // Bloques de la materia a reasignar
    final mat = await _client
        .from('acad_materias')
        .select('curso_id')
        .eq('materia_id', materiaId)
        .maybeSingle();
    final bloquesMateria = await _client
        .from('acad_horarios')
        .select('dia_semana, hora_inicio, hora_fin')
        .eq('materia_id', materiaId);

    // Materias que ya dicta el nuevo docente + sus bloques
    final susMaterias = await _client
        .from('acad_materias')
        .select('materia_id, nombre_asignatura, curso_id')
        .eq('docente_titular_id', nuevoDocenteId);
    final susMatIds = susMaterias.map((m) => m['materia_id']).toList();
    List<Map<String, dynamic>> susBloques = [];
    if (susMatIds.isNotEmpty) {
      final bl = await _client
          .from('acad_horarios')
          .select('materia_id, dia_semana, hora_inicio, hora_fin')
          .inFilter('materia_id', susMatIds);
      susBloques = List<Map<String, dynamic>>.from(bl);
    }
    final nombreMat = {for (final m in susMaterias) m['materia_id']: m['nombre_asignatura']};

    final disp = await obtenerDisponibilidadDocente(nuevoDocenteId);

    final choques = <String>[];
    final fuera = <String>[];
    for (final b in bloquesMateria) {
      final dia = (b['dia_semana'] ?? '').toString().toUpperCase();
      final ini = (b['hora_inicio'] ?? '').toString();
      final fin = (b['hora_fin'] ?? '').toString();

      for (final sb in susBloques) {
        if ((sb['dia_semana'] ?? '').toString().toUpperCase() == dia &&
            _seSolapan(ini, fin, (sb['hora_inicio'] ?? '').toString(),
                (sb['hora_fin'] ?? '').toString())) {
          choques.add('$dia $ini-$fin choca con ${nombreMat[sb['materia_id']] ?? 'otra materia'}');
        }
      }

      if (disp.isNotEmpty) {
        final ok = disp.any((d) =>
            (d['dia'] ?? '').toString().toUpperCase() == dia &&
            _minutos((d['desde'] ?? '00:00').toString()) <= _minutos(ini) &&
            _minutos((d['hasta'] ?? '23:59').toString()) >= _minutos(fin));
        if (!ok) fuera.add('$dia $ini-$fin fuera de la disponibilidad declarada');
      }
    }

    final ok = choques.isEmpty && fuera.isEmpty;
    if (ok || forzar) {
      await _client
          .from('acad_materias')
          .update({'docente_titular_id': nuevoDocenteId}).eq('materia_id', materiaId);
      // Mantener también la tabla relacional docente-materia-curso.
      try {
        if (mat?['curso_id'] != null) {
          await _client.from('acad_docente_materia_curso').upsert({
            'docente_id': nuevoDocenteId,
            'materia_id': materiaId,
            'curso_id': mat!['curso_id'],
          }, onConflict: 'docente_id,materia_id,curso_id');
        }
      } catch (_) {}
    }
    return {'ok': ok, 'aplicado': ok || forzar, 'choques': choques, 'fuera_disponibilidad': fuera};
  }

  /// Asocia un docente a una materia y curso en la tabla relacional
  Future<void> asignarDocenteAMateria({
    required String docenteId,
    required String materiaId,
    required String cursoId,
  }) async {
    await _client.from('acad_docente_materia_curso').insert({
      'docente_id': docenteId,
      'materia_id': materiaId,
      'curso_id': cursoId,
    });
  }

  /// Asocia un docente (especificado por su auth_id) a múltiples materias
  Future<void> vincularDocenteAMaterias(String authId, List<String> materiasIds, List<Map<String, dynamic>> materias) async {
    final docData = await _client
        .from('usr_docentes')
        .select('docente_id')
        .eq('auth_id', authId)
        .maybeSingle();
    final docenteId = docData?['docente_id'] as String?;
    if (docenteId == null) return;

    for (final mId in materiasIds) {
      final m = materias.firstWhere((element) => element['materia_id'] == mId, orElse: () => {});
      if (m.isNotEmpty) {
        await asignarDocenteMateriaCurso(
          docenteId: docenteId,
          materiaId: mId,
          cursoId: m['curso_id'] as String,
        );
      }
    }
  }

  // --- MÉTODOS PARA MI PERFIL (ARCHIVOS DDJJ / CV) ---
  Future<List<Map<String, dynamic>>> obtenerArchivosPersonal(String authId) async {
    try {
      final res = await _client
          .from('usr_archivos_personal')
          .select('*')
          .eq('auth_id', authId)
          .order('fecha_subida', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  /// Sube un archivo del legajo personal y devuelve el id generado, para poder
  /// enlazarlo (por ejemplo, un certificado con su licencia).
  Future<String?> guardarArchivoPersonal({
    required String authId,
    required String tipoArchivo, // 'DDJJ' | 'CV' | 'CERTIFICADO'
    required String nombreArchivo,
    required String formato, // 'PDF' o 'WORD'
    required String base64Data,
  }) async {
    // Obtenemos el docente_id si corresponde
    final docData = await _client
        .from('usr_docentes')
        .select('docente_id')
        .eq('auth_id', authId)
        .maybeSingle();
    final docenteId = docData?['docente_id'] as String?;

    final res = await _client.from('usr_archivos_personal').insert({
      'auth_id': authId,
      'docente_id': docenteId,
      'tipo_archivo': tipoArchivo,
      'nombre_archivo': nombreArchivo,
      'formato': formato,
      'datos_base64': base64Data,
      'fecha_subida': DateTime.now().toIso8601String(),
    }).select('id').maybeSingle();

    return res?['id']?.toString();
  }

  /// Guarda los datos de contacto del propio perfil docente.
  /// Va por RPC porque la política de usr_docentes sólo permite UPDATE a
  /// ADMIN/DIRECTIVO: la función actualiza sólo la fila del usuario actual y
  /// nunca toca ddjj_cargos (que define privilegios).
  Future<void> actualizarMiPerfilDocente({
    String? telefono,
    String? domicilio,
    String? tituloProfesional,
    String? especialidad,
  }) async {
    await _client.rpc('actualizar_mi_perfil_docente', params: {
      'p_telefono': telefono,
      'p_domicilio': domicilio,
      'p_titulo_profesional': tituloProfesional,
      'p_especialidad': especialidad,
    });
  }

  Future<void> eliminarArchivoPersonal(String archivoId) async {
    await _client.from('usr_archivos_personal').delete().eq('id', archivoId);
  }

  // --- FALTAS Y LICENCIAS DEL DOCENTE ---

  /// Inasistencias y licencias del docente autenticado (o del que se indique).
  Future<List<Map<String, dynamic>>> obtenerInasistenciasDocente(String authId) async {
    try {
      final res = await _client
          .from('usr_docente_inasistencias')
          .select('*, usr_archivos_personal(id, nombre_archivo, formato, datos_base64)')
          .eq('auth_id', authId)
          .order('fecha_desde', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Error al obtener inasistencias del docente: $e');
      return [];
    }
  }

  /// Registra una falta o licencia. [archivoId] enlaza el certificado ya subido.
  Future<void> registrarInasistenciaDocente({
    required String authId,
    required String tipo, // 'INJUSTIFICADA' | 'JUSTIFICADA' | 'LICENCIA'
    required DateTime fechaDesde,
    required DateTime fechaHasta,
    String? motivo,
    String? observaciones,
    String? archivoId,
  }) async {
    final docData = await _client
        .from('usr_docentes')
        .select('docente_id')
        .eq('auth_id', authId)
        .maybeSingle();

    await _client.from('usr_docente_inasistencias').insert({
      'auth_id': authId,
      'docente_id': docData?['docente_id'],
      'tipo': tipo,
      'fecha_desde': fechaDesde.toIso8601String().substring(0, 10),
      'fecha_hasta': fechaHasta.toIso8601String().substring(0, 10),
      'motivo': motivo,
      'observaciones': observaciones,
      'archivo_id': archivoId,
    });
  }

  Future<void> eliminarInasistenciaDocente(String id) async {
    await _client.from('usr_docente_inasistencias').delete().eq('id', id);
  }

  /// Resumen para las tarjetas del perfil: días injustificados, licencias y
  /// porcentaje de presentismo del mes en curso.
  /// El presentismo se calcula sobre los días hábiles (lunes a viernes) del mes.
  Map<String, dynamic> resumirInasistencias(
    List<Map<String, dynamic>> inasistencias, {
    DateTime? mesDeReferencia,
  }) {
    final ref = mesDeReferencia ?? DateTime.now();
    final inicioMes = DateTime(ref.year, ref.month, 1);
    final finMes = DateTime(ref.year, ref.month + 1, 0);

    int diasEntre(DateTime a, DateTime b) => b.difference(a).inDays + 1;

    int injustificadas = 0;
    int licencias = 0;
    int diasAusentesEnElMes = 0;

    for (final i in inasistencias) {
      final desde = DateTime.tryParse((i['fecha_desde'] ?? '').toString());
      final hasta = DateTime.tryParse((i['fecha_hasta'] ?? '').toString()) ?? desde;
      if (desde == null || hasta == null) continue;

      final dias = diasEntre(desde, hasta);
      final tipo = (i['tipo'] ?? '').toString().toUpperCase();
      if (tipo == 'INJUSTIFICADA') {
        injustificadas += dias;
      } else {
        licencias += dias;
      }

      // Solapamiento con el mes de referencia, contando sólo días hábiles
      final desdeMes = desde.isBefore(inicioMes) ? inicioMes : desde;
      final hastaMes = hasta.isAfter(finMes) ? finMes : hasta;
      if (!hastaMes.isBefore(desdeMes)) {
        for (var d = desdeMes;
            !d.isAfter(hastaMes);
            d = d.add(const Duration(days: 1))) {
          if (d.weekday <= 5) diasAusentesEnElMes++;
        }
      }
    }

    int habilesDelMes = 0;
    for (var d = inicioMes; !d.isAfter(finMes); d = d.add(const Duration(days: 1))) {
      if (d.weekday <= 5) habilesDelMes++;
    }

    final presentismo = habilesDelMes == 0
        ? 100
        : (((habilesDelMes - diasAusentesEnElMes) / habilesDelMes) * 100).round().clamp(0, 100);

    return {
      'injustificadas': injustificadas,
      'licencias': licencias,
      'presentismo': presentismo,
    };
  }

  // --- OBSERVACIONES ÁULICAS / DEVOLUCIONES DIRECTIVAS ---

  /// Devoluciones de supervisión recibidas por un docente.
  Future<List<Map<String, dynamic>>> obtenerObservacionesAulicas(String docenteAuthId) async {
    try {
      final res = await _client
          .from('usr_observaciones_aulicas')
          .select('*, usr_archivos_personal(id, nombre_archivo, formato, datos_base64)')
          .eq('docente_auth_id', docenteAuthId)
          .order('fecha_visita', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Error al obtener observaciones áulicas: $e');
      return [];
    }
  }

  /// Historial completo (portal directivo).
  Future<List<Map<String, dynamic>>> obtenerTodasLasObservacionesAulicas() async {
    try {
      final res = await _client
          .from('usr_observaciones_aulicas')
          .select('*')
          .order('fecha_visita', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Error al obtener el historial de supervisión: $e');
      return [];
    }
  }

  /// Registra una visita de clase y notifica al docente observado.
  Future<void> registrarObservacionAulica({
    required String docenteAuthId,
    String? docenteId,
    String? docenteNombre,
    String? cursoTexto,
    required DateTime fechaVisita,
    String? modulo,
    String? foco,
    required String observacion,
    String? acuerdos,
    bool notificarDocente = true,
  }) async {
    final user = _client.auth.currentUser;

    await _client.from('usr_observaciones_aulicas').insert({
      'docente_auth_id': docenteAuthId,
      'docente_id': docenteId,
      'curso_texto': cursoTexto,
      'fecha_visita': fechaVisita.toIso8601String().substring(0, 10),
      'modulo': modulo,
      'foco': foco,
      'observacion': observacion,
      'acuerdos': acuerdos,
      'subido_por': user?.userMetadata?['nombre'] ?? user?.email ?? 'Equipo Directivo',
      'subido_por_auth': user?.id,
      'leido': false,
    });

    if (notificarDocente) {
      await notificarSistema(
        asunto: 'Devolución de Observación Áulica${cursoTexto != null ? ' — $cursoTexto' : ''}',
        texto: 'Recibiste una nueva devolución de supervisión pedagógica. '
            'Podés leerla en Mi Perfil > Observaciones de Clases.',
        destinatariosAuthIds: [docenteAuthId],
      );
    }
  }

  Future<void> marcarObservacionAulicaLeida(String id) async {
    await _client.from('usr_observaciones_aulicas').update({
      'leido': true,
      'fecha_lectura': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Personal de la institución (docentes y directivos) con su auth_id.
  Future<List<Map<String, dynamic>>> obtenerPersonalConAuth() async {
    try {
      final res = await _client.rpc('get_personal_list');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      print('Error al obtener el listado de personal: $e');
      return [];
    }
  }

  // --- MÉTODOS PARA TRAYECTORIA ESCOLAR DEL ALUMNO ---
  Future<List<Map<String, dynamic>>> obtenerTrayectoriaAlumno(String legajoId) async {
    try {
      final res = await _client
          .from('acad_trayectoria_alumno')
          .select('*')
          .eq('legajo_id', legajoId)
          .order('anio_lectivo', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  Future<void> guardarTrayectoriaAlumno({
    required String legajoId,
    required String cursoNombre,
    required int anioLectivo,
    required String condicion,
    required double promedio,
    String? observaciones,
  }) async {
    await _client.from('acad_trayectoria_alumno').insert({
      'legajo_id': legajoId,
      'curso_nombre': cursoNombre,
      'anio_lectivo': anioLectivo,
      'condicion': condicion,
      'promedio': promedio,
      'observaciones': observaciones ?? '',
    });
  }

  // --- MÉTODOS PARA MATERIAS ADEUDADAS / PREVIAS / RITE ---
  Future<List<Map<String, dynamic>>> obtenerMateriasAdeudadas(String legajoId) async {
    try {
      final res = await _client
          .from('acad_materias_adeudadas')
          .select('*')
          .or('legajo_id.eq.$legajoId,alumno_id.eq.$legajoId')
          .order('anio_origen', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Error al obtener materias adeudadas: $e');
      return [];
    }
  }

  Future<void> guardarMateriaAdeudada({
    required String legajoId,
    required String nombreMateria,
    required int anioOrigen,
    required String condicion,
    required String estado,
    String? observaciones,
  }) async {
    await _client.from('acad_materias_adeudadas').insert({
      'legajo_id': legajoId,
      'nombre_materia': nombreMateria,
      'anio_origen': anioOrigen,
      'condicion': condicion,
      'estado': estado,
      'observaciones': observaciones ?? '',
    });
  }

  Future<void> actualizarEstadoMateriaAdeudada(String id, String nuevoEstado) async {
    await _client
        .from('acad_materias_adeudadas')
        .update({'estado': nuevoEstado})
        .eq('adeudada_id', id);
  }

  // --- MÉTODOS PARA TRÁMITES Y CONSTANCIAS ---
  Future<List<Map<String, dynamic>>> obtenerTramitesPorPadre(String padreAuthId) async {
    try {
      final res = await _client
          .from('tramites_solicitudes')
          .select('*, usr_legajo_alumno(*)')
          .eq('padre_auth_id', padreAuthId)
          .order('fecha_solicitud', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerTodosLosTramites() async {
    try {
      final res = await _client
          .from('tramites_solicitudes')
          .select('*, usr_legajo_alumno(*)')
          .order('fecha_solicitud', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  Future<void> solicitarConstancia({
    required String legajoId,
    required String padreAuthId,
    required String tipoTramite,
    String? observaciones,
  }) async {
    await _client.from('tramites_solicitudes').insert({
      'legajo_id': legajoId,
      'padre_auth_id': padreAuthId,
      'tipo_tramite': tipoTramite,
      'estado': 'PENDIENTE',
      'fecha_solicitud': DateTime.now().toIso8601String(),
      'observaciones': observaciones ?? 'Solicitado desde Portal de Familias.',
    });

    obtenerAuthIdsAdministracion().then((adminIds) {
      notificarSistema(
        asunto: 'Movimiento de Familias: Solicitud de Constancia ($tipoTramite)',
        texto: 'Se ha ingresado una nueva solicitud de trámite/constancia desde el Portal de Familias.',
        destinatariosAuthIds: adminIds,
      );
    });
  }

  Future<void> resolverTramite({
    required String tramiteId,
    required String nuevoEstado,
    required String codigoVerificacion,
    String? observaciones,
  }) async {
    await _client.from('tramites_solicitudes').update({
      'estado': nuevoEstado,
      'fecha_resolucion': DateTime.now().toIso8601String(),
      'codigo_verificacion': codigoVerificacion,
      'observaciones': observaciones ?? 'Trámite emitido formalmente por Dirección/Secretaría.',
    }).eq('id', tramiteId);

    // Obtener información del trámite para notificar al padre y a administración
    try {
      final t = await _client.from('tramites_solicitudes').select('padre_auth_id, tipo_tramite').eq('id', tramiteId).maybeSingle();
      if (t != null) {
        final padreId = t['padre_auth_id']?.toString() ?? '';
        final tipo = t['tipo_tramite']?.toString() ?? 'Constancia';
        final adminIds = await obtenerAuthIdsAdministracion();
        final dests = [...adminIds, if (padreId.isNotEmpty) padreId];
        await notificarSistema(
          asunto: 'Resolución de Dirección: Trámite $nuevoEstado ($tipo)',
          texto: 'El trámite "$tipo" ha sido resuelto y aprobado formalmente por la Dirección/Secretaría. Código: $codigoVerificacion.',
          destinatariosAuthIds: dests,
        );
      }
    } catch (_) {}
  }

  /// Valida si al asignar o cambiar el horario de un docente existe conflicto
  /// con su Declaración Jurada de Cargos (DDJJ) o con otros cursos en la misma franja.
  Future<Map<String, dynamic>> validarConflictoHorarioYDDJJ({
    required String emailOIdDocente,
    required String diaSemana,
    required String moduloInicio,
    required String moduloFin,
    required List<Map<String, dynamic>> horariosActivosInstitucion,
    required Map<String, Map<String, dynamic>> ddjjProfesores,
  }) async {
    // 1. Verificar colisión interna (ya tiene hora en la institución en ese día y franja)
    for (final h in horariosActivosInstitucion) {
      if ((h['docente'] == emailOIdDocente || h['email'] == emailOIdDocente) &&
          h['dia'] == diaSemana &&
          h['modulo'] == moduloInicio) {
        return {
          'hay_conflicto': true,
          'tipo': 'COLISION_INTERNA',
          'mensaje': 'El docente ya dicta ${h['materia']} en ${h['curso']} los $diaSemana a las $moduloInicio.',
        };
      }
    }

    // 2. Verificar en la Declaración Jurada (DDJJ externa / cargos externos)
    final ddjj = ddjjProfesores[emailOIdDocente];
    if (ddjj != null && ddjj['presentado'] == true) {
      final restricciones = ddjj['restricciones'] as List<dynamic>? ?? [];
      for (final r in restricciones) {
        if (r['dia'] == diaSemana && r['modulo'] == moduloInicio) {
          return {
            'hay_conflicto': true,
            'tipo': 'CONFLICTO_DDJJ',
            'mensaje': 'Conflicto con Declaración Jurada: El docente declaró incompatibilidad horaria por cargo en ${r['institucion'] ?? "otra institución"} ($diaSemana a las $moduloInicio).',
          };
        }
      }
    }

    return {
      'hay_conflicto': false,
      'tipo': 'OK',
      'mensaje': 'Horario sin superposiciones ni conflictos con DDJJ.',
    };
  }

  // =========================================================================
  // BOLETINES E INFORME DE TRAYECTORIA
  // =========================================================================

  Future<double> calcularInasistenciasTotales(String alumnoId, String cursoId, int anio) async {
    final res = await _client
        .from('asistencia_detalle')
        .select('valor_inasistencia, asistencia_cabecera!inner(curso_id, fecha)')
        .eq('alumno_id', alumnoId)
        .eq('asistencia_cabecera.curso_id', cursoId)
        .gte('asistencia_cabecera.fecha', '$anio-01-01')
        .lte('asistencia_cabecera.fecha', '$anio-12-31');
    
    double total = 0.0;
    for (var r in res) {
      total += (r['valor_inasistencia'] as num).toDouble();
    }
    return total;
  }

  Future<void> actualizarInasistenciasBoletin(String boletinId, double inasistencias) async {
    await _client.from('aca_boletines').update({
      'total_inasistencias_diarias': inasistencias,
      'fecha_actualizacion': DateTime.now().toIso8601String()
    }).eq('boletin_id', boletinId);
  }

  Future<Map<String, dynamic>> obtenerOCrearBoletin(String alumnoId, String cursoId, int anioLectivo) async {
    var resp = await _client
        .from('aca_boletines')
        .select()
        .eq('alumno_id', alumnoId)
        .eq('curso_id', cursoId)
        .eq('anio_lectivo', anioLectivo)
        .maybeSingle();
    
    if (resp == null) {
      resp = await _client.from('aca_boletines').insert({
        'alumno_id': alumnoId,
        'curso_id': cursoId,
        'anio_lectivo': anioLectivo,
      }).select().single();
    }
    return resp;
  }

  Future<void> guardarCriteriosDocente(
    String boletinId, 
    String materiaId, 
    Map<String, String> criterios
  ) async {
    var detalle = await _client
        .from('aca_boletin_detalle')
        .select()
        .eq('boletin_id', boletinId)
        .eq('materia_id', materiaId)
        .maybeSingle();

    if (detalle == null) {
      await _client.from('aca_boletin_detalle').insert({
        'boletin_id': boletinId,
        'materia_id': materiaId,
        'apropiacion_contenidos': criterios['apropiacion'],
        'resolucion_actividades': criterios['resolucion'],
        'participacion_clases': criterios['participacion'],
        'planteos_dudas': criterios['dudas'],
        'entrega_actividades': criterios['entrega'],
        'prolijidad_carpeta': criterios['prolijidad'],
        'cumplimiento_aic': criterios['aic'],
      });
    } else {
      await _client.from('aca_boletin_detalle').update({
        'apropiacion_contenidos': criterios['apropiacion'] ?? detalle['apropiacion_contenidos'],
        'resolucion_actividades': criterios['resolucion'] ?? detalle['resolucion_actividades'],
        'participacion_clases': criterios['participacion'] ?? detalle['participacion_clases'],
        'planteos_dudas': criterios['dudas'] ?? detalle['planteos_dudas'],
        'entrega_actividades': criterios['entrega'] ?? detalle['entrega_actividades'],
        'prolijidad_carpeta': criterios['prolijidad'] ?? detalle['prolijidad_carpeta'],
        'cumplimiento_aic': criterios['aic'] ?? detalle['cumplimiento_aic'],
      }).eq('detalle_id', detalle['detalle_id']);
    }
  }

  String calcularTEA_TEP_TED(double nota) {
    if (nota >= 7) return 'TEA';
    if (nota >= 4) return 'TEP';
    return 'TED';
  }

  Future<void> cerrarEtapaDocente(
    String boletinId,
    String materiaId,
    int etapa,
    List<String> actividadesSeleccionadas
  ) async {
    // 1. Obtener notas de esas actividades para este alumno y promediar
    final notas = await _client
        .from('aca_calificaciones')
        .select('nota_numerica')
        .inFilter('actividad_id', actividadesSeleccionadas); // Falta cruzar con alumno, simplificado por ahora

    // Para la lógica real cruzamos actividad y alumno. Como aquí no tenemos el alumnoId en el args, lo deduciremos del boletín o lo pasamos.
    // Asumiremos que el frontend nos pasa las calificaciones directamente o las promedia.
    // Dejaremos un helper si el frontend lo calcula.
  }

  Future<void> guardarPromedioEtapa(
    String boletinId,
    String materiaId,
    int etapa,
    double promedio
  ) async {
    final resumen = calcularTEA_TEP_TED(promedio);
    
    var detalle = await _client
        .from('aca_boletin_detalle')
        .select()
        .eq('boletin_id', boletinId)
        .eq('materia_id', materiaId)
        .maybeSingle();

    if (detalle == null) {
      await _client.from('aca_boletin_detalle').insert({
        'boletin_id': boletinId,
        'materia_id': materiaId,
        (etapa == 1 ? 'promedio_1_etapa' : 'promedio_2_etapa'): promedio,
        (etapa == 1 ? 'resumen_1_etapa' : 'resumen_2_etapa'): resumen,
      });
    } else {
      await _client.from('aca_boletin_detalle').update({
        (etapa == 1 ? 'promedio_1_etapa' : 'promedio_2_etapa'): promedio,
        (etapa == 1 ? 'resumen_1_etapa' : 'resumen_2_etapa'): resumen,
      }).eq('detalle_id', detalle['detalle_id']);
    }
  }

  Future<List<Map<String, dynamic>>> obtenerDetallesBoletin(String boletinId) async {
    final res = await _client
        .from('aca_boletin_detalle')
        .select('*, acad_materias(nombre_asignatura)')
        .eq('boletin_id', boletinId);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> guardarRubricasCualitativas(List<Map<String, dynamic>> rubricas) async {
    if (rubricas.isEmpty) return;
    await _client
        .from('aca_rubricas_cualitativas')
        .upsert(rubricas, onConflict: 'alumno_id, materia_id, etapa');
  }

  Future<void> guardarCierreEtapa(Map<String, dynamic> cierre) async {
    await _client.from('aca_cierres_etapa').upsert(cierre, onConflict: 'alumno_id, materia_id, etapa');
  }

  // ─── Rúbricas cualitativas por materia/etapa ──────────────────────────────

  /// Lee las rúbricas cualitativas guardadas para una materia y etapa concretas.
  Future<List<Map<String, dynamic>>> obtenerRubricasCualitativasPorMateria({
    required String materiaId,
    required String etapa,
  }) async {
    final response = await _client
        .from('aca_rubricas_cualitativas')
        .select('*')
        .eq('materia_id', materiaId)
        .eq('etapa', etapa);
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── Categorías por materia (grupos de calificación del docente) ──────────

  /// Devuelve las categorías de una materia específica MÁS las categorías globales
  /// (materia_id IS NULL, ej. Evidencias / Desempeño / Autoevaluación del seed).
  /// Así el docente siempre tiene al menos un grupo disponible para cargar notas,
  /// aunque aún no haya creado categorías propias para su materia.
  Future<List<Map<String, dynamic>>> obtenerCategoriasMateria(String materiaId) async {
    final response = await _client
        .from('aca_categorias_nota')
        .select('id, nombre, peso_porcentaje, materia_id')
        .or('materia_id.eq.$materiaId,materia_id.is.null')
        .order('nombre', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Crea una nueva categoría/grupo vinculada a una materia específica.
  Future<Map<String, dynamic>> crearCategoriaMateria({
    required String materiaId,
    required String nombre,
    required double pesoPorc,
  }) async {
    final res = await _client.from('aca_categorias_nota').insert({
      'materia_id': materiaId,
      'nombre': nombre,
      'peso_porcentaje': pesoPorc,
    }).select().single();
    return Map<String, dynamic>.from(res);
  }

  /// Elimina una categoría/grupo (solo las propias de la materia, no las globales).
  Future<void> eliminarCategoriaMateria(String categoriaId) async {
    await _client.from('aca_categorias_nota').delete().eq('id', categoriaId);
  }

  // ─── Configuración de modo de calificación por materia ────────────────────

  /// Obtiene el modo de calificación guardado para una materia.
  /// Retorna 'GRUPOS' (por defecto) o 'PORCENTAJE'.
  Future<String> obtenerModoCalificacion(String materiaId) async {
    try {
      final res = await _client
          .from('aca_config_materia')
          .select('modo_calificacion')
          .eq('materia_id', materiaId)
          .maybeSingle();
      return res?['modo_calificacion']?.toString() ?? 'GRUPOS';
    } catch (_) {
      return 'GRUPOS';
    }
  }

  /// Guarda (upsert) el modo de calificación para una materia.
  Future<void> guardarModoCalificacion(String materiaId, String modo) async {
    await _client.from('aca_config_materia').upsert({
      'materia_id': materiaId,
      'modo_calificacion': modo,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'materia_id');
  }
}

