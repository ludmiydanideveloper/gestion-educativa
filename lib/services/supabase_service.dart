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

    final response = await _client.from('asistencia_cabecera').insert({
      'curso_id': cursoId,
      'fecha': fecha.toIso8601String().substring(0, 10), // Formato YYYY-MM-DD
      'estado': 'APROBADO', // Planilla aprobada
      'registrado_por_docente_id': finalDocenteId,
      'materia_id': materiaId,
      'tipo_asistencia': materiaId != null ? 'POR_MATERIA' : tipoAsistencia,
    }).select('asistencia_cabecera_id').single();

    // Notificar a Administración / Dirección sobre la toma de asistencia
    obtenerAuthIdsAdministracion().then((adminIds) {
      notificarSistema(
        asunto: 'Movimiento Escolar: Toma de Asistencia (${fecha.toIso8601String().substring(0, 10)})',
        texto: 'Se ha registrado la planilla de asistencia ($tipoAsistencia) en el curso.',
        destinatariosAuthIds: adminIds,
      );
    });

    return response['asistencia_cabecera_id'] as String;
  }

  /// Inserta de forma masiva (bulk insert) todos los detalles de asistencia
  Future<void> insertDetalles(String cabeceraId, List<AlumnoAsistencia> alumnos) async {
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

  /// Crea una nueva actividad académica para una materia y categoría específica
  Future<Map<String, dynamic>> crearActividad({
    required String materiaId,
    required String categoriaId,
    required String titulo,
    required DateTime fecha,
  }) async {
    final docenteId = await obtenerDocenteIdActual();
    
    final response = await _client.from('aca_actividades').insert({
      'docente_id': docenteId,
      'materia_id': materiaId,
      'categoria_id': categoriaId,
      'titulo': titulo,
      'fecha': fecha.toIso8601String().substring(0, 10),
    }).select().single();
    
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

  /// Obtiene todas las actividades creadas para una materia específica
  Future<List<Map<String, dynamic>>> obtenerActividades(String materiaId) async {
    final response = await _client
        .from('aca_actividades')
        .select('id, docente_id, materia_id, categoria_id, titulo, fecha, aca_categorias_nota(nombre, peso_porcentaje)')
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

      if (materias.isEmpty) return {'materias': [], 'actividades': [], 'calificaciones': [], 'categorias': []};

      final materiaIds = materias.map((m) => m['materia_id'] as String).toList();

      final catRes = await _client.from('aca_categorias_nota').select('id, materia_id, nombre, peso_porcentaje').inFilter('materia_id', materiaIds);
      final categorias = List<Map<String, dynamic>>.from(catRes);

      final actRes = await _client.from('aca_actividades').select('id, materia_id, categoria_id, titulo, fecha').inFilter('materia_id', materiaIds);
      final actividades = List<Map<String, dynamic>>.from(actRes);

      if (actividades.isEmpty) return {'materias': materias, 'actividades': [], 'calificaciones': [], 'categorias': categorias};

      final actIds = actividades.map((a) => a['id'] as String).toList();

      var queryCalif = _client.from('aca_calificaciones').select('id, actividad_id, alumno_id, nota_numerica').inFilter('actividad_id', actIds);
      if (alumnosIds != null && alumnosIds.isNotEmpty) {
        queryCalif = queryCalif.inFilter('alumno_id', alumnosIds);
      }
      final califRes = await queryCalif;
      final calificaciones = List<Map<String, dynamic>>.from(califRes);

      return {
        'materias': materias,
        'actividades': actividades,
        'calificaciones': calificaciones,
        'categorias': categorias,
      };
    } catch (e) {
      print('Error al obtener datos del boletín completo: $e');
      return {'materias': [], 'actividades': [], 'calificaciones': [], 'categorias': []};
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
  Future<List<Map<String, dynamic>>> obtenerCalendarioPorCurso(String? cursoId, {bool soloPublicos = true}) async {
    try {
      dynamic query = _client.from('acad_calendario').select('*');
      if (cursoId != null && cursoId.isNotEmpty) {
        // Traer eventos generales (null) o del curso específico
        query = query.or('curso_id.eq.$cursoId,curso_id.is.null');
      } else {
        query = query.isFilter('curso_id', null);
      }
      final response = await query.order('fecha', ascending: true);
      final lista = List<Map<String, dynamic>>.from(response);

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

  /// Crea un nuevo evento de calendario. Disparará el trigger de notificación.
  Future<void> crearEventoCalendario({
    required String titulo,
    required String descripcion,
    required String fecha,
    required String tipoEvento,
    String? cursoId,
    bool esInterno = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final finalTitulo = esInterno && !titulo.startsWith('[INTERNO]') ? '[INTERNO] $titulo' : titulo;
    final finalDesc = esInterno && !descripcion.startsWith('[INTERNO]') ? '[INTERNO] $descripcion' : descripcion;

    try {
      await _client.from('acad_calendario').insert({
        'titulo': finalTitulo,
        'descripcion': finalDesc,
        'fecha': fecha,
        'tipo_evento': tipoEvento,
        'curso_id': (cursoId != null && cursoId.isNotEmpty) ? cursoId : null,
      });
    } catch (e) {
      String dbTipo = tipoEvento.toUpperCase();
      if (dbTipo.contains('EVALUAC')) dbTipo = 'EVALUACION';
      else if (dbTipo.contains('REUNI')) dbTipo = 'REUNION';
      else dbTipo = 'ACTIVIDAD';

      await _client.from('acad_calendario').insert({
        'titulo': finalTitulo,
        'descripcion': '$finalDesc [Cat: $tipoEvento]',
        'fecha': fecha,
        'tipo_evento': dbTipo,
        'curso_id': (cursoId != null && cursoId.isNotEmpty) ? cursoId : null,
      });
    }
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
        final res = await _client.from('usr_legajos').select('auth_id, rol');
        for (var r in res) {
          final rol = r['rol']?.toString().toUpperCase() ?? '';
          if (r['auth_id'] != null && (rol == 'PRECEPTOR' || rol == 'ADMIN' || rol == 'DIRECTIVO')) {
            authIds.add(r['auth_id'].toString());
          }
        }
      }
      if (destinatariosRoles.contains('Alumnos de 1° SEC') || destinatariosRoles.contains('Alumnos de 2° SEC') || destinatariosRoles.contains('Familias / Tutores')) {
        final res = await _client.from('usr_alumnos').select('auth_id');
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

  /// Registra el temario dictado usando la tabla acad_calendario con un tipo especial
  Future<void> registrarTemario({
    required String cursoId,
    required String materiaId,
    required String materiaNombre,
    required String tema,
    required String fecha,
  }) async {
    await _client.from('acad_calendario').insert({
      'titulo': materiaNombre,
      'descripcion': tema,
      'fecha': fecha,
      'tipo_evento': 'TEMARIO',
      'curso_id': cursoId,
    });
  }

  /// Obtiene los temarios cargados para un curso específico
  Future<List<Map<String, dynamic>>> obtenerTemarios({String? cursoId}) async {
    try {
      var query = _client
          .from('acad_calendario')
          .select('*')
          .eq('tipo_evento', 'TEMARIO');
      if (cursoId != null) {
        query = query.eq('curso_id', cursoId);
      }
      final response = await query.order('fecha', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener temarios: $e');
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

  Future<void> guardarArchivoPersonal({
    required String authId,
    required String tipoArchivo, // 'DDJJ' o 'CV'
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

    await _client.from('usr_archivos_personal').insert({
      'auth_id': authId,
      'docente_id': docenteId,
      'tipo_archivo': tipoArchivo,
      'nombre_archivo': nombreArchivo,
      'formato': formato,
      'datos_base64': base64Data,
      'fecha_subida': DateTime.now().toIso8601String(),
    });
  }

  Future<void> eliminarArchivoPersonal(String archivoId) async {
    await _client.from('usr_archivos_personal').delete().eq('id', archivoId);
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
          .eq('legajo_id', legajoId)
          .order('anio_origen', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
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
        .eq('id', id);
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
}
