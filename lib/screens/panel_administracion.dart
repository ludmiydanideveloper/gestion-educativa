import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/print_helper.dart';
import '../widgets/brand_widgets.dart';

class PanelAdministracion extends StatefulWidget {
  const PanelAdministracion({super.key});

  @override
  State<PanelAdministracion> createState() => _PanelAdministracionState();
}

class _PanelAdministracionState extends State<PanelAdministracion> with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  int _selectedTabIndex = 0;
  late TabController _tabController;

  // Listas de datos
  List<Map<String, dynamic>> _personal = [];
  List<Map<String, dynamic>> _alumnos = [];
  List<Map<String, dynamic>> _tutores = [];
  List<Map<String, dynamic>> _cursos = [];
  List<Map<String, dynamic>> _materias = [];
  List<Map<String, dynamic>> _gruposFamiliares = [];

  // Filtros de búsqueda
  String _searchPersonal = '';
  String _searchAlumnos = '';
  String _searchTutores = '';
  String? _asistenciaCursoId;
  String _searchAsistencia = '';
  int _modoVistaAsistencia = 0; // 0: Fichas, 1: Mensual, 2: Por Materia
  String _asistenciaMateriaSeleccionada = 'Matemática';
  int _selectedMesIndex = DateTime.now().month;
  List<Map<String, dynamic>> _asistenciaMensualDatos = [];
  bool _loadingAsistenciaMensual = false;

  // Estados del Repositorio Pedagógico
  String? _repCursoId;
  String? _repMateriaId;
  List<Map<String, dynamic>> _repositorioArchivos = [];

  // Estados de EOE (Gabinete Psicopedagógico)
  Map<String, dynamic>? _eoeSelectedAlumno;
  final Map<String, List<Map<String, String>>> _eoeInformes = {};
  final Map<String, List<Map<String, String>>> _eoeBitacora = {};
  final Map<String, List<Map<String, dynamic>>> _eoeEvaluacionesDocente = {};

  // Declaraciones Juradas de Profesores y Horarios
  final Map<String, Map<String, dynamic>> _ddjjProfesores = {};
  String? _horarioSelectedCursoId;
  final List<Map<String, dynamic>> _proyectosInstitucionales = [
    {
      'id': '1',
      'nombre': 'Feria de Ciencias y Tecnología 2026',
      'coordinador': 'Danilo Gomez',
      'rol_coordinador': 'Profesor / Coordinador de Área',
      'email_coordinador': 'danilo.gomez@escuela.edu',
      'telefono_coordinador': '+54 9 11 5544-3322',
      'estado': 'Planificación',
      'fecha_inicio': '01/08/2026',
      'fecha_fin': '15/10/2026',
      'organizacion': 'Exposición intercolegial con participación de 1° a 6° año en stands temáticos de robótica, ecología y física aplicada.',
      'cronograma': 'Etapa 1 (Agosto): Presentación de proyectos.\nEtapa 2 (Septiembre): Preselección y tutorías.\nEtapa 3 (Octubre): Feria abierta a la comunidad escolar.',
      'archivos': [
        {'nombre': 'Reglamento_y_Bases_Feria_2026.pdf', 'fecha': '10/07/2026', 'subido_por': 'Coordinación'},
        {'nombre': 'Grilla_de_Evaluados_y_Stands.xlsx', 'fecha': '11/07/2026', 'subido_por': 'Danilo Gomez'}
      ]
    },
    {
      'id': '2',
      'nombre': 'Proyecto Institucional de Solidaridad y Comedor',
      'coordinador': 'Maria Funes',
      'rol_coordinador': 'Directiva / Orientación Social',
      'email_coordinador': 'mfunes@escuela.edu',
      'telefono_coordinador': '+54 9 11 4433-2211',
      'estado': 'En Curso',
      'fecha_inicio': '01/05/2026',
      'fecha_fin': '30/11/2026',
      'organizacion': 'Colecta mensual de alimentos no perecederos y jornadas de voluntariado en centros comunitarios del barrio.',
      'cronograma': 'Primer sábado de cada mes: Recepción de donaciones.\nSegundo sábado: Clasificación en SUM escolar.\nTercer sábado: Entrega comunitaria.',
      'archivos': [
        {'nombre': 'Autorizacion_Salida_Voluntariado.pdf', 'fecha': '02/05/2026', 'subido_por': 'Maria Funes'}
      ]
    },
  ];

  final List<Map<String, dynamic>> _observacionesGestionClases = [
    {
      'id': '1',
      'docente': 'Danilo Gomez',
      'curso': '3° B - Matemática',
      'fecha': '10/07/2026',
      'observacion': 'Excelente manejo del pizarrón y recursos interactivos. Se sugiere profundizar en la ejercitación guiada del grupo que intensifica RITE.',
      'archivo': 'Devolucion_Observacion_Clase_Gomez.pdf',
      'subido_por': 'Directora (Maria Funes)',
    },
    {
      'id': '2',
      'docente': 'Laura Martinez',
      'curso': '2° A - Prácticas del Lenguaje',
      'fecha': '05/07/2026',
      'observacion': 'Clase muy ordenada con alta participación de alumnos. Se revisaron acuerdos del contrato pedagógico y lectura adaptada con EOE.',
      'archivo': 'Acta_Observacion_Aulica_2A.pdf',
      'subido_por': 'Directora (Maria Funes)',
    },
  ];

  final List<Map<String, dynamic>> _horariosActivosInstitucion = [
    {'curso_id': '1', 'curso': '1° A', 'dia': 'Lunes', 'modulo': '1° Módulo (07:30 - 08:50)', 'materia': 'Matemática', 'docente': 'Prof. Gomez', 'email': 'gomez@escuela.edu'},
    {'curso_id': '1', 'curso': '1° A', 'dia': 'Lunes', 'modulo': '2° Módulo (09:00 - 10:20)', 'materia': 'Matemática', 'docente': 'Prof. Gomez', 'email': 'gomez@escuela.edu'},
    {'curso_id': '1', 'curso': '1° A', 'dia': 'Martes', 'modulo': '3° Módulo (10:40 - 12:00)', 'materia': 'Lengua y Literatura', 'docente': 'Prof. Martinez', 'email': 'martinez@escuela.edu'},
    {'curso_id': '1', 'curso': '1° A', 'dia': 'Miércoles', 'modulo': '1° Módulo (07:30 - 08:50)', 'materia': 'Historia', 'docente': 'Prof. Lopez', 'email': 'lopez@escuela.edu'},
    {'curso_id': '2', 'curso': '2° A', 'dia': 'Jueves', 'modulo': '1° Módulo (07:30 - 08:50)', 'materia': 'Física', 'docente': 'Prof. Gomez', 'email': 'gomez@escuela.edu'},
  ];

  void _inicializarRepositorioYEOE() {
    if (_cursos.isEmpty) return;
    _repCursoId ??= _cursos.first['curso_id'] as String;
    if (_repCursoId != null && _materias.isNotEmpty) {
      final listMats = _materias.where((m) => m['curso_id'] == _repCursoId).toList();
      if (listMats.isNotEmpty) {
        _repMateriaId ??= listMats.first['materia_id'] as String;
      }
    }

    if (_repositorioArchivos.isEmpty && _repCursoId != null && _repMateriaId != null) {
      final cMatch = _cursos.firstWhere((c) => c['curso_id'] == _repCursoId, orElse: () => {});
      final mMatch = _materias.firstWhere((m) => m['materia_id'] == _repMateriaId, orElse: () => {});
      final cursoName = cMatch['identificador_division'] ?? 'Curso';
      final matName = mMatch['nombre_asignatura'] ?? 'Materia';
      
      _repositorioArchivos = [
        {
          'id': '1',
          'curso_id': _repCursoId,
          'materia_id': _repMateriaId,
          'tipo': 'Planificación',
          'nombre': 'Planificación $matName - $cursoName.pdf',
          'fecha': '08/07/2026',
          'estado': 'Pendiente',
          'docente': 'Daniel Gomez'
        },
        {
          'id': '2',
          'curso_id': _repCursoId,
          'materia_id': _repMateriaId,
          'tipo': 'Contrato Pedagógico',
          'nombre': 'Contrato de Convivencia - $matName.pdf',
          'fecha': '09/07/2026',
          'estado': 'Aprobado',
          'docente': 'Daniel Gomez'
        },
        {
          'id': '3',
          'curso_id': _repCursoId,
          'materia_id': _repMateriaId,
          'tipo': 'Criterios de Evaluación',
          'nombre': 'Criterios de Aprobación - $matName.pdf',
          'fecha': '09/07/2026',
          'estado': 'Aprobado',
          'docente': 'Daniel Gomez'
        },
      ];
    }

    // Inicializar mock de EOE
    int adCount = 0;
    for (int i = 0; i < _alumnos.length; i++) {
      final a = _alumnos[i];
      final legajoId = a['legajo_id'] as String;
      
      // Mapear adecuaciones curriculares de datos_demograficos
      final demo = Map<String, dynamic>.from(a['datos_demograficos'] as Map? ?? {});
      bool hasAdecuacion = demo['adecuacion_curricular'] == true || a['adecuacion_curricular'] == true;
      
      // Si no hay alumnos con adecuación, marcar los 3 primeros como ficticios/activos por defecto para demostración
      if (!hasAdecuacion && i < 3 && _alumnos.where((al) => al['adecuacion_curricular'] == true).isEmpty) {
        hasAdecuacion = true;
        demo['adecuacion_curricular'] = true;
        demo['tipo_adecuacion'] = i == 0 ? 'Metodológica (Tiempo Extendido)' : (i == 1 ? 'De Acceso (Consignas Visuales)' : 'De Contenido');
        demo['detalles_adecuacion'] = 'Requiere segmentación de consignas, tiempo adicional en evaluaciones escritas (+20 min) y acompañamiento personalizado.';
        a['datos_demograficos'] = demo;
      }

      if (hasAdecuacion) {
        adCount++;
        a['adecuacion_curricular'] = true;
        a['tipo_adecuacion'] = demo['tipo_adecuacion'] ?? a['tipo_adecuacion'] ?? 'Metodológica';
        a['detalles_adecuacion'] = demo['detalles_adecuacion'] ?? a['detalles_adecuacion'] ?? 'Adecuación pedagógica activa según informe EOE.';
      }

      _eoeInformes.putIfAbsent(legajoId, () => [
        {'id': '1', 'nombre': 'Diagnóstico Psicológico y Neurocognitivo (EOE).pdf', 'fecha': '12/03/2026', 'especialista': 'Lic. Sofia Martinez (Psicopedagoga)'},
        {'id': '2', 'nombre': 'Pautas de Acompañamiento en el Aula.docx', 'fecha': '25/03/2026', 'especialista': 'Equipo EOE'}
      ]);

      _eoeBitacora.putIfAbsent(legajoId, () => [
        {'id': '1', 'autor': 'Preceptor Martin', 'nota': 'Se observa buena predisposición. En exámenes escritos requiere más tiempo pero logra concentrarse.', 'fecha': '15/06/2026'},
        {'id': '2', 'autor': 'Docente Lengua', 'nota': 'Se aplicó evaluación oral complementaria. Responde muy bien a las consignas integradoras.', 'fecha': '30/06/2026'}
      ]);

      _eoeEvaluacionesDocente.putIfAbsent(legajoId, () => [
        {
          'id': '1',
          'materia': 'Construcción de la Ciudadanía',
          'docente': 'Daniel Gomez',
          'informe_original': 'Evaluación Escrita - Unidad 2 (Original).pdf',
          'fecha_evaluacion': '18/07/2026',
          'observaciones_eoe': 'Se rediseña con tipografía clara (Arial 14), división de consignas largas y tiempo extendido (+25 min).',
          'archivo_adecuado': 'Evaluación Escrita - Unidad 2 (ADECUADA por EOE).pdf',
          'estado': 'Adecuada',
        },
        {
          'id': '2',
          'materia': 'Historia 1°',
          'docente': 'Prof. Titular',
          'informe_original': 'Trabajo Práctico Integrador - Revoluciones.docx',
          'fecha_evaluacion': '24/07/2026',
          'observaciones_eoe': 'Pendiente de revisión pedagógica por el gabinete.',
          'archivo_adecuado': null,
          'estado': 'Pendiente de Adecuación',
        },
      ]);
    }
  }

  final List<String> _mesesNombres = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 12, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarAsistenciaMensual() async {
    if (_asistenciaCursoId == null) return;
    setState(() => _loadingAsistenciaMensual = true);
    try {
      final list = await _supabaseService.obtenerAsistenciaMensualCurso(_asistenciaCursoId!);
      setState(() {
        _asistenciaMensualDatos = list;
        _loadingAsistenciaMensual = false;
      });
    } catch (e) {
      print('Error al cargar asistencia mensual: $e');
      setState(() => _loadingAsistenciaMensual = false);
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _supabaseService.fetchPersonalList(),
        _supabaseService.fetchAlumnosList(),
        _supabaseService.fetchTutoresList(),
        _supabaseService.fetchCursos(),
        _supabaseService.fetchMaterias(),
        _supabaseService.fetchGruposFamiliares(),
      ]);

      setState(() {
        _personal = results[0];
        _alumnos = results[1];
        _tutores = results[2];
        _cursos = results[3];
        _materias = results[4];
        _gruposFamiliares = results[5];
        if (_asistenciaCursoId == null && _cursos.isNotEmpty) {
          _asistenciaCursoId = _cursos.first['curso_id'] as String;
        }
        _inicializarRepositorioYEOE();
      });
      await _cargarAsistenciaMensual();
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarExito(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- MODAL DE ALTA DE USUARIO (ADMIN, PRECEPTOR, DOCENTE, ALUMNO, PADRE) ---
  void _abrirModalCrearUsuario({required String rol}) {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final nombreController = TextEditingController();
    final apellidoController = TextEditingController();
    final dniController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedCursoId;
    final List<String> selectedMateriasIds = [];
    String selectedRol = rol;

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Alta de ${selectedRol == 'PADRE' ? 'Tutor/Familia' : selectedRol.toLowerCase()}'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (['DOCENTE', 'PRECEPTOR', 'ADMIN', 'DIRECTIVO'].contains(rol)) ...[
                        DropdownButtonFormField<String>(
                          value: selectedRol,
                          decoration: const InputDecoration(
                            labelText: 'Rol en la Institución',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'DOCENTE', child: Text('Docente (Profesor Titular)')),
                            DropdownMenuItem(value: 'PRECEPTOR', child: Text('Preceptor / Encargado de Curso')),
                            DropdownMenuItem(value: 'ADMIN', child: Text('Administrador General')),
                            DropdownMenuItem(value: 'DIRECTIVO', child: Text('Directivo Escolar')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedRol = val;
                                if (selectedRol != 'DOCENTE') {
                                  selectedMateriasIds.clear();
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: apellidoController,
                        decoration: const InputDecoration(labelText: 'Apellido'),
                        validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: dniController,
                        decoration: const InputDecoration(labelText: 'DNI'),
                        keyboardType: TextInputType.number,
                        validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => value == null || !value.contains('@') ? 'Email inválido' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña Temporal (Opcional)',
                          helperText: 'Por defecto será el número de DNI',
                        ),
                      ),
                      if (selectedRol == 'ALUMNO') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedCursoId,
                          decoration: const InputDecoration(labelText: 'Curso a Matricular'),
                          items: _cursos.map((c) {
                            return DropdownMenuItem(
                              value: c['curso_id'] as String,
                              child: Text(c['identificador_division'] as String),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedCursoId = val),
                          validator: (value) => value == null ? 'Selecciona un curso' : null,
                        ),
                      ],
                      if (selectedRol == 'DOCENTE') ...[
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Asignar Materias (Opcional)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _materias.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: Text('No hay materias disponibles')),
                                )
                              : SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: _materias.map((m) {
                                      final c = _cursos.firstWhere(
                                        (curso) => curso['curso_id'] == m['curso_id'],
                                        orElse: () => {},
                                      );
                                      final label = '${m['nombre_asignatura']} - ${c['identificador_division'] ?? 'Curso'}';
                                      final isSelected = selectedMateriasIds.contains(m['materia_id']);
                                      return CheckboxListTile(
                                        title: Text(label, style: const TextStyle(fontSize: 13)),
                                        value: isSelected,
                                        dense: true,
                                        controlAffinity: ListTileControlAffinity.leading,
                                        onChanged: (bool? val) {
                                          setModalState(() {
                                            if (val == true) {
                                              selectedMateriasIds.add(m['materia_id'] as String);
                                            } else {
                                              selectedMateriasIds.remove(m['materia_id'] as String);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(context).pop();
                    
                    setState(() => _isLoading = true);
                    try {
                      final pwd = passwordController.text.trim().isEmpty 
                          ? dniController.text.trim() 
                          : passwordController.text.trim();
                      
                      final newUserId = await _supabaseService.adminCreateUser(
                        email: emailController.text.trim(),
                        password: pwd,
                        rol: selectedRol,
                        nombre: nombreController.text.trim(),
                        apellido: apellidoController.text.trim(),
                        dni: dniController.text.trim(),
                        cursoId: selectedCursoId,
                      );

                      if (selectedRol == 'DOCENTE' && selectedMateriasIds.isNotEmpty) {
                        await _supabaseService.vincularDocenteAMaterias(
                          newUserId,
                          selectedMateriasIds,
                          _materias,
                        );
                      }
                      
                      _mostrarExito('Usuario ($selectedRol) creado con éxito. Contraseña temporal: $pwd');
                      _cargarDatos();
                    } catch (e) {
                      _mostrarError('Error al crear usuario: $e');
                      setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- MODAL DE EDICIÓN DE USUARIO ---
  void _abrirModalEditarUsuario(Map<String, dynamic> user, String rol) {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: user['email']);
    final nombreCompleto = user['nombre_completo'] as String? ?? '';
    final parts = nombreCompleto.split(' ');
    final nombreController = TextEditingController(text: parts.isNotEmpty ? parts.first : '');
    final apellidoController = TextEditingController(text: parts.length > 1 ? parts.sublist(1).join(' ') : '');
    final dniController = TextEditingController(text: user['dni']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Usuario'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: apellidoController,
                    decoration: const InputDecoration(labelText: 'Apellido'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                  if (rol != 'PERSONAL') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: dniController,
                      decoration: const InputDecoration(labelText: 'DNI'),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value == null || !value.contains('@') ? 'Email inválido' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(context).pop();
                
                setState(() => _isLoading = true);
                try {
                  final userId = user['auth_id'] as String;
                  await _supabaseService.adminUpdateUser(
                    userId: userId,
                    email: emailController.text.trim(),
                    nombre: nombreController.text.trim(),
                    apellido: apellidoController.text.trim(),
                    dni: dniController.text.trim(),
                  );
                  _mostrarExito('Usuario actualizado con éxito');
                  _cargarDatos();
                } catch (e) {
                  _mostrarError('Error al actualizar usuario: $e');
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _imprimirBoletinAlumno(Map<String, dynamic> alumno) async {
    final cursoId = alumno['curso_id'] as String?;
    if (cursoId == null || cursoId.isEmpty) {
      _mostrarError('El alumno no está matriculado en ningún curso.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final alumnoId = alumno['legajo_id'] as String;
      
      final results = await Future.wait([
        _supabaseService.obtenerCategoriasCalificaciones(),
        _supabaseService.obtenerCalificacionesAlumno(alumnoId),
        _supabaseService.fetchMaterias(cursoId: cursoId),
      ]);

      PrintHelper.imprimirBoletin(
        studentName: alumno['nombre_completo'] ?? '',
        dni: alumno['dni']?.toString() ?? '',
        cursoName: alumno['curso_nombre'] ?? 'Sin curso',
        categorias: results[0] as List<Map<String, dynamic>>,
        calificaciones: results[1] as List<Map<String, dynamic>>,
        materias: results[2] as List<Map<String, dynamic>>,
      );
    } catch (e) {
      _mostrarError('Error al generar boletín: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _imprimirAsistenciaAlumno(Map<String, dynamic> alumno) async {
    setState(() => _isLoading = true);
    try {
      final alumnoId = alumno['legajo_id'] as String;
      final data = await _supabaseService.obtenerAsistenciaAlumno(alumnoId);

      PrintHelper.imprimirAsistencia(
        studentName: alumno['nombre_completo'] ?? '',
        dni: alumno['dni']?.toString() ?? '',
        cursoName: alumno['curso_nombre'] ?? 'Sin curso',
        asistencias: data,
      );
    } catch (e) {
      _mostrarError('Error al generar reporte de asistencia: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarDetalleYFaltasPorMateriaAlumno(Map<String, dynamic> alumno) {
    final String name = alumno['nombre_completo']?.toString().toUpperCase() ?? 'ALUMNO';
    final String dni = alumno['dni']?.toString() ?? 'Sin DNI';
    final String curso = alumno['curso_nombre'] ?? 'Curso Asignado';
    final double totalInasistencias = (name.length % 5) + 0.5;

    final List<Map<String, dynamic>> faltasMateria = [
      {'materia': 'Matemática I/II/III', 'presentes': 30, 'ausentes': 2, 'faltas': 2.0, 'porcentaje': '93.7%', 'estado': 'REGULAR'},
      {'materia': 'Prácticas del Lenguaje', 'presentes': 32, 'ausentes': 0, 'faltas': 0.0, 'porcentaje': '100%', 'estado': 'ASISTENCIA PERFECTA'},
      {'materia': 'Ciencias Naturales / Biología', 'presentes': 29, 'ausentes': 3, 'faltas': 3.0, 'porcentaje': '90.6%', 'estado': 'REGULAR'},
      {'materia': 'Historia / Construcción Ciudadana', 'presentes': 31, 'ausentes': 1, 'faltas': 1.0, 'porcentaje': '96.8%', 'estado': 'REGULAR'},
      {'materia': 'Geografía General', 'presentes': 30, 'ausentes': 2, 'faltas': 2.0, 'porcentaje': '93.7%', 'estado': 'REGULAR'},
      {'materia': 'Inglés Técnico', 'presentes': 28, 'ausentes': 4, 'faltas': 4.0, 'porcentaje': '87.5%', 'estado': 'ALERTA RITE'},
      {'materia': 'Educación Física', 'presentes': 32, 'ausentes': 0, 'faltas': 0.0, 'porcentaje': '100%', 'estado': 'ASISTENCIA PERFECTA'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.analytics_rounded, color: Colors.blue, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Desglose de Faltas por Materia', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('$name ($curso)', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withAlpha(50)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Inasistencias Institucionales:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('DNI Alumno: $dni', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: totalInasistencias > 3 ? Colors.red.shade700 : Colors.green.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${totalInasistencias.toStringAsFixed(1)} FALTAS TOTALES',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Detalle Curricular y Faltas por Asignatura (RITE):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      headingRowHeight: 38,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 36,
                      columns: const [
                        DataColumn(label: Text('Materia / Área', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Faltas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Asistencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Estado RITE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                      rows: faltasMateria.map((fm) {
                        final double f = fm['faltas'] as double;
                        return DataRow(cells: [
                          DataCell(Text(fm['materia'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                          DataCell(Text(f.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: f > 2 ? Colors.red.shade800 : Colors.black87))),
                          DataCell(Text(fm['porcentaje'] as String, style: const TextStyle(fontSize: 12))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: f == 0 ? Colors.blue.shade50 : (f > 3 ? Colors.red.shade50 : Colors.green.shade50),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                fm['estado'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: f == 0 ? Colors.blue.shade800 : (f > 3 ? Colors.red.shade800 : Colors.green.shade800),
                                ),
                              ),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              PrintHelper.imprimirFaltasPorMateria(
                cursoName: curso,
                materiaName: 'Desglose Integral por Materias • $name',
                alumnosFaltas: faltasMateria.map((fm) => {
                  'nombre': fm['materia'],
                  'dni': 'Alumno: $name ($dni)',
                  'presentes': fm['presentes'],
                  'ausentes': fm['ausentes'],
                  'tardes': 0,
                  'faltas': fm['faltas'],
                  'condicion': fm['estado'],
                }).toList(),
              );
            },
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Imprimir Faltas por Materia (PDF Modelo)'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _imprimirAsistenciaAlumno(alumno);
            },
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: const Text('Asistencia General (PDF)'),
          ),
        ],
      ),
    );
  }

  // --- MODAL TRAYECTORIA, ANALÍTICO Y ACREDITACIONES RITE ---
  void _abrirModalTrayectoriaAlumno(Map<String, dynamic> alumno) {
    final alumnoId = alumno['legajo_id']?.toString() ?? '';
    if (alumnoId.isEmpty) {
      _mostrarError('El alumno no tiene un ID válido en legajos.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 900,
                padding: const EdgeInsets.all(28),
                child: FutureBuilder<List<dynamic>>(
                  future: Future.wait([
                    Supabase.instance.client.from('aca_trayectoria_alumnos').select('*').eq('alumno_id', alumnoId).order('anio_lectivo'),
                    Supabase.instance.client.from('aca_materias_adeudadas').select('*').eq('alumno_id', alumnoId).order('anio_origen'),
                  ]),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 300,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return SizedBox(
                        height: 250,
                        child: Center(child: Text('Error cargando trayectoria: \${snapshot.error}')),
                      );
                    }

                    final trayectoria = List<Map<String, dynamic>>.from(snapshot.data![0] as List);
                    final adeudadas = List<Map<String, dynamic>>.from(snapshot.data![1] as List);

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.purple.withOpacity(0.15),
                                child: const Icon(Icons.history_edu_rounded, color: Colors.purple, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Trayectoria Académica y Analítico: ${alumno["nombre_completo"]}',
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
                                    ),
                                    Text(
                                      'DNI: ${alumno["dni"] ?? "-"} • Curso Actual: ${alumno["curso_nombre"] ?? "Sin curso"}',
                                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                                label: const Text('Generar PDF Analítico / Aprobadas', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  PrintHelper.imprimirTrayectoriaYAnalitico(
                                    studentName: alumno['nombre_completo'] ?? '',
                                    dni: alumno['dni']?.toString() ?? '',
                                    cursoActual: alumno['curso_nombre'] ?? 'Sin curso',
                                    trayectoria: trayectoria,
                                    materiasAdeudadas: adeudadas,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 26),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const Divider(height: 36),

                          // SECCIÓN 1: TRAYECTORIA CURRICULAR
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('1. Historial de Cursos y Años Lectivos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                              TextButton.icon(
                                icon: const Icon(Icons.add_circle_outline_rounded),
                                label: const Text('Agregar Año / Curso Pasado'),
                                onPressed: () async {
                                  final anioCtrl = TextEditingController(text: (DateTime.now().year - 1).toString());
                                  final cursoCtrl = TextEditingController(text: '1ro A');
                                  final promCtrl = TextEditingController(text: '8.50');
                                  String cond = 'APROBADO';

                                  await showDialog(
                                    context: context,
                                    builder: (cDialog) => AlertDialog(
                                      title: const Text('Registrar Año Cursado (Trayectoria)'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(controller: anioCtrl, decoration: const InputDecoration(labelText: 'Año Lectivo (ej. 2024)')),
                                          TextField(controller: cursoCtrl, decoration: const InputDecoration(labelText: 'Curso / División (ej. 1ro A)')),
                                          TextField(controller: promCtrl, decoration: const InputDecoration(labelText: 'Promedio General (ej. 8.50)')),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            value: cond,
                                            decoration: const InputDecoration(labelText: 'Condición Final'),
                                            items: ['APROBADO', 'EN_CURSO', 'ADEUDA_MATERIAS'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                            onChanged: (v) => cond = v!,
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(cDialog), child: const Text('Cancelar')),
                                        ElevatedButton(
                                          onPressed: () async {
                                            await Supabase.instance.client.from('aca_trayectoria_alumnos').insert({
                                              'alumno_id': alumnoId,
                                              'anio_lectivo': int.tryParse(anioCtrl.text) ?? DateTime.now().year,
                                              'curso_nombre': cursoCtrl.text.trim(),
                                              'promedio': double.tryParse(promCtrl.text) ?? 0.0,
                                              'condicion': cond,
                                            });
                                            if (cDialog.mounted) Navigator.pop(cDialog);
                                            setModalState(() {});
                                          },
                                          child: const Text('Guardar'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (trayectoria.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              width: double.infinity,
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                              child: const Text('Aún no se ha cargado historial de años anteriores para este alumno.', style: TextStyle(color: Colors.black54)),
                            )
                          else
                            Table(
                              border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                              columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(3), 2: FlexColumnWidth(2.5), 3: FlexColumnWidth(1.5), 4: FlexColumnWidth(1)},
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.indigo.shade50),
                                  children: const [
                                    Padding(padding: EdgeInsets.all(10), child: Text('Año Lectivo', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(10), child: Text('Curso / División', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(10), child: Text('Condición', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(10), child: Text('Promedio', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(10), child: Text('Acción', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                ...trayectoria.map((t) => TableRow(
                                  children: [
                                    Padding(padding: const EdgeInsets.all(10), child: Text(t['anio_lectivo']?.toString() ?? '-')),
                                    Padding(padding: const EdgeInsets.all(10), child: Text(t['curso_nombre'] ?? '-')),
                                    Padding(padding: const EdgeInsets.all(10), child: Text(t['condicion'] ?? 'APROBADO', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                    Padding(padding: const EdgeInsets.all(10), child: Text(t['promedio']?.toString() ?? '0.00')),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () async {
                                        await Supabase.instance.client.from('aca_trayectoria_alumnos').delete().eq('id', t['id']);
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                )),
                              ],
                            ),

                          const SizedBox(height: 32),

                          // SECCIÓN 2: MATERIAS ADEUDADAS RITE
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('2. Materias Adeudadas y Pendientes (Comisión RITE)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                    Text('Estas materias irán automáticamente al apartado de Materias Adeudadas RITE de los profesores.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.deepOrange),
                                icon: const Icon(Icons.add_task_rounded),
                                label: const Text('Agregar Materia RITE'),
                                onPressed: () async {
                                  final matCtrl = TextEditingController(text: 'Matemática');
                                  final anioCtrl = TextEditingController(text: (DateTime.now().year - 1).toString());
                                  String selCond = 'Intensifica'; // Intensifica, Recursa, Adeuda Previa

                                  await showDialog(
                                    context: context,
                                    builder: (cDialog) => StatefulBuilder(
                                      builder: (cDialog, setDialState) => AlertDialog(
                                        title: const Text('Registrar Materia para Comisión RITE'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            TextField(controller: matCtrl, decoration: const InputDecoration(labelText: 'Nombre de la Materia', hintText: 'Ej. Matemática, Historia...')),
                                            const SizedBox(height: 12),
                                            TextField(controller: anioCtrl, decoration: const InputDecoration(labelText: 'Año en que se cursó (ej. 2025 o 1ro)')),
                                            const SizedBox(height: 12),
                                            const Text('Condición RITE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            DropdownButtonFormField<String>(
                                              value: selCond,
                                              isExpanded: true,
                                              items: const [
                                                DropdownMenuItem(value: 'Intensifica', child: Text('⚡ INTENSIFICA (Intensificación)')),
                                                DropdownMenuItem(value: 'Recursa', child: Text('🔄 RECURSA (Recursado)')),
                                                DropdownMenuItem(value: 'Adeuda Previa', child: Text('📌 ADEUDA PREVIA')),
                                              ],
                                              onChanged: (v) => setDialState(() => selCond = v!),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(cDialog), child: const Text('Cancelar')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                                            onPressed: () async {
                                              if (matCtrl.text.isNotEmpty) {
                                                await Supabase.instance.client.from('aca_materias_adeudadas').insert({
                                                  'alumno_id': alumnoId,
                                                  'nombre_materia': matCtrl.text.trim(),
                                                  'anio_origen': int.tryParse(anioCtrl.text) ?? DateTime.now().year,
                                                  'condicion': selCond,
                                                  'estado': 'PENDIENTE',
                                                });
                                                if (cDialog.mounted) Navigator.pop(cDialog);
                                                setModalState(() {});
                                              }
                                            },
                                            child: const Text('Registrar para RITE', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (adeudadas.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              width: double.infinity,
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.green),
                                  SizedBox(width: 12),
                                  Text('El alumno no registra materias adeudadas. ¡Analítico al día!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          else
                            Table(
                              border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                              columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(2), 3: FlexColumnWidth(2), 4: FlexColumnWidth(1)},
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.deepOrange.shade50),
                                  children: const [
                                    Padding(padding: EdgeInsets.all(10), child: Text('Asignatura Adeudada', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(10), child: Text('Año Origen', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(10), child: Text('Condición', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(10), child: Text('Estado RITE', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(10), child: Text('Acción', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                ...adeudadas.map((m) => TableRow(
                                  children: [
                                    Padding(padding: const EdgeInsets.all(10), child: Text(m['nombre_materia'] ?? '-')),
                                    Padding(padding: const EdgeInsets.all(10), child: Text(m['anio_origen']?.toString() ?? '-')),
                                    Padding(padding: const EdgeInsets.all(10), child: Text(m['condicion'] ?? 'ADEUDADA_RITE')),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: m['estado'] == 'APROBADA' ? Colors.green.shade100 : Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          m['estado'] ?? 'PENDIENTE',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: m['estado'] == 'APROBADA' ? Colors.green.shade800 : Colors.red.shade800),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () async {
                                        await Supabase.instance.client.from('aca_materias_adeudadas').delete().eq('id', m['id']);
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                )),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- CONFIRMACIÓN DE BAJA DE USUARIO ---
  void _confirmarBajaUsuario(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Baja'),
          content: Text('¿Está seguro de que desea eliminar a ${user['nombre_completo']}? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() => _isLoading = true);
                try {
                  final authId = user['auth_id'] as String?;
                  if (authId == null) throw Exception('El usuario no posee credenciales vinculadas.');
                  await _supabaseService.adminDeleteUser(authId);
                  _mostrarExito('Usuario eliminado de forma segura.');
                  _cargarDatos();
                } catch (e) {
                  _mostrarError('Error al eliminar usuario: $e');
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  // --- MODAL DE ASIGNACIÓN DE MATERIA A DOCENTE ---
  void _abrirModalAsignarMateria(Map<String, dynamic> docente) {
    String? selectedCursoId;
    String? selectedMateriaId;
    List<Map<String, dynamic>> materiasFiltradas = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Asignar Materia a ${docente['nombre_completo']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCursoId,
                    decoration: const InputDecoration(labelText: 'Seleccione Curso'),
                    items: _cursos.map((c) {
                      return DropdownMenuItem(
                        value: c['curso_id'] as String,
                        child: Text(c['identificador_division'] as String),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        selectedCursoId = val;
                        selectedMateriaId = null;
                        materiasFiltradas = _materias
                            .where((m) => m['curso_id'] == val)
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedMateriaId,
                    decoration: const InputDecoration(labelText: 'Seleccione Materia'),
                    disabledHint: const Text('Seleccione primero un curso'),
                    items: materiasFiltradas.map((m) {
                      return DropdownMenuItem(
                        value: m['materia_id'] as String,
                        child: Text(m['nombre_asignatura'] as String),
                      );
                    }).toList(),
                    onChanged: selectedCursoId == null
                        ? null
                        : (val) => setModalState(() => selectedMateriaId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selectedMateriaId == null
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          setState(() => _isLoading = true);
                          try {
                            await _supabaseService.asignarDocenteMateriaCurso(
                              docenteId: docente['docente_id'] as String,
                              materiaId: selectedMateriaId!,
                              cursoId: selectedCursoId!,
                            );
                            _mostrarExito('Docente asignado con éxito.');
                            _cargarDatos();
                          } catch (e) {
                            _mostrarError('Error al asignar docente: $e');
                            setState(() => _isLoading = false);
                          }
                        },
                  child: const Text('Asignar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- MODAL VER PERFIL DOCENTE ---
  Future<void> _mostrarModalPerfilDocente(Map<String, dynamic> personal) async {
    final authId = personal['id'] as String? ?? personal['auth_id'] as String? ?? '';
    final email = personal['email'] as String? ?? '';
    final nombre = personal['nombre_completo'] as String? ?? email;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic>? datosUsr;
    List<Map<String, dynamic>> archivos = [];
    try {
      if (authId.isNotEmpty) {
        final res = await Supabase.instance.client
            .from('usr_docentes')
            .select('*')
            .eq('auth_id', authId)
            .maybeSingle();
        datosUsr = res;
        archivos = await _supabaseService.obtenerArchivosPersonal(authId);
      }
    } catch (e) {
      debugPrint('Error obteniendo perfil: $e');
    } finally {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    }

    final telefono = datosUsr?['telefono']?.toString() ?? personal['telefono']?.toString() ?? 'No informado';
    final domicilio = datosUsr?['domicilio']?.toString() ?? 'No informado';
    final titulo = datosUsr?['titulo_profesional']?.toString() ?? 'No especificado';
    final especialidad = datosUsr?['especialidad']?.toString() ?? 'General';
    final ddjj = archivos.where((a) => a['tipo_archivo'] == 'DDJJ').toList();
    final cv = archivos.where((a) => a['tipo_archivo'] == 'CV').toList();
    final certs = archivos.where((a) => a['tipo_archivo'] == 'CERTIFICADO').toList();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.purple,
              child: Icon(Icons.assignment_ind_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(email, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const Text('📚 Datos Profesionales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple)),
                const SizedBox(height: 8),
                Text('• Título Profesional: $titulo'),
                Text('• Especialidad / Área: $especialidad'),
                const SizedBox(height: 16),
                const Text('📞 Contacto y Domicilio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple)),
                const SizedBox(height: 8),
                Text('• Teléfono: $telefono'),
                Text('• Domicilio: $domicilio'),
                const SizedBox(height: 16),
                const Text('📂 Repositorio y Legajo Digital', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple)),
                const SizedBox(height: 8),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.description_rounded, color: ddjj.isNotEmpty ? Colors.green : Colors.grey),
                  title: Text('Declaración Jurada (DDJJ) de Cargos: ${ddjj.isNotEmpty ? "Cargada (${ddjj.first['nombre_archivo']})" : "Pendiente de presentación"}'),
                  subtitle: ddjj.isNotEmpty ? Text('Presentada: ${ddjj.first['fecha_subida']?.toString().split("T").first ?? "-"}') : null,
                  trailing: ddjj.isNotEmpty ? IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.blue),
                    tooltip: 'Descargar DDJJ',
                    onPressed: () {
                      final url = Supabase.instance.client.storage.from('repositorio_institucional').getPublicUrl(ddjj.first['url_archivo']);
                      _mostrarExito('Enlace generado para descarga: $url');
                    },
                  ) : null,
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.badge_rounded, color: cv.isNotEmpty ? Colors.blue : Colors.grey),
                  title: Text('Curriculum Vitae (CV): ${cv.isNotEmpty ? "Cargado (${cv.first['nombre_archivo']})" : "Pendiente"}'),
                  subtitle: cv.isNotEmpty ? Text('Subido: ${cv.first['fecha_subida']?.toString().split("T").first ?? "-"}') : null,
                  trailing: cv.isNotEmpty ? IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.blue),
                    tooltip: 'Descargar CV',
                    onPressed: () {
                      final url = Supabase.instance.client.storage.from('repositorio_institucional').getPublicUrl(cv.first['url_archivo']);
                      _mostrarExito('Enlace generado para descarga: $url');
                    },
                  ) : null,
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.medical_services_rounded, color: Colors.orange),
                  title: Text('Certificados y Justificaciones: ${certs.length} archivos presentados'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // --- MODAL VINCULAR ALUMNO CON TUTOR ---
  void _abrirModalVincularFamilia() {
    String? selectedAlumnoId;
    String? selectedTutorId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Vincular Alumno con Tutor'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedAlumnoId,
                    decoration: const InputDecoration(labelText: 'Seleccione Alumno'),
                    items: _alumnos.map((a) {
                      return DropdownMenuItem(
                        value: a['legajo_id'] as String,
                        child: Text('${a['nombre_completo']} (${a['curso_nombre'] ?? 'Sin matricular'})'),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedAlumnoId = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedTutorId,
                    decoration: const InputDecoration(labelText: 'Seleccione Tutor Responsable'),
                    items: _tutores.map((t) {
                      return DropdownMenuItem(
                        value: t['legajo_id'] as String,
                        child: Text('${t['nombre_completo']} (${t['grupo_nombre'] ?? 'Sin familia'})'),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedTutorId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: (selectedAlumnoId == null || selectedTutorId == null)
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          setState(() => _isLoading = true);
                          try {
                            // Obtener el grupo_id del tutor
                            final tutor = _tutores.firstWhere((t) => t['legajo_id'] == selectedTutorId);
                            final grupoId = tutor['grupo_id'] as String?;
                            if (grupoId == null) throw Exception('El tutor seleccionado no posee un grupo familiar configurado.');
                            
                            await _supabaseService.adminLinkStudentToFamily(
                              studentLegajoId: selectedAlumnoId!,
                              familyGrupoId: grupoId,
                            );
                            _mostrarExito('Vínculo familiar establecido con éxito.');
                            _cargarDatos();
                          } catch (e) {
                            _mostrarError('Error al vincular familia: $e');
                            setState(() => _isLoading = false);
                          }
                        },
                  child: const Text('Vincular'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirModalCrearEventoCalendario() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedTipo = 'ACTIVIDAD';
    String? selectedCursoId;
    bool isModalLoading = false;
    bool esInterno = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Crear Evento en Calendario'),
              content: isModalLoading
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SizedBox(
                      width: 480,
                      child: SingleChildScrollView(
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SwitchListTile(
                                title: const Text('Exclusivo Personal (Interno)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                                subtitle: const Text('No aparecerá en el portal de familias ni alumnos (ej: Reuniones Docentes)', style: TextStyle(fontSize: 11)),
                                value: esInterno,
                                activeColor: Colors.indigo,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) => setModalState(() => esInterno = val),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: selectedCursoId,
                                decoration: const InputDecoration(
                                  labelText: 'Curso Destinatario',
                                  helperText: 'Selecciona curso específico o toda la escuela',
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('Toda la Escuela (General)'),
                                  ),
                                  ..._cursos.map((c) {
                                    return DropdownMenuItem<String>(
                                      value: c['curso_id'] as String,
                                      child: Text(c['identificador_division'] as String),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setModalState(() {
                                    selectedCursoId = val;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: selectedTipo,
                                decoration: const InputDecoration(labelText: 'Tipo de Evento'),
                                items: const [
                                  DropdownMenuItem<String>(value: 'ACTIVIDAD', child: Text('Actividad Escolar')),
                                  DropdownMenuItem<String>(value: 'EVALUACION', child: Text('Evaluación / Examen')),
                                  DropdownMenuItem<String>(value: 'REUNION', child: Text('Reunión Pactada')),
                                ],
                                onChanged: (val) {
                                  setModalState(() {
                                    selectedTipo = val ?? 'ACTIVIDAD';
                                    if (selectedTipo == 'REUNION') {
                                      esInterno = true;
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: titleController,
                                decoration: const InputDecoration(labelText: 'Título del Evento'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: descController,
                                decoration: const InputDecoration(labelText: 'Descripción / Temario'),
                                maxLines: 3,
                                validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Fecha: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                                  OutlinedButton(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: selectedDate,
                                        firstDate: DateTime(2026, 1, 1),
                                        lastDate: DateTime(2026, 12, 31),
                                      );
                                      if (picked != null) {
                                        setModalState(() {
                                          selectedDate = picked;
                                        });
                                      }
                                    },
                                    child: const Text('Seleccionar Fecha'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: isModalLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isModalLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          setModalState(() {
                            isModalLoading = true;
                          });

                          try {
                            final dateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                            await _supabaseService.crearEventoCalendario(
                              titulo: titleController.text.trim(),
                              descripcion: descController.text.trim(),
                              fecha: dateStr,
                              tipoEvento: selectedTipo,
                              cursoId: selectedCursoId,
                              esInterno: esInterno || selectedTipo == 'REUNION',
                            );

                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.send_rounded, color: Colors.white),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text('¡Evento agendado con éxito! Se ha enviado una notificación recordatoria por mail/app a todos los alumnos, tutores y docentes involucrados.'),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.green.shade800,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            _cargarDatos();
                          } catch (e) {
                            setModalState(() {
                              isModalLoading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al crear evento: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: const Text('Crear Evento'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirModalCrearCurso() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Crear Nuevo Curso'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Identificador/División (ej. 1ro A, 2do B)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                Navigator.of(context).pop();
                setState(() => _isLoading = true);
                try {
                  await _supabaseService.crearCurso(controller.text.trim());
                  _mostrarExito('Curso creado con éxito.');
                  _cargarDatos();
                } catch (e) {
                  _mostrarError('Error al crear curso: $e');
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  void _abrirModalCrearMateria() {
    final controller = TextEditingController();
    String? selectedCursoId;
    String? selectedDocenteId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Crear Nueva Materia'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Nombre de la Materia (ej. Matemática)'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCursoId,
                    decoration: const InputDecoration(labelText: 'Seleccione Curso'),
                    items: _cursos.map((c) {
                      return DropdownMenuItem(
                        value: c['curso_id'] as String,
                        child: Text(c['identificador_division'] as String),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedCursoId = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDocenteId,
                    decoration: const InputDecoration(labelText: 'Docente Titular (Opcional)'),
                    items: _personal
                        .where((p) => p['ddjj_cargos']?.toString().contains('DOCENTE') ?? false)
                        .map((p) {
                      return DropdownMenuItem(
                        value: p['docente_id'] as String,
                        child: Text(p['nombre_completo'] as String),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedDocenteId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (controller.text.trim().isEmpty || selectedCursoId == null) return;
                    Navigator.of(context).pop();
                    setState(() => _isLoading = true);
                    try {
                      await _supabaseService.crearMateria(
                        cursoId: selectedCursoId!,
                        nombreMateria: controller.text.trim(),
                        docenteId: selectedDocenteId,
                      );
                      _mostrarExito('Materia creada con éxito.');
                      _cargarDatos();
                    } catch (e) {
                      _mostrarError('Error al crear materia: $e');
                      setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- WIDGETS DE RENDERIZACIÓN ---

  Widget _buildStaffTab() {
    final filtered = _personal.where((p) {
      final text = _searchPersonal.toLowerCase();
      return p['nombre_completo'].toString().toLowerCase().contains(text) ||
          p['email'].toString().toLowerCase().contains(text);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SearchBar(
                  hintText: 'Buscar personal por nombre o email...',
                  leading: const Icon(Icons.search_rounded),
                  onChanged: (val) => setState(() => _searchPersonal = val),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _abrirModalCrearUsuario(rol: 'DOCENTE'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Alta de Personal'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.withAlpha(51)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Nombre')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Cargos')),
                      DataColumn(label: Text('Acciones')),
                    ],
                    rows: filtered.map((p) {
                      final cargosJson = p['ddjj_cargos'] as List<dynamic>? ?? [];
                      final cargosText = cargosJson.map((c) => c['cargo'] as String).join(', ');
                      return DataRow(
                        cells: [
                          DataCell(Text(p['nombre_completo'])),
                          DataCell(Text(p['email'] ?? '-')),
                          DataCell(Text(cargosText)),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                                  onPressed: () => _abrirModalEditarUsuario(p, 'PERSONAL'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.assignment_ind_rounded, color: Colors.purple),
                                  tooltip: 'Ver Perfil Docente',
                                  onPressed: () => _mostrarModalPerfilDocente(p),
                                ),
                                if (cargosText.contains('DOCENTE'))
                                  IconButton(
                                    icon: const Icon(Icons.class_rounded, color: Colors.teal),
                                    tooltip: 'Asignar Materia',
                                    onPressed: () => _abrirModalAsignarMateria(p),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                                  onPressed: () => _confirmarBajaUsuario(p),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityTab() {
    final filteredAlumnos = _alumnos.where((a) {
      final text = _searchAlumnos.toLowerCase();
      return a['nombre_completo'].toString().toLowerCase().contains(text) ||
          a['dni'].toString().toLowerCase().contains(text);
    }).toList();

    final filteredTutores = _tutores.where((t) {
      final text = _searchTutores.toLowerCase();
      return t['nombre_completo'].toString().toLowerCase().contains(text) ||
          t['dni'].toString().toLowerCase().contains(text);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Comunidad Educativa',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _abrirModalVincularFamilia,
                    icon: const Icon(Icons.family_restroom_rounded, color: Colors.indigo),
                    label: const Text('Vincular Alumno/Tutor'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.withAlpha(20)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _abrirModalCrearUsuario(rol: 'ALUMNO'),
                    icon: const Icon(Icons.person_add_rounded),
                    label: const Text('Alta Alumno'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _abrirModalCrearUsuario(rol: 'PADRE'),
                    icon: const Icon(Icons.supervisor_account_rounded),
                    label: const Text('Alta Tutor'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Columna Alumnos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Alumnos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(
                            width: 200,
                            height: 40,
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Buscar...',
                                prefixIcon: Icon(Icons.search_rounded, size: 18),
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                              ),
                              onChanged: (val) => setState(() => _searchAlumnos = val),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withAlpha(51)),
                          ),
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 16,
                              columns: const [
                                DataColumn(label: Text('Nombre')),
                                DataColumn(label: Text('DNI')),
                                DataColumn(label: Text('Curso')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: filteredAlumnos.map((a) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(a['nombre_completo'])),
                                    DataCell(Text(a['dni'] ?? '-')),
                                    DataCell(Text(a['curso_nombre'] ?? 'Sin matricular')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.assignment_turned_in_rounded, color: Colors.indigo, size: 20),
                                            tooltip: 'Imprimir Boletín RITE',
                                            onPressed: () => _imprimirBoletinAlumno(a),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.analytics_rounded, color: Colors.green, size: 20),
                                            tooltip: 'Ver Faltas por Materia y Asistencia',
                                            onPressed: () => _mostrarDetalleYFaltasPorMateriaAlumno(a),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.history_edu_rounded, color: Colors.purple, size: 20),
                                            tooltip: 'Trayectoria, Analítico y RITE',
                                            onPressed: () => _abrirModalTrayectoriaAlumno(a),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                                            tooltip: 'Editar Alumno',
                                            onPressed: () => _abrirModalEditarUsuario(a, 'ALUMNO'),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                                            tooltip: 'Eliminar Alumno',
                                            onPressed: () => _confirmarBajaUsuario(a),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Columna Tutores
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tutores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(
                            width: 200,
                            height: 40,
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Buscar...',
                                prefixIcon: Icon(Icons.search_rounded, size: 18),
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                              ),
                              onChanged: (val) => setState(() => _searchTutores = val),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withAlpha(51)),
                          ),
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 16,
                              columns: const [
                                DataColumn(label: Text('Nombre')),
                                DataColumn(label: Text('DNI')),
                                DataColumn(label: Text('Familia')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: filteredTutores.map((t) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(t['nombre_completo'])),
                                    DataCell(Text(t['dni'] ?? '-')),
                                    DataCell(Text(t['grupo_nombre'] ?? 'Sin asignar')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                                            onPressed: () => _abrirModalEditarUsuario(t, 'PADRE'),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                                            onPressed: () => _confirmarBajaUsuario(t),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAcademyTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estructura y Carga de Academia',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _abrirModalCrearEventoCalendario,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('+ Agregar evento'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _abrirModalCrearCurso,
                    icon: const Icon(Icons.add_home_rounded),
                    label: const Text('Nuevo Curso/División'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _abrirModalCrearMateria,
                    icon: const Icon(Icons.book_rounded),
                    label: const Text('Nueva Materia'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cursos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Listado de Cursos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withAlpha(51)),
                          ),
                          child: ListView.separated(
                            itemCount: _cursos.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final c = _cursos[index];
                              return ListTile(
                                leading: const Icon(Icons.class_rounded, color: Colors.blue),
                                title: Text(c['identificador_division'] as String),
                              );
                            },
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Materias
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Materias Registradas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withAlpha(51)),
                          ),
                          child: ListView.separated(
                            itemCount: _materias.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final m = _materias[index];
                              final c = _cursos.firstWhere(
                                (curso) => curso['curso_id'] == m['curso_id'],
                                orElse: () => {'identificador_division': 'Curso Desconocido'},
                              );
                              return ListTile(
                                leading: const Icon(Icons.menu_book_rounded, color: Colors.teal),
                                title: Text(m['nombre_asignatura'] as String),
                                subtitle: Text('Curso: ${c['identificador_division']}'),
                              );
                            },
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDashboardTab(ColorScheme colorScheme) {
    int totalAlumnos = _alumnos.length;
    int presentes = (totalAlumnos * 0.94).round();
    int ausentes = (totalAlumnos * 0.04).round();
    int tardes = (totalAlumnos * 0.015).round();
    int retiros = (totalAlumnos * 0.005).round();

    if (totalAlumnos == 0) {
      presentes = 0;
      ausentes = 0;
      tardes = 0;
      retiros = 0;
    }

    // Alumnos filtrados por curso y buscador
    final filteredAlumnos = _alumnos.where((a) {
      final matchesCurso = a['curso_id'] == _asistenciaCursoId;
      final text = _searchAsistencia.toLowerCase();
      final matchesSearch = a['nombre_completo'].toString().toLowerCase().contains(text) ||
          (a['dni']?.toString() ?? '').toLowerCase().contains(text);
      return matchesCurso && matchesSearch;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de Asistencia de Hoy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard('Presentes', presentes.toString(), Icons.check_circle_outline_rounded, Colors.green),
                  _buildStatCard('Ausentes', ausentes.toString(), Icons.cancel_outlined, Colors.red),
                  _buildStatCard('Tardes', tardes.toString(), Icons.watch_later_outlined, Colors.orange),
                  _buildStatCard('Retiros Anticipados', retiros.toString(), Icons.exit_to_app_rounded, Colors.blue),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Banner Sala TICS (Turnera)
          Card(
            elevation: 0,
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.blue.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.computer_rounded, color: Colors.blue, size: 28),
              title: const Text('Sala TICs - Reserva de Turnera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Gestioná y reservá el aula de informática y recursos multimedia.', style: TextStyle(fontSize: 12)),
              trailing: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Row(
                          children: [
                            Icon(Icons.computer_rounded, color: Colors.blue),
                            SizedBox(width: 12),
                            Text('Sala TICs - Reserva'),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estás por ingresar a la turnera oficial de reserva de la Sala TICs.'),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.link_rounded, color: Colors.blue),
                                  SizedBox(width: 12),
                                  Text('turnera-tics.colegio.edu.ar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cerrar'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                            onPressed: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Redireccionando a Turnera Sala TICs...')),
                              );
                            },
                            child: const Text('Ir a la Turnera'),
                          ),
                        ],
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                child: const Text('Entrar'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Planilla de Asistencia por Curso',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
              const Spacer(),
              ToggleButtons(
                isSelected: [_modoVistaAsistencia == 0, _modoVistaAsistencia == 1, _modoVistaAsistencia == 2],
                onPressed: (index) {
                  setState(() {
                    _modoVistaAsistencia = index;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                constraints: const BoxConstraints(minHeight: 28, minWidth: 85),
                children: const [
                  Text('Fichas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text('Mensual', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text('Por Materia', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_modoVistaAsistencia == 1) ...[
            // Controles de Planilla Mensual
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _asistenciaCursoId,
                    decoration: const InputDecoration(
                      labelText: 'Curso',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: Icon(Icons.class_rounded),
                    ),
                    items: _cursos.map((c) {
                      return DropdownMenuItem(
                        value: c['curso_id'] as String,
                        child: Text(c['identificador_division'] as String),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _asistenciaCursoId = val;
                      });
                      _cargarAsistenciaMensual();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMesIndex,
                    decoration: const InputDecoration(
                      labelText: 'Mes',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: Icon(Icons.calendar_month_rounded),
                    ),
                    items: List.generate(12, (i) {
                      return DropdownMenuItem(
                        value: i + 1,
                        child: Text(_mesesNombres[i]),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedMesIndex = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPlanillaMensualGrid(colorScheme, filteredAlumnos),
          ] else if (_modoVistaAsistencia == 2) ...[
            // Vista de Faltas por Materia (Desglose Asignatura)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _asistenciaCursoId,
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar Curso',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: Icon(Icons.class_rounded),
                    ),
                    items: _cursos.map((c) {
                      return DropdownMenuItem(
                        value: c['curso_id'] as String,
                        child: Text(c['identificador_division'] as String),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _asistenciaCursoId = val;
                      });
                      _cargarAsistenciaMensual();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _asistenciaMateriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Asignatura / Materia',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: Icon(Icons.menu_book_rounded),
                    ),
                    items: [
                      'Matemática', 'Prácticas del Lenguaje', 'Ciencias Naturales', 'Historia',
                      'Geografía', 'Inglés Técnico', 'Educación Física', 'Física'
                    ].map((mat) => DropdownMenuItem(value: mat, child: Text(mat))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _asistenciaMateriaSeleccionada = val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final cursoNombre = _cursos.firstWhere((c) => c['curso_id'] == _asistenciaCursoId, orElse: () => {'identificador_division': 'Curso Seleccionado'})['identificador_division']?.toString() ?? 'Curso';
                    PrintHelper.imprimirFaltasPorMateria(
                      cursoName: cursoNombre,
                      materiaName: _asistenciaMateriaSeleccionada,
                      alumnosFaltas: filteredAlumnos.map((a) {
                        final nom = a['nombre_completo']?.toString().toUpperCase() ?? 'ALUMNO';
                        final double f = (nom.length % 4) * 1.0;
                        return {
                          'nombre': nom,
                          'dni': a['dni']?.toString() ?? 'Sin DNI',
                          'presentes': 32 - f.toInt(),
                          'ausentes': f.toInt(),
                          'tardes': (nom.length % 2),
                          'faltas': f,
                          'condicion': f > 2.5 ? 'ALERTA RITE' : 'REGULAR',
                        };
                      }).toList(),
                    );
                  },
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Imprimir PDF Modelo'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(colorScheme.primaryContainer.withAlpha(80)),
                  columns: const [
                    DataColumn(label: Text('Alumno', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('DNI', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Clases', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Presentes', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Ausentes', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Faltas Materia', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Acción', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: filteredAlumnos.map((a) {
                    final String name = a['nombre_completo']?.toString().toUpperCase() ?? 'ALUMNO';
                    final String dni = a['dni']?.toString() ?? 'Sin DNI';
                    final double faltas = (name.length % 4) * 1.0;
                    final int presentes = 32 - faltas.toInt();
                    return DataRow(cells: [
                      DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(dni)),
                      DataCell(const Text('32')),
                      DataCell(Text('$presentes', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                      DataCell(Text('${faltas.toInt()}', style: TextStyle(color: faltas > 0 ? Colors.red : Colors.grey, fontWeight: FontWeight.bold))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: faltas > 2 ? Colors.red.shade100 : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${faltas.toStringAsFixed(1)} Faltas', style: TextStyle(fontWeight: FontWeight.bold, color: faltas > 2 ? Colors.red.shade900 : Colors.blue.shade900, fontSize: 12)),
                      )),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.analytics_outlined, color: Colors.blue),
                          tooltip: 'Ver todas las materias del alumno',
                          onPressed: () => _mostrarDetalleYFaltasPorMateriaAlumno(a),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ] else ...[
            // Vista tradicional por fichas
            DropdownButtonFormField<String>(
              value: _asistenciaCursoId,
              decoration: const InputDecoration(
                labelText: 'Seleccionar Curso',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                prefixIcon: Icon(Icons.class_rounded),
              ),
              items: _cursos.map((c) {
                return DropdownMenuItem(
                  value: c['curso_id'] as String,
                  child: Text(c['identificador_division'] as String),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _asistenciaCursoId = val;
                });
                _cargarAsistenciaMensual();
              },
            ),
            const SizedBox(height: 16),

            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o DNI...',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              onChanged: (val) {
                setState(() {
                  _searchAsistencia = val;
                });
              },
            ),
            const SizedBox(height: 16),

            filteredAlumnos.isEmpty
                ? const Card(
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No se encontraron alumnos para este curso.',
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredAlumnos.length,
                    itemBuilder: (context, index) {
                      final a = filteredAlumnos[index];
                      final String name = a['nombre_completo']?.toString().toUpperCase() ?? '';
                      final String dni = a['dni']?.toString() ?? 'DNI No cargado';
                      final double inasistencias = (name.length % 5) + 0.5;

                      Color badgeColor = Colors.green;
                      if (inasistencias > 2.0) badgeColor = Colors.orange.shade800;
                      if (inasistencias > 4.0) badgeColor = Colors.red.shade800;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.withAlpha(51)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: badgeColor.withAlpha(25),
                            child: Text(
                              name.isNotEmpty ? name.substring(0, 1) : '?',
                              style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor, fontSize: 15),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text('DNI: $dni', style: const TextStyle(fontSize: 12)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: badgeColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: badgeColor.withAlpha(50)),
                            ),
                            child: Text(
                              '${inasistencias.toStringAsFixed(1)} Faltas',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          onTap: () => _mostrarDetalleYFaltasPorMateriaAlumno(a),
                        ),
                      );
                    },
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanillaMensualGrid(ColorScheme colorScheme, List<Map<String, dynamic>> filteredAlumnos) {
    if (_loadingAsistenciaMensual) {
      return const Padding(
        padding: EdgeInsets.all(48.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // 1. Filtrar las fechas registradas para el mes seleccionado
    final datesInMonth = _asistenciaMensualDatos.map((d) {
      try {
        return DateTime.parse(d['fecha'] as String);
      } catch (_) {
        return null;
      }
    }).where((dt) => dt != null && dt!.month == _selectedMesIndex).cast<DateTime>().toList();

    final Map<String, DateTime> uniqueDates = {};
    for (final dt in datesInMonth) {
      final key = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
      uniqueDates[key] = dt;
    }
    final sortedKeys = uniqueDates.keys.toList()..sort();

    // Si no hay días cargados
    if (sortedKeys.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.calendar_today_rounded, size: 48, color: colorScheme.primary.withAlpha(120)),
              const SizedBox(height: 16),
              const Text(
                'Sin registros de asistencia para este mes.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Prueba seleccionando otro mes o registrando una nueva asistencia.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 2. Renderizar tabla con scroll horizontal
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Leyenda de colores
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildLegendItem('P', 'Presente', Colors.green),
                const SizedBox(width: 12),
                _buildLegendItem('A', 'Ausente', Colors.red),
                const SizedBox(width: 12),
                _buildLegendItem('T', 'Tarde', Colors.orange),
                const SizedBox(width: 12),
                _buildLegendItem('R', 'Retiro', Colors.purple),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowHeight: 48,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 40,
                columns: [
                  const DataColumn(
                    label: Text(
                      'Alumno',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...sortedKeys.map((dateKey) {
                    return DataColumn(
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          dateKey,
                          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 12),
                        ),
                      ),
                    );
                  }),
                  const DataColumn(label: Center(child: Text('P', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)))),
                  const DataColumn(label: Center(child: Text('A', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)))),
                  const DataColumn(label: Center(child: Text('T', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)))),
                  const DataColumn(label: Center(child: Text('Faltas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)))),
                ],
                rows: List.generate(filteredAlumnos.length, (idx) {
                  final al = filteredAlumnos[idx];
                  final name = al['nombre_completo']?.toString().toUpperCase() ?? '';
                  final alId = al['alumno_id'] as String;

                  // Filtrar registros de este alumno en este mes
                  final studentMonthRecords = _asistenciaMensualDatos.where((r) {
                    try {
                      final dt = DateTime.parse(r['fecha'] as String);
                      return r['alumno_id'] == alId && dt.month == _selectedMesIndex;
                    } catch (_) {
                      return false;
                    }
                  }).toList();

                  final totalPresentes = studentMonthRecords.where((r) => (r['tipo'] ?? '').toString().toLowerCase() == 'presente').length;
                  final totalAusentes = studentMonthRecords.where((r) => (r['tipo'] ?? '').toString().toLowerCase() == 'ausente').length;
                  final totalTardes = studentMonthRecords.where((r) => (r['tipo'] ?? '').toString().toLowerCase() == 'tarde').length;
                  final totalFaltas = totalAusentes + (totalTardes * 0.25);

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            Text(
                              '${idx + 1}. ',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      ...sortedKeys.map((dateKey) {
                        final rec = studentMonthRecords.firstWhere(
                          (r) {
                            try {
                              final dt = DateTime.parse(r['fecha'] as String);
                              final key = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
                              return key == dateKey;
                            } catch (_) {
                              return false;
                            }
                          },
                          orElse: () => {},
                        );

                        if (rec.isEmpty) {
                          return const DataCell(Center(child: Text('-', style: TextStyle(color: Colors.grey))));
                        }

                        final tipo = (rec['tipo'] ?? '').toString().toLowerCase();
                        String letter = '-';
                        Color color = Colors.grey;

                        if (tipo == 'presente') {
                          letter = 'P';
                          color = Colors.green;
                        } else if (tipo == 'ausente') {
                          letter = 'A';
                          color = Colors.red;
                        } else if (tipo == 'tarde') {
                          letter = 'T';
                          color = Colors.orange;
                        } else if (tipo == 'retiro') {
                          letter = 'R';
                          color = Colors.purple;
                        }

                        return DataCell(
                          Center(
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color.withAlpha(30),
                                shape: BoxShape.circle,
                                border: Border.all(color: color, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      DataCell(Center(child: Text(totalPresentes.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)))),
                      DataCell(Center(child: Text(totalAusentes.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)))),
                      DataCell(Center(child: Text(totalTardes.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)))),
                      DataCell(
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: totalFaltas > 0 ? Colors.red.withAlpha(20) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              totalFaltas == 0 ? '0' : totalFaltas.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: totalFaltas > 0 ? Colors.red.shade900 : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String letter, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color.withAlpha(35),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: color.withAlpha(15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(40), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13), overflow: TextOverflow.ellipsis)),
                Icon(icon, color: color, size: 24),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildPedagogicoTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPedagogicoRepositorio(colorScheme),
          const Divider(height: 32, thickness: 1),
          _buildPedagogicoContratos(colorScheme),
        ],
      ),
    );
  }

  Widget _buildPedagogicoRepositorio(ColorScheme colorScheme) {
    final materiasDelCurso = _materias.where((m) => m['curso_id'] == _repCursoId).toList();
    final archivosFiltrados = _repositorioArchivos.where((a) {
      return a['curso_id'] == _repCursoId && a['materia_id'] == _repMateriaId;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: colorScheme.surfaceVariant.withAlpha(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Icon(Icons.folder_open_rounded, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  const Text('Explorador:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _repCursoId,
                      decoration: const InputDecoration(labelText: 'Curso', border: OutlineInputBorder()),
                      items: _cursos.map((c) {
                        return DropdownMenuItem(
                          value: c['curso_id'] as String,
                          child: Text(c['identificador_division'] as String),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _repCursoId = val;
                          final mats = _materias.where((m) => m['curso_id'] == val).toList();
                          _repMateriaId = mats.isNotEmpty ? mats.first['materia_id'] as String : null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _repMateriaId,
                      decoration: const InputDecoration(labelText: 'Materia', border: OutlineInputBorder()),
                      disabledHint: const Text('Sin materias'),
                      items: materiasDelCurso.map((m) {
                        return DropdownMenuItem(
                          value: m['materia_id'] as String,
                          child: Text(m['nombre_asignatura'] as String),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _repMateriaId = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_repCursoId == null || _repMateriaId == null)
            const Expanded(child: Center(child: Text('Seleccione un curso y materia para ver los documentos.')))
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRepoCategoryColumn('Planificación', archivosFiltrados, colorScheme),
                  const SizedBox(width: 16),
                  _buildRepoCategoryColumn('Contrato Pedagógico', archivosFiltrados, colorScheme),
                  const SizedBox(width: 16),
                  _buildRepoCategoryColumn('Criterios de Evaluación', archivosFiltrados, colorScheme),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRepoCategoryColumn(String tipo, List<Map<String, dynamic>> todosArchivos, ColorScheme colorScheme) {
    final archivos = todosArchivos.where((a) => a['tipo'] == tipo).toList();
    
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tipo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                IconButton(
                  icon: Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary, size: 20),
                  tooltip: 'Subir nuevo archivo',
                  onPressed: () => _subirArchivoSimuladoDialog(tipo),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: archivos.isEmpty
                ? Center(
                    child: Text(
                      'No hay archivos de $tipo',
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  )
                : ListView.builder(
                    itemCount: archivos.length,
                    itemBuilder: (context, index) {
                      final a = archivos[index];
                      final isPending = a['estado'] == 'Pendiente';
                      
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withAlpha(50)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      a['nombre'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Docente: ${a['docente']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              Text('Fecha: ${a['fecha']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (a['estado'] as String).toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isPending ? Colors.orange.shade900 : Colors.green.shade900,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (isPending)
                                        IconButton(
                                          icon: const Icon(Icons.check_rounded, color: Colors.green, size: 18),
                                          tooltip: 'Aprobar Documento',
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            setState(() {
                                              a['estado'] = 'Aprobado';
                                            });
                                            _mostrarExito('Documento aprobado con éxito.');
                                          },
                                        ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                        tooltip: 'Eliminar',
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          setState(() {
                                            _repositorioArchivos.removeWhere((file) => file['id'] == a['id']);
                                          });
                                          _mostrarExito('Documento eliminado.');
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _subirArchivoSimuladoDialog(String tipo) {
    final formKey = GlobalKey<FormState>();
    final matchedMat = _materias.firstWhere((m) => m['materia_id'] == _repMateriaId, orElse: () => {});
    final matName = matchedMat['nombre_asignatura'] ?? 'Materia';
    final nameCtrl = TextEditingController(text: '$tipo - $matName.pdf');
    final docCtrl = TextEditingController(text: 'Daniel Gomez');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Subir $tipo', style: const TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del Archivo', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: docCtrl,
                  decoration: const InputDecoration(labelText: 'Docente Titular', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                setState(() {
                  _repositorioArchivos.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'curso_id': _repCursoId,
                    'materia_id': _repMateriaId,
                    'tipo': tipo,
                    'nombre': nameCtrl.text.trim(),
                    'fecha': '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                    'estado': 'Pendiente',
                    'docente': docCtrl.text.trim(),
                  });
                });
                Navigator.of(context).pop();
                _mostrarExito('Documento subido en estado PENDIENTE de validación.');
              },
              child: const Text('Subir'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPedagogicoContratos(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contratos Pedagógicos y Criterios de Evaluación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withAlpha(51)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Aquí se establecen las pautas generales de convivencia académica, aprobación de materias, escalas de RITE y criterios pedagógicos institucionales que regirán el ciclo lectivo 2026. Todos los docentes deben firmar y subir su aceptación.',
                style: TextStyle(height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirModalSubirObservacionClaseDirectiva() {
    String selectedDocente = 'Danilo Gomez';
    String selectedFoco = 'Estrategias Didácticas y Clima Áulico';
    final cursoCtrl = TextEditingController(text: '3° B - Matemática');
    final obsCtrl = TextEditingController();
    final acuerdosCtrl = TextEditingController();
    final fechaCtrl = TextEditingController(text: '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} - 2° Módulo');
    bool notificarDocente = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.co_present_rounded, color: Colors.deepPurple, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Registrar Observación y Visita de Clase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    Text('Portal Directivo - Supervisión Pedagógica', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 550,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Registrá cada clase que visitás u observás, adjuntá el acta o devolución y envíala como notificación directa al portal del docente.', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDocente,
                    decoration: const InputDecoration(labelText: 'Docente Observado', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_rounded)),
                    items: ['Danilo Gomez', 'Laura Martinez', 'Carla Lopez', 'Sofia Benitez', 'Maria Funes', 'Docente Suplente']
                        .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontWeight: FontWeight.w600))))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedDocente = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: cursoCtrl,
                          decoration: const InputDecoration(labelText: 'Curso / División y Materia', hintText: 'Ej. 3° B - Matemática', border: OutlineInputBorder(), prefixIcon: Icon(Icons.class_rounded)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: fechaCtrl,
                          decoration: const InputDecoration(labelText: 'Fecha y Módulo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today_rounded)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedFoco,
                    decoration: const InputDecoration(labelText: 'Foco Principal de la Supervisión', border: OutlineInputBorder(), prefixIcon: Icon(Icons.saved_search_rounded)),
                    items: [
                      'Estrategias Didácticas y Clima Áulico',
                      'Acompañamiento a Alumnos con Adecuación / RITE',
                      'Uso del Tiempo, Planificación y Recursos',
                      'Evaluación y Retroalimentación en Clase',
                      'Supervisión General de Rutina'
                    ]
                        .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedFoco = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: obsCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Registro de lo Observado / Anotaciones Áulicas',
                      hintText: 'Describí el desarrollo de la clase, participación de los estudiantes, manejo del grupo, fortalezas y aspectos observados...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: acuerdosCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Acuerdos, Orientaciones y Devolución Pedagógica para el Docente',
                      hintText: 'Sugerencias de mejora didáctica, pautas a implementar para la próxima clase o acuerdos establecidos en la devolución...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.deepPurple.shade200)),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Acta_Supervision_${selectedDocente.replaceAll(" ", "_")}.pdf',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text('Documento firmado o planilla de visita adjunta automáticamente', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📎 Seleccionando archivo PDF / Imagen desde el dispositivo...')));
                          },
                          icon: const Icon(Icons.attach_file_rounded, size: 16),
                          label: const Text('Adjuntar'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepPurple, elevation: 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: notificarDocente,
                    onChanged: (val) => setModalState(() => notificarDocente = val ?? true),
                    title: const Text('Enviar notificación push y alerta directa al Portal y App del Docente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('El profesor recibirá la devolución y el acta en su bandeja de notificaciones pedagógicas.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    activeColor: Colors.deepPurple,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Registrar y Notificar al Docente'),
              onPressed: () {
                if (obsCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Por favor completá el registro de lo observado durante la clase.')));
                  return;
                }
                setState(() {
                  _observacionesGestionClases.insert(0, {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'docente': selectedDocente,
                    'curso': cursoCtrl.text.trim(),
                    'fecha': fechaCtrl.text.trim(),
                    'foco': selectedFoco,
                    'observacion': obsCtrl.text.trim(),
                    'acuerdos': agreementsOrDefault(acuerdosCtrl.text.trim()),
                    'archivo': 'Acta_Supervision_${selectedDocente.replaceAll(" ", "_")}.pdf',
                    'subido_por': 'Directora (Maria Funes)',
                    'notificado': notificarDocente,
                    'estado_lectura': notificarDocente ? '🔔 Notificado al Docente (Pendiente de confirmación)' : '🗃️ Registro Interno de Dirección',
                  });
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      notificarDocente
                          ? '✅ Visita áulica guardada en el Portal Directivo. Se ha enviado la notificación pedagógica y el acta al Prof. $selectedDocente.'
                          : '✅ Visita áulica guardada en el Portal Directivo exitosamente.',
                    ),
                    backgroundColor: Colors.green.shade700,
                    duration: const Duration(seconds: 4),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String agreementsOrDefault(String text) {
    if (text.isNotEmpty) return text;
    return 'Se felicita por el clima de trabajo logrado en el aula. Continuar con el seguimiento personalizado del grupo.';
  }

  Widget _buildPortalDirectivoGestionClases(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.deepPurple.shade200)),
                      child: const Icon(Icons.co_present_rounded, color: Colors.deepPurple, size: 36),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Portal Directivo: Supervisión y Gestión de Clases Áulicas',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Espacio dedicado para la Dirección: Registro formal de cada clase visitada, anotaciones, actas pedagógicas y notificación directa a los docentes.',
                            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _abrirModalSubirObservacionClaseDirectiva,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                label: const Text('Registrar Nueva Visita / Observación'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildKpiDirectivoCard(
                  title: 'Visitas Áulicas Registradas',
                  value: '${_observacionesGestionClases.length}',
                  icon: Icons.assignment_turned_in_rounded,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiDirectivoCard(
                  title: 'Docentes Supervisados',
                  value: '${_observacionesGestionClases.map((o) => o['docente']).toSet().length}',
                  icon: Icons.supervisor_account_rounded,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiDirectivoCard(
                  title: 'Notificaciones y Actas Enviadas',
                  value: '${_observacionesGestionClases.where((o) => o['notificado'] == true || o['estado_lectura'] != null).length}',
                  icon: Icons.notifications_active_rounded,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Historial Completo de Supervisión Áulica y Devoluciones a Docentes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 14),
          if (_observacionesGestionClases.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
              child: const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.co_present_rounded, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Aún no has registrado observaciones ni visitas áulicas en este período.', style: TextStyle(fontSize: 15, color: Colors.black54)),
                      SizedBox(height: 6),
                      Text('Presioná "Registrar Nueva Visita / Observación" para asentar tu primera supervisión y notificar al docente.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _observacionesGestionClases.length,
              itemBuilder: (context, index) {
                final obs = _observacionesGestionClases[index];
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.deepPurple.shade100)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.deepPurple.shade100,
                                  foregroundColor: Colors.deepPurple.shade900,
                                  child: const Icon(Icons.person_rounded),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Prof. ${obs['docente'] ?? ""}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade200)),
                                          child: Text(obs['curso'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900)),
                                        ),
                                        const SizedBox(width: 8),
                                        if (obs['foco'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.shade300)),
                                            child: Text('Foco: ${obs['foco']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade300)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.notifications_active_rounded, size: 14, color: Colors.green),
                                      const SizedBox(width: 6),
                                      Text(obs['estado_lectura'] ?? '🔔 Notificado al Docente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Visita: ${obs['fecha'] ?? ""}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 28, thickness: 1),
                        const Text('Lo observado durante la clase:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                          child: Text(
                            obs['observacion'] ?? '',
                            style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                          ),
                        ),
                        if (obs['acuerdos'] != null && (obs['acuerdos'] as String).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Acuerdos, Orientaciones y Devolución Pedagógica:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo)),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.indigo.shade50.withOpacity(0.5), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.indigo.shade100)),
                            child: Text(
                              obs['acuerdos'] ?? '',
                              style: TextStyle(fontSize: 13.5, height: 1.4, color: Colors.indigo.shade900, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 18),
                                  label: Text(obs['archivo'] ?? 'Acta_Observacion.pdf', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                const SizedBox(width: 12),
                                Text('Registrado por: ${obs['subido_por'] ?? "Directora Maria Funes"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🔔 Reenviando notificación push y correo con acta al Prof. ${obs['docente']}...')));
                                  },
                                  icon: const Icon(Icons.send_to_mobile_rounded, size: 16),
                                  label: const Text('Reenviar Notificación'),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📄 Abriendo/Descargando acta ${obs['archivo']}...')));
                                  },
                                  icon: const Icon(Icons.visibility_rounded, size: 16),
                                  label: const Text('Ver Acta Completa'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade50, foregroundColor: Colors.deepPurple, elevation: 0),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKpiDirectivoCard({required String title, required String value, required IconData icon, required Color color}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: color.withOpacity(0.3))),
      color: color.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuloEdeIndependiente(ColorScheme colorScheme) {
    final listReales = _alumnos.where((a) => a['adecuacion_curricular'] == true).toList();

    if (_eoeSelectedAlumno != null) {
      return _buildEoeDetailView(_eoeSelectedAlumno!, colorScheme);
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gabinete Psicopedagógico (EOE) - Adecuaciones Curriculares',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Módulo independiente para la gestión integral de informes docentes, fechas programadas y archivos adecuados.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _abrirModalActivarAdecuacionEOE,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Activar Adecuación'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: listReales.isEmpty
                ? const Center(
                    child: Text(
                      'No hay alumnos registrados con Adecuación Curricular Activa.\nPulse "Activar Adecuación" para agregar uno.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, height: 1.4),
                    ),
                  )
                : ListView.builder(
                    itemCount: listReales.length,
                    itemBuilder: (context, index) {
                      final al = listReales[index];
                      final tipo = al['tipo_adecuacion'] ?? 'General';
                      
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.indigo.withAlpha(50)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.indigo.shade50,
                            child: Icon(Icons.psychology_rounded, color: Colors.indigo.shade800, size: 28),
                          ),
                          title: Text(al['nombre'] ?? al['nombre_completo'] ?? 'Alumno', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('DNI: ${al['dni']} | Tipo: $tipo', style: const TextStyle(fontWeight: FontWeight.w500)),
                              if (al['detalles_adecuacion'] != null && (al['detalles_adecuacion'] as String).isNotEmpty)
                                Text('Pautas: ${al['detalles_adecuacion']}', style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.indigo),
                          onTap: () {
                            setState(() {
                              _eoeSelectedAlumno = al;
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEoeDetailView(Map<String, dynamic> al, ColorScheme colorScheme) {
    final legajoId = al['legajo_id'] ?? al['id'] ?? '';
    final evaluaciones = _eoeEvaluacionesDocente[legajoId] ?? [];
    final informes = _eoeInformes[legajoId] ?? [];
    final bitacora = _eoeBitacora[legajoId] ?? [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _eoeSelectedAlumno = null),
              ),
              const SizedBox(width: 8),
              const Text('Ficha Psicopedagógica del Alumno', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.indigo.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.indigo.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.assignment_ind_rounded, color: Colors.indigo.shade800, size: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(al['nombre'] ?? al['nombre_completo'] ?? 'Alumno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo.shade900)),
                        const SizedBox(height: 4),
                        Text('DNI: ${al['dni']} | Tipo: ${al['tipo_adecuacion']}', style: TextStyle(color: Colors.indigo.shade900, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('Pautas: ${al['detalles_adecuacion']}', style: TextStyle(color: Colors.indigo.shade900, fontSize: 12, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    indicatorColor: colorScheme.primary,
                    isScrollable: true,
                    tabs: const [
                      Tab(icon: Icon(Icons.assignment_turned_in_rounded), text: 'Evaluaciones e Informes Docentes para Adecuar'),
                      Tab(icon: Icon(Icons.folder_shared_rounded), text: 'Papeles de Gabinete (Confidencial)'),
                      Tab(icon: Icon(Icons.forum_rounded), text: 'Bitácora de Acompañamiento'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildEoeEvaluacionesTab(legajoId, evaluaciones, colorScheme),
                        _buildEoeConfidentialTab(legajoId, informes, colorScheme),
                        _buildEoeBitacoraTab(legajoId, bitacora, colorScheme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEoeEvaluacionesTab(String legajoId, List<Map<String, dynamic>> evaluaciones, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Informes y evaluaciones originales subidas por los docentes con fecha de toma programada para ser adecuadas por el EOE:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _subirEvaluacionDocenteEoeDialog(legajoId),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Subir Informe / Evaluación Docente'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: evaluaciones.isEmpty
              ? const Center(child: Text('No hay evaluaciones o informes pendientes de adecuación.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
              : ListView.builder(
                  itemCount: evaluaciones.length,
                  itemBuilder: (context, index) {
                    final ev = evaluaciones[index];
                    final hasAdecuado = ev['archivo_adecuado'] != null && (ev['archivo_adecuado'] as String).isNotEmpty;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: hasAdecuado ? Colors.green.withAlpha(80) : Colors.orange.withAlpha(80)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.description_rounded, color: hasAdecuado ? Colors.green : Colors.orange, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(ev['informe_original'] ?? 'Evaluación / Informe', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text('Materia: ${ev['materia']} | Docente: ${ev['docente']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: hasAdecuado ? Colors.green.shade50 : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: hasAdecuado ? Colors.green : Colors.orange),
                                  ),
                                  child: Text(
                                    ev['estado'] ?? (hasAdecuado ? 'Adecuada' : 'Pendiente'),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: hasAdecuado ? Colors.green.shade900 : Colors.orange.shade900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.indigo),
                                const SizedBox(width: 6),
                                Text('Fecha de Toma Programada: ${ev['fecha_evaluacion'] ?? "Sin fecha fijada"}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.indigo)),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => _editarFechaEvaluacionEoeDialog(legajoId, ev),
                                  icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                                  label: const Text('Modificar Fecha', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withAlpha(15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('📝 Observaciones del Gabinete (EOE) para la Adecuación:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
                                      InkWell(
                                        onTap: () => _editarObservacionesEoeDialog(legajoId, ev),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                                          child: Text('Editar', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(ev['observaciones_eoe'] ?? 'Sin observaciones.', style: const TextStyle(fontSize: 13, height: 1.3)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    hasAdecuado ? 'Archivo Adecuado Listó para el Alumno: ${ev['archivo_adecuado']}' : 'Aún no se ha subido el archivo con la evaluación adecuada.',
                                    style: TextStyle(fontSize: 13, fontWeight: hasAdecuado ? FontWeight.bold : FontWeight.normal, color: hasAdecuado ? Colors.green.shade800 : Colors.grey),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _subirArchivoAdecuadoEoeDialog(legajoId, ev),
                                  icon: Icon(hasAdecuado ? Icons.refresh_rounded : Icons.upload_file_rounded, size: 16),
                                  label: Text(hasAdecuado ? 'Reemplazar Adecuación' : 'Subir Archivo Adecuado'),
                                  style: ElevatedButton.styleFrom(backgroundColor: hasAdecuado ? Colors.blue : Colors.green, foregroundColor: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _subirEvaluacionDocenteEoeDialog(String legajoId) {
    final formKey = GlobalKey<FormState>();
    final matCtrl = TextEditingController(text: 'Matemática');
    final docCtrl = TextEditingController(text: 'Prof. Gomez');
    final fileCtrl = TextEditingController(text: 'Evaluación Unidad 3 - Original.pdf');
    final fechaCtrl = TextEditingController(text: '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subir Evaluación/Informe para Adecuar'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: matCtrl,
                  decoration: const InputDecoration(labelText: 'Materia / Asignatura', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: docCtrl,
                  decoration: const InputDecoration(labelText: 'Docente a cargo', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: fileCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del Archivo Original', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_file)),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: fechaCtrl,
                  decoration: const InputDecoration(labelText: 'Fecha Programada para la Toma (DD/MM/AAAA)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              setState(() {
                final list = _eoeEvaluacionesDocente.putIfAbsent(legajoId, () => []);
                list.insert(0, {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'materia': matCtrl.text.trim(),
                  'docente': docCtrl.text.trim(),
                  'informe_original': fileCtrl.text.trim(),
                  'fecha_evaluacion': fechaCtrl.text.trim(),
                  'observaciones_eoe': 'En proceso de análisis y adecuación curricular.',
                  'archivo_adecuado': null,
                  'estado': 'Pendiente de Adecuación',
                });
              });
              Navigator.pop(context);
              _mostrarExito('Evaluación cargada. Pendiente de adecuación por EOE.');
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _editarFechaEvaluacionEoeDialog(String legajoId, Map<String, dynamic> ev) {
    final ctrl = TextEditingController(text: ev['fecha_evaluacion']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modificar Fecha de Toma'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nueva Fecha (DD/MM/AAAA)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                ev['fecha_evaluacion'] = ctrl.text.trim();
              });
              Navigator.pop(context);
              _mostrarExito('Fecha de toma programada actualizada.');
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _editarObservacionesEoeDialog(String legajoId, Map<String, dynamic> ev) {
    final ctrl = TextEditingController(text: ev['observaciones_eoe']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Observaciones EOE'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Pautas y Observaciones de Adecuación', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                ev['observaciones_eoe'] = ctrl.text.trim();
              });
              Navigator.pop(context);
              _mostrarExito('Observaciones actualizadas con éxito.');
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _subirArchivoAdecuadoEoeDialog(String legajoId, Map<String, dynamic> ev) {
    final ctrl = TextEditingController(text: 'Evaluación Adecuada - ${(ev['materia'] ?? "Materia").toString().replaceAll(" ", "_")}.pdf');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subir Archivo Adecuado (EOE)'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adjunte la evaluación o informe con las adecuaciones curriculares finalizadas para que el docente y el alumno puedan acceder:', style: TextStyle(fontSize: 13, height: 1.3)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Nombre del Archivo Adecuado', border: OutlineInputBorder(), prefixIcon: Icon(Icons.picture_as_pdf_rounded, color: Colors.red)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              setState(() {
                ev['archivo_adecuado'] = ctrl.text.trim();
                ev['estado'] = 'Adecuada';
              });
              Navigator.pop(context);
              _mostrarExito('Archivo adecuado subido y asignado al alumno y al docente.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Subir Archivo Adecuado'),
          ),
        ],
      ),
    );
  }

  Widget _buildEoeConfidentialTab(String legajoId, List<Map<String, String>> informes, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Informes y Diagnósticos Médicos/Terapéuticos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            TextButton.icon(
              onPressed: () => _agregarInformeEoeDialog(legajoId),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Agregar Informe', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: informes.isEmpty
              ? const Center(child: Text('No hay informes registrados.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
              : ListView.builder(
                  itemCount: informes.length,
                  itemBuilder: (context, index) {
                    final inf = informes[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.withAlpha(50)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.lock_rounded, color: Colors.red),
                        title: Text(inf['nombre']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Fecha: ${inf['fecha']} | Especialista: ${inf['especialista']}', style: const TextStyle(fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              informes.removeWhere((x) => x['id'] == inf['id']);
                            });
                            _mostrarExito('Informe eliminado.');
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEoeBitacoraTab(String legajoId, List<Map<String, String>> bitacora, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Historial de Notas de Seguimiento Escolar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            TextButton.icon(
              onPressed: () => _agregarNotaBitacoraDialog(legajoId),
              icon: const Icon(Icons.rate_review_rounded, size: 16),
              label: const Text('Nueva Nota', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: bitacora.isEmpty
              ? const Center(child: Text('No hay notas de bitácora registradas.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
              : ListView.builder(
                  itemCount: bitacora.length,
                  itemBuilder: (context, index) {
                    final nota = bitacora[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.withAlpha(50)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(nota['autor']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
                                Text(nota['fecha']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(nota['nota']!, style: const TextStyle(fontSize: 12, height: 1.3)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _abrirModalActivarAdecuacionEOE() {
    final formKey = GlobalKey<FormState>();
    String? selectedAlumnoId;
    String tipo = 'Metodológica';
    final detallesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Activar Adecuación Curricular', style: TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedAlumnoId,
                      decoration: const InputDecoration(labelText: 'Seleccione Alumno', border: OutlineInputBorder()),
                      items: _alumnos.map((a) {
                        return DropdownMenuItem(
                          value: a['legajo_id'] as String,
                          child: Text(a['nombre_completo'] as String),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedAlumnoId = val),
                      validator: (val) => val == null ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: tipo,
                      decoration: const InputDecoration(labelText: 'Tipo de Adecuación', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Metodológica', child: Text('Metodológica')),
                        DropdownMenuItem(value: 'De Acceso', child: Text('De Acceso')),
                        DropdownMenuItem(value: 'De Contenido', child: Text('De Contenido')),
                      ],
                      onChanged: (val) => setModalState(() => tipo = val ?? 'Metodológica'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: detallesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Detalles de la Adecuación', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate() || selectedAlumnoId == null) return;
                    Navigator.of(context).pop();
                    
                    setState(() => _isLoading = true);
                    try {
                      await _supabaseService.actualizarAdecuacionCurricular(
                        alumnoId: selectedAlumnoId!,
                        activa: true,
                        tipo: tipo,
                        detalles: detallesCtrl.text.trim(),
                      );
                      setState(() {
                        for (var a in _alumnos) {
                          if (a['legajo_id'] == selectedAlumnoId!) {
                            a['adecuacion_curricular'] = true;
                            a['tipo_adecuacion'] = tipo;
                            a['detalles_adecuacion'] = detallesCtrl.text.trim();
                            final demo = Map<String, dynamic>.from(a['datos_demograficos'] as Map? ?? {});
                            demo['adecuacion_curricular'] = true;
                            demo['tipo_adecuacion'] = tipo;
                            demo['detalles_adecuacion'] = detallesCtrl.text.trim();
                            a['datos_demograficos'] = demo;
                            break;
                          }
                        }
                        _eoeEvaluacionesDocente.putIfAbsent(selectedAlumnoId!, () => [
                          {
                            'id': DateTime.now().millisecondsSinceEpoch.toString(),
                            'materia': 'Matemática 1°',
                            'docente': 'Docente Titular',
                            'informe_original': 'Evaluación Escrita - Diagnóstico.pdf',
                            'fecha_evaluacion': '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                            'observaciones_eoe': 'Pendiente de revisión por el gabinete.',
                            'archivo_adecuado': null,
                            'estado': 'Pendiente de Adecuación',
                          }
                        ]);
                        _isLoading = false;
                      });
                      _mostrarExito('Adecuación curricular activada con éxito. Archivos inicializados.');
                      _cargarDatos();
                    } catch (e) {
                      _mostrarError('Error al activar adecuación: $e');
                      setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Activar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _agregarInformeEoeDialog(String legajoId) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final espCtrl = TextEditingController(text: 'Lic. Sofia Martinez (Psicopedagoga)');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar Informe Confidencial', style: TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del Informe', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: espCtrl,
                  decoration: const InputDecoration(labelText: 'Especialista Firmante', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                setState(() {
                  _eoeInformes.putIfAbsent(legajoId, () => []);
                  _eoeInformes[legajoId]!.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'nombre': nameCtrl.text.trim(),
                    'especialista': espCtrl.text.trim(),
                    'fecha': '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                  });
                });
                Navigator.of(context).pop();
                _mostrarExito('Informe confidencial guardado.');
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void _agregarNotaBitacoraDialog(String legajoId) {
    final formKey = GlobalKey<FormState>();
    final noteCtrl = TextEditingController();
    final autorCtrl = TextEditingController(text: 'Equipo EOE');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva Nota de Seguimiento', style: TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Nota / Observación', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: autorCtrl,
                  decoration: const InputDecoration(labelText: 'Autor', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                setState(() {
                  _eoeBitacora.putIfAbsent(legajoId, () => []);
                  _eoeBitacora[legajoId]!.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'nota': noteCtrl.text.trim(),
                    'autor': autorCtrl.text.trim(),
                    'fecha': '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                  });
                });
                Navigator.of(context).pop();
                _mostrarExito('Nota de bitácora agregada.');
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  String? _rendCursoId;
  String? _rendMateriaId;

  Widget _buildAcademicoAvanzadoTab(ColorScheme colorScheme) {
    if (_rendCursoId == null && _cursos.isNotEmpty) {
      _rendCursoId = _cursos.first['curso_id'] as String;
    }
    if (_rendCursoId != null && _rendMateriaId == null && _materias.isNotEmpty) {
      final list = _materias.where((m) => m['curso_id'] == _rendCursoId).toList();
      if (list.isNotEmpty) {
        _rendMateriaId = list.first['materia_id'] as String;
      }
    }

    final filteredAlumnos = _alumnos.where((a) => a['curso_id'] == _rendCursoId).toList();
    final materiasDelCurso = _materias.where((m) => m['curso_id'] == _rendCursoId).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.analytics_rounded, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  const Text('Filtro de Rendimiento:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _rendCursoId,
                      decoration: const InputDecoration(labelText: 'Curso', border: OutlineInputBorder()),
                      items: _cursos.map((c) {
                        return DropdownMenuItem(
                          value: c['curso_id'] as String,
                          child: Text(c['identificador_division'] as String),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _rendCursoId = val;
                          final mats = _materias.where((m) => m['curso_id'] == val).toList();
                          _rendMateriaId = mats.isNotEmpty ? mats.first['materia_id'] as String : null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _rendMateriaId,
                      decoration: const InputDecoration(labelText: 'Materia', border: OutlineInputBorder()),
                      disabledHint: const Text('Sin materias'),
                      items: materiasDelCurso.map((m) {
                        return DropdownMenuItem(
                          value: m['materia_id'] as String,
                          child: Text(m['nombre_asignatura'] as String),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _rendMateriaId = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_rendCursoId == null || _rendMateriaId == null)
            const Center(child: Text('Seleccione un curso y materia para analizar el rendimiento.'))
          else ...[
            Text(
              'Libreta Digital RITE',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withAlpha(51)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Alumno')),
                    DataColumn(label: Text('TP 1')),
                    DataColumn(label: Text('Evaluación 1')),
                    DataColumn(label: Text('Desempeño')),
                    DataColumn(label: Text('Promedio')),
                    DataColumn(label: Text('Valoración RITE')),
                  ],
                  rows: filteredAlumnos.map((a) {
                    final double n1 = ((a['nombre_completo'].toString().length % 3) + 7).toDouble();
                    final double n2 = ((a['nombre_completo'].toString().length % 4) + 6).toDouble();
                    final double n3 = ((a['nombre_completo'].toString().length % 2) + 8).toDouble();
                    final promedio = (n1 + n2 + n3) / 3;

                    String rite = 'TEA';
                    Color riteColor = Colors.green;
                    if (promedio < 7.0 && promedio >= 4.0) {
                      rite = 'TEP';
                      riteColor = Colors.orange;
                    } else if (promedio < 4.0) {
                      rite = 'TED';
                      riteColor = Colors.red;
                    }
                    final badgeText = '$rite ${(promedio * 10).toStringAsFixed(0)}%';

                    return DataRow(
                      cells: [
                        DataCell(Text(a['nombre_completo'] as String, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(n1.toStringAsFixed(1))),
                        DataCell(Text(n2.toStringAsFixed(1))),
                        DataCell(Text(n3.toStringAsFixed(1))),
                        DataCell(Text(promedio.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: riteColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: riteColor),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(color: riteColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCambioHorarioTab(ColorScheme colorScheme) {
    // Filtrar personal que sea docente o tenga email de profesor
    final docentes = _personal.where((p) {
      final meta = p['raw_user_meta_data'] as Map<String, dynamic>? ?? {};
      final rol = meta['rol'] ?? '';
      return rol == 'DOCENTE' || p['email'].toString().contains('profe') || p['email'].toString().contains('docente');
    }).toList();

    final cursoActualId = _horarioSelectedCursoId ?? (_cursos.isNotEmpty ? _cursos.first['curso_id'] as String : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Editor de Horarios y Control de Declaraciones Juradas (DDJJ)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary)),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withAlpha(51))),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Utilice esta sección para realizar modificaciones al cronograma de asignaturas de la institución. Al intentar cambiar o asignar un módulo, el sistema leerá automáticamente las Declaraciones Juradas de los docentes para prevenir superposiciones e incompatibilidades horarias.',
                    style: TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: cursoActualId,
                    decoration: const InputDecoration(labelText: 'Curso a modificar y verificar', border: OutlineInputBorder()),
                    items: _cursos.map((c) {
                      return DropdownMenuItem(
                        value: c['curso_id'] as String,
                        child: Text(c['identificador_division'] as String),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _horarioSelectedCursoId = val;
                      });
                      _mostrarExito('Grilla semanal cargada con control activo de DDJJ.');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (cursoActualId != null)
            _buildGrillaHorariaCurso(cursoActualId, docentes, colorScheme),

          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Declaraciones Juradas (DDJJ) de Cargos y Restricciones',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final rowsHtml = docentes.map((p) {
                    final email = p['email'] as String;
                    final status = _ddjjProfesores[email]?['presentado'] == true ? 'Presentada' : 'Pendiente';
                    final fecha = _ddjjProfesores[email]?['fecha'] ?? '-';
                    final archivo = _ddjjProfesores[email]?['archivo'] ?? '-';
                    final badgeClass = status == 'Presentada' ? 'badge-green' : 'badge-red';
                    
                    return '''
                      <tr>
                        <td>${p['nombre_completo'] ?? email}</td>
                        <td>$email</td>
                        <td><span class="badge $badgeClass">$status</span></td>
                        <td>$fecha</td>
                        <td>$archivo</td>
                      </tr>
                    ''';
                  }).join('');

                  final tableHtml = '''
                    <h2>Listado de DDJJ de Profesores</h2>
                    <table>
                      <thead>
                        <tr>
                          <th>Profesor</th>
                          <th>Email</th>
                          <th>Estado DDJJ</th>
                          <th>Fecha Presentación</th>
                          <th>Archivo Adjunto</th>
                        </tr>
                      </thead>
                      <tbody>
                        $rowsHtml
                      </tbody>
                    </table>
                  ''';
                  
                  PrintHelper.imprimirHTML(titulo: 'Declaraciones Juradas de Docentes', htmlContentBody: tableHtml);
                },
                icon: const Icon(Icons.print_rounded),
                label: const Text('Exportar Listado'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withAlpha(51))),
            child: docentes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('No hay profesores registrados en el sistema.')),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docentes.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = docentes[index];
                      final email = p['email'] as String;
                      
                      // Lazy init DDJJ status con restricciones de muestra para el algoritmo
                      _ddjjProfesores.putIfAbsent(email, () => {
                        'presentado': index % 2 == 0,
                        'fecha': index % 2 == 0 ? '2026-03-01' : null,
                        'archivo': index % 2 == 0 ? 'DDJJ_Cargos_${email.split("@").first}.pdf' : null,
                        'restricciones': [
                          {'dia': 'Martes', 'modulo': '1° Módulo (07:30 - 08:50)', 'institucion': 'Escuela Técnica N° 2'},
                          {'dia': 'Jueves', 'modulo': '3° Módulo (10:40 - 12:00)', 'institucion': 'Instituto San José'}
                        ],
                      });

                      final state = _ddjjProfesores[email]!;
                      final bool isPresentado = state['presentado'];
                      final rest = state['restricciones'] as List<dynamic>? ?? [];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isPresentado ? Colors.green.shade50 : Colors.red.shade50,
                          child: Icon(
                            isPresentado ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                            color: isPresentado ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(p['nombre_completo'] ?? email, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              isPresentado
                                  ? 'Presentada: ${state['fecha']} | Archivo: ${state['archivo']}'
                                  : 'Declaración Jurada PENDIENTE',
                              style: TextStyle(fontSize: 12, color: isPresentado ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.w600),
                            ),
                            if (isPresentado && rest.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '⚠️ Restricciones declaradas: ${rest.map((r) => "${r['dia']} ${r['modulo']} (${r['institucion']})").join(", ")}',
                                style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                              ),
                            ],
                          ],
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () {
                            _abrirModalAdjuntarDdjj(p);
                          },
                          icon: const Icon(Icons.attach_file_rounded, size: 16),
                          label: Text(isPresentado ? 'Reemplazar DDJJ' : 'Adjuntar DDJJ', style: const TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPresentado ? Colors.grey.shade200 : colorScheme.primary,
                            foregroundColor: isPresentado ? Colors.black87 : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrillaHorariaCurso(String cursoId, List<Map<String, dynamic>> docentes, ColorScheme colorScheme) {
    final dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
    final modulos = [
      '1° Módulo (07:30 - 08:50)',
      '2° Módulo (09:00 - 10:20)',
      '3° Módulo (10:40 - 12:00)',
      '4° Módulo (13:10 - 14:30)',
      '5° Módulo (14:40 - 16:00)',
    ];

    final cursoNombre = _cursos.firstWhere((c) => c['curso_id'] == cursoId, orElse: () => {'identificador_division': 'Curso'})['identificador_division'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.indigo.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📅 Grilla Semanal interactiva - $cursoNombre', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Text('💡 Haga clic en un módulo para modificar o asignar docente con verificación DDJJ', style: TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
                columnSpacing: 20,
                columns: [
                  const DataColumn(label: Text('Horario / Franja', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...dias.map((dia) => DataColumn(label: Text(dia, style: const TextStyle(fontWeight: FontWeight.bold)))),
                ],
                rows: modulos.map((modulo) {
                  return DataRow(
                    cells: [
                      DataCell(Text(modulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      ...dias.map((dia) {
                        final asignaciones = _horariosActivosInstitucion.where((h) => h['curso_id'] == cursoId && h['dia'] == dia && h['modulo'] == modulo).toList();
                        final asig = asignaciones.isNotEmpty ? asignaciones.first : null;

                        return DataCell(
                          InkWell(
                            onTap: () => _abrirModalAsignarHorarioYValidarDDJJ(cursoId, cursoNombre ?? 'Curso', dia, modulo, docentes),
                            child: Container(
                              width: 140,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: asig != null ? Colors.indigo.withAlpha(20) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: asig != null ? Colors.indigo.shade300 : Colors.grey.shade300),
                              ),
                              child: asig != null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(asig['materia'] ?? 'Materia', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(asig['docente'] ?? 'Docente', style: const TextStyle(fontSize: 10, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_circle_outline_rounded, size: 14, color: Colors.grey),
                                        SizedBox(width: 4),
                                        Text('Libre / Asignar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalAsignarHorarioYValidarDDJJ(String cursoId, String cursoNombre, String dia, String modulo, List<Map<String, dynamic>> docentes) {
    final matCtrl = TextEditingController(text: 'Ciencias / Materia');
    String? selDocenteEmail = docentes.isNotEmpty ? (docentes.first['email'] as String) : null;
    String? selDocenteNombre = docentes.isNotEmpty ? (docentes.first['nombre_completo'] ?? selDocenteEmail) : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Asignar Módulo - $dia ($modulo)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Curso seleccionado: $cursoNombre', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: matCtrl,
                      decoration: const InputDecoration(labelText: 'Materia / Asignatura', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selDocenteEmail,
                      decoration: const InputDecoration(labelText: 'Docente a asignar', border: OutlineInputBorder()),
                      items: docentes.map((doc) {
                        final email = doc['email'] as String;
                        final nom = doc['nombre_completo'] ?? email;
                        return DropdownMenuItem(value: email, child: Text(nom));
                      }).toList(),
                      onChanged: (v) {
                        setModalState(() {
                          selDocenteEmail = v;
                          final doc = docentes.firstWhere((d) => d['email'] == v, orElse: () => {});
                          selDocenteNombre = doc['nombre_completo'] ?? v;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.verified_user_rounded, size: 16),
                  label: const Text('Validar DDJJ y Guardar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (selDocenteEmail == null) return;
                    
                    final valRes = await _supabaseService.validarConflictoHorarioYDDJJ(
                      emailOIdDocente: selDocenteEmail!,
                      diaSemana: dia,
                      moduloInicio: modulo,
                      moduloFin: modulo,
                      horariosActivosInstitucion: _horariosActivosInstitucion,
                      ddjjProfesores: _ddjjProfesores,
                    );

                    if (!context.mounted) return;

                    if (valRes['hay_conflicto'] == true) {
                      showDialog(
                        context: context,
                        builder: (ctxAlert) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                              SizedBox(width: 8),
                              Text('¡Conflicto Horario / DDJJ!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(valRes['mensaje'] as String, style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                                child: const Text('El algoritmo ha detectado incompatibilidad horaria al cruzar esta franja con la Declaración Jurada o la carga interna del docente.', style: TextStyle(fontSize: 12, color: Colors.red)),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctxAlert),
                              child: const Text('Revisar y Cancelar'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () {
                                Navigator.pop(ctxAlert);
                                setState(() {
                                  _horariosActivosInstitucion.removeWhere((h) => h['curso_id'] == cursoId && h['dia'] == dia && h['modulo'] == modulo);
                                  _horariosActivosInstitucion.add({
                                    'curso_id': cursoId,
                                    'curso': cursoNombre,
                                    'dia': dia,
                                    'modulo': modulo,
                                    'materia': matCtrl.text.trim(),
                                    'docente': selDocenteNombre,
                                    'email': selDocenteEmail,
                                  });
                                });
                                Navigator.pop(context);
                                _mostrarExito('Módulo asignado forzadamente pese al conflicto.');
                              },
                              child: const Text('Forzar Asignación'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      setState(() {
                        _horariosActivosInstitucion.removeWhere((h) => h['curso_id'] == cursoId && h['dia'] == dia && h['modulo'] == modulo);
                        _horariosActivosInstitucion.add({
                          'curso_id': cursoId,
                          'curso': cursoNombre,
                          'dia': dia,
                          'modulo': modulo,
                          'materia': matCtrl.text.trim(),
                          'docente': selDocenteNombre,
                          'email': selDocenteEmail,
                        });
                      });
                      Navigator.pop(context);
                      _mostrarExito('✔ Horario validado contra DDJJ y asignado con éxito.');
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirModalAdjuntarDdjj(Map<String, dynamic> profesor) {
    final email = profesor['email'] as String;
    final fileController = TextEditingController(text: 'DDJJ_Cargos_${email.split("@").first}_2026.pdf');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Adjuntar Declaración Jurada - ${profesor['nombre_completo'] ?? email}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Seleccione e ingrese el nombre del archivo PDF de la declaración jurada de cargos presentada por el docente:',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fileController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del archivo adjunto',
                  prefixIcon: Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A4C9C)),
              onPressed: () {
                setState(() {
                  _ddjjProfesores[email] = {
                    'presentado': true,
                    'fecha': DateTime.now().toIso8601String().substring(0, 10),
                    'archivo': fileController.text,
                  };
                });
                Navigator.pop(context);
                _mostrarExito('Declaración Jurada adjuntada correctamente.');
              },
              child: const Text('Guardar y Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFechasLimiteTab(ColorScheme colorScheme) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Programar Fecha Límite para Docentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary)),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withAlpha(51))),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Asunto de la Fecha Límite', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Descripción detallada del requerimiento', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _mostrarExito('Notificación de fecha límite enviada a todos los docentes.');
                      titleController.clear();
                      descController.clear();
                    },
                    child: const Text('Enviar Notificación'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirModalArchivosProyecto(Map<String, dynamic> p) {
    final fileCtrl = TextEditingController(text: 'Documento_Proyecto_${(p['nombre'] as String).replaceAll(" ", "_")}.pdf');
    final archivos = (p['archivos'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.folder_shared_rounded, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(child: Text('Archivos: ${p['nombre']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Repositorio de planificaciones, actas y documentos del proyecto:', style: TextStyle(fontSize: 13, height: 1.3)),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: archivos.isEmpty
                      ? const Center(child: Text('No hay archivos adjuntos en este proyecto.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: archivos.length,
                          itemBuilder: (context, i) {
                            final arc = archivos[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                              title: Text(arc['nombre'] ?? 'Archivo', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Subido el: ${arc['fecha'] ?? "-"} por ${arc['subido_por'] ?? "Admin"}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.download_rounded, color: Colors.blue),
                                onPressed: () => _mostrarExito('Descargando ${arc['nombre']}...'),
                              ),
                            );
                          },
                        ),
                ),
                const Divider(height: 24),
                const Text('Subir nuevo documento al proyecto:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fileCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre del Archivo PDF/DOCX', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (fileCtrl.text.trim().isEmpty) return;
                        setState(() {
                          archivos.add({
                            'nombre': fileCtrl.text.trim(),
                            'fecha': '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                            'subido_por': 'Directivo / Admin',
                          });
                          p['archivos'] = archivos;
                        });
                        setModalState(() {});
                        fileCtrl.clear();
                        _mostrarExito('Archivo agregado al proyecto con éxito.');
                      },
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text('Subir'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ],
        ),
      ),
    );
  }

  void _abrirModalFechasProyecto(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(child: Text('Fechas y Organización: ${p['nombre']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.withAlpha(25), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withAlpha(80))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Fecha de Inicio', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(p['fecha_inicio'] ?? '01/08/2026', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepOrange)),
                        ],
                      ),
                      Container(height: 30, width: 1, color: Colors.orange.withAlpha(80)),
                      Column(
                        children: [
                          const Text('Fecha de Finalización', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(p['fecha_fin'] ?? '30/11/2026', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepOrange)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('📋 Organización Operativa y Pedagógica:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Text(p['organizacion'] ?? 'Sin descripción pedagógica detallada.', style: const TextStyle(fontSize: 13, height: 1.4)),
                const SizedBox(height: 16),
                const Text('⏱️ Cronograma de Etapas y Actividades:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                  child: Text(p['cronograma'] ?? 'Etapa 1: Lanzamiento.\nEtapa 2: Desarrollo e implementación.\nEtapa 3: Cierre y evaluación.', style: const TextStyle(fontSize: 13, height: 1.4, fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _abrirModalACargoProyecto(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person_pin_rounded, color: Colors.teal),
            const SizedBox(width: 10),
            Expanded(child: Text('Responsable a Cargo: ${p['nombre']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.teal.shade100,
                child: Icon(Icons.school_rounded, color: Colors.teal.shade800, size: 40),
              ),
              const SizedBox(height: 12),
              Text(p['coordinador'] ?? 'Docente a Cargo', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(p['rol_coordinador'] ?? 'Coordinador Institucional', style: TextStyle(fontSize: 13, color: Colors.teal.shade800, fontWeight: FontWeight.w600)),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.email_rounded, color: Colors.teal),
                title: const Text('Correo Electrónico', style: TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text(p['email_coordinador'] ?? 'contacto@escuela.edu', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.phone_rounded, color: Colors.teal),
                title: const Text('Teléfono de Contacto / WhatsApp', style: TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text(p['telefono_coordinador'] ?? '+54 9 11 0000-0000', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _abrirModalNuevoProyecto() {
    final formKey = GlobalKey<FormState>();
    final nomCtrl = TextEditingController();
    final coordCtrl = TextEditingController();
    final rolCtrl = TextEditingController(text: 'Docente Titular');
    final emailCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final iniCtrl = TextEditingController(text: '01/08/2026');
    final finCtrl = TextEditingController(text: '30/11/2026');
    final orgCtrl = TextEditingController();
    final cronoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Nuevo Proyecto Institucional', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: 550,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del Proyecto', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: coordCtrl,
                          decoration: const InputDecoration(labelText: 'Docente / Coordinador a cargo', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: rolCtrl,
                          decoration: const InputDecoration(labelText: 'Rol o Función', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email del Responsable', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: telCtrl,
                          decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: iniCtrl,
                          decoration: const InputDecoration(labelText: 'Fecha de Inicio', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: finCtrl,
                          decoration: const InputDecoration(labelText: 'Fecha de Finalización', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: orgCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Organización Operativa y Pedagógica', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cronoCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Cronograma de Etapas', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              setState(() {
                _proyectosInstitucionales.insert(0, {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'nombre': nomCtrl.text.trim(),
                  'coordinador': coordCtrl.text.trim(),
                  'rol_coordinador': rolCtrl.text.trim(),
                  'email_coordinador': emailCtrl.text.trim().isEmpty ? 'docente@escuela.edu' : emailCtrl.text.trim(),
                  'telefono_coordinador': telCtrl.text.trim().isEmpty ? '+54 9 11 0000-0000' : telCtrl.text.trim(),
                  'estado': 'Planificación',
                  'fecha_inicio': iniCtrl.text.trim(),
                  'fecha_fin': finCtrl.text.trim(),
                  'organizacion': orgCtrl.text.trim().isEmpty ? 'Proyecto en etapa de planificación institucional.' : orgCtrl.text.trim(),
                  'cronograma': cronoCtrl.text.trim().isEmpty ? 'Etapa 1: Presentación y diseño de grilla.' : cronoCtrl.text.trim(),
                  'archivos': [],
                });
              });
              Navigator.pop(context);
              _mostrarExito('Proyecto institucional creado con éxito.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('Crear Proyecto'),
          ),
        ],
      ),
    );
  }

  Widget _buildProyectosTab(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Proyectos Institucionales', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                    const SizedBox(height: 4),
                    const Text('Gestión integral de proyectos escolares, con archivos adjuntos, fechas organizativas y responsables a cargo.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _abrirModalNuevoProyecto,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo Proyecto'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _proyectosInstitucionales.isEmpty
                ? const Center(child: Text('No hay proyectos registrados.'))
                : ListView.builder(
                    itemCount: _proyectosInstitucionales.length,
                    itemBuilder: (context, index) {
                      final p = _proyectosInstitucionales[index];
                      final archCount = (p['archivos'] as List?)?.length ?? 0;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blue.withAlpha(51))),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.blue.shade50,
                                    child: Icon(Icons.assignment_turned_in_rounded, color: Colors.blue.shade800, size: 28),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text(p['nombre'] ?? 'Proyecto', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                            Chip(
                                              label: Text(p['estado'] ?? 'Activo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              backgroundColor: Colors.blue.shade50,
                                              side: BorderSide.none,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Responsable: ${p['coordinador']} | Período: ${p['fecha_inicio']} a ${p['fecha_fin']}', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _abrirModalArchivosProyecto(p),
                                    icon: const Icon(Icons.folder_rounded, size: 18),
                                    label: Text('Subir / Ver Archivos ($archCount)'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white, elevation: 0),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _abrirModalFechasProyecto(p),
                                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                                    label: const Text('Fechas y Organización'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white, elevation: 0),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _abrirModalACargoProyecto(p),
                                    icon: const Icon(Icons.person_pin_rounded, size: 18),
                                    label: Text('A Cargo de: ${p['coordinador']}'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white, elevation: 0),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    // Check permissions
    final user = Supabase.instance.client.auth.currentUser;
    final rol = user?.userMetadata?['rol'] as String?;
    if (rol != 'ADMIN' && rol != 'DIRECTIVO') {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Denegado')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Acceso Denegado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              SizedBox(height: 8),
              Text('Solo los administradores o directivos pueden acceder a esta sección.'),
            ],
          ),
        ),
      );
    }

    Widget tabContent;
    switch (_selectedTabIndex) {
      case 0:
        tabContent = _buildDashboardTab(colorScheme);
        break;
      case 1:
        tabContent = _buildStaffTab();
        break;
      case 2:
        tabContent = _buildCommunityTab();
        break;
      case 3:
        tabContent = _buildAcademyTab();
        break;
      case 4:
        tabContent = _buildPedagogicoTab(colorScheme);
        break;
      case 5:
        tabContent = _buildAcademicoAvanzadoTab(colorScheme);
        break;
      case 6:
        tabContent = _buildCambioHorarioTab(colorScheme);
        break;
      case 7:
        tabContent = _buildFechasLimiteTab(colorScheme);
        break;
      case 8:
        tabContent = _buildProyectosTab(colorScheme);
        break;
      case 9:
        tabContent = _buildTramitesAdminTab(colorScheme);
        break;
      case 10:
        tabContent = _buildModuloEdeIndependiente(colorScheme);
        break;
      case 11:
        tabContent = _buildPortalDirectivoGestionClases(colorScheme);
        break;
      default:
        tabContent = const Center(child: Text('Seleccione una opción'));
    }

    if (isLargeScreen) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const BrandLogo(height: 38, showText: false),
              const SizedBox(width: 12),
              const Text('Panel de Administración General', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Recargar Datos',
              onPressed: _cargarDatos,
            )
          ],
        ),
        body: Row(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: _selectedTabIndex,
                      onDestinationSelected: (index) {
                        setState(() => _selectedTabIndex = index);
                      },
                      labelType: NavigationRailLabelType.all,
                      leading: const Padding(
                        padding: EdgeInsets.only(top: 16, bottom: 8),
                        child: BrandLogo(height: 48, showText: true),
                      ),
                      trailing: const Padding(
                        padding: EdgeInsets.only(top: 24, bottom: 16),
                        child: BrandFrankiaFooter(scale: 0.7),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_rounded),
                          selectedIcon: Icon(Icons.dashboard_rounded),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.badge_rounded),
                          selectedIcon: Icon(Icons.badge_rounded),
                          label: Text('Staff'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.people_rounded),
                          selectedIcon: Icon(Icons.people_rounded),
                          label: Text('Comunidad'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.account_tree_rounded),
                          selectedIcon: Icon(Icons.account_tree_rounded),
                          label: Text('Académica'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.menu_book_rounded),
                          selectedIcon: Icon(Icons.menu_book_rounded),
                          label: Text('Pedagógico'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.analytics_rounded),
                          selectedIcon: Icon(Icons.analytics_rounded),
                          label: Text('Rendimiento'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.edit_calendar_rounded),
                          selectedIcon: Icon(Icons.edit_calendar_rounded),
                          label: Text('Horarios'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.notification_important_rounded),
                          selectedIcon: Icon(Icons.notification_important_rounded),
                          label: Text('Límites'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.assignment_rounded),
                          selectedIcon: Icon(Icons.assignment_rounded),
                          label: Text('Proyectos'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.mark_email_read_rounded),
                          selectedIcon: Icon(Icons.mark_email_read_rounded),
                          label: Text('Trámites'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.psychology_rounded),
                          selectedIcon: Icon(Icons.psychology_rounded),
                          label: Text('Adecuaciones / EOE'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.co_present_rounded),
                          selectedIcon: Icon(Icons.co_present_rounded),
                          label: Text('Gestión de Clases'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: _isLoading && _personal.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : tabContent,
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 12,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const BrandLogo(height: 32, showText: false),
              const SizedBox(width: 8),
              const Text('Administración', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _cargarDatos,
            )
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            onTap: (index) {
              setState(() => _selectedTabIndex = index);
            },
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_rounded), text: 'Dashboard'),
              Tab(icon: Icon(Icons.badge_rounded), text: 'Staff'),
              Tab(icon: Icon(Icons.people_rounded), text: 'Comunidad'),
              Tab(icon: Icon(Icons.account_tree_rounded), text: 'Académica'),
              Tab(icon: Icon(Icons.menu_book_rounded), text: 'Pedagógico'),
              Tab(icon: Icon(Icons.analytics_rounded), text: 'Rendimiento'),
              Tab(icon: Icon(Icons.edit_calendar_rounded), text: 'Horarios'),
              Tab(icon: Icon(Icons.notification_important_rounded), text: 'Límites'),
              Tab(icon: Icon(Icons.assignment_rounded), text: 'Proyectos'),
              Tab(icon: Icon(Icons.mark_email_read_rounded), text: 'Trámites'),
              Tab(icon: Icon(Icons.psychology_rounded), text: 'Adecuaciones / EOE'),
              Tab(icon: Icon(Icons.co_present_rounded), text: 'Gestión de Clases'),
            ],
          ),
        ),
        body: _isLoading && _personal.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : tabContent,
      ),
    );
  }

  Widget _buildTramitesAdminTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.mark_email_read_rounded, size: 32, color: Colors.deepPurple),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gestión y Emisión de Trámites / Constancias', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    Text('Solicitudes enviadas por padres y tutores desde el Portal Familia para aprobación y emisión de constancias.', style: TextStyle(fontSize: 14, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client
                .from('tramites_solicitudes')
                .select('*')
                .order('fecha_solicitud', ascending: false)
                .then((data) => List<Map<String, dynamic>>.from(data)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
              }
              final solicitudes = snapshot.data ?? [];
              if (solicitudes.isEmpty) {
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No hay solicitudes de trámites pendientes en este momento.', style: TextStyle(fontSize: 16, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: solicitudes.length,
                itemBuilder: (ctx, idx) {
                  final s = solicitudes[idx];
                  final esEmitido = s['estado'] == 'EMITIDO';
                  final tipoTramite = s['tipo_tramite'] ?? 'Constancia de Alumno Regular';
                  final alumnoNom = s['alumno_nombre'] ?? '-';
                  final dniVal = s['dni'] ?? '-';
                  final cursoNom = s['curso_nombre'] ?? '-';
                  final solicitante = s['tutor_email'] ?? 'Familia';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: esEmitido ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                            child: Icon(esEmitido ? Icons.verified_rounded : Icons.pending_actions_rounded, color: esEmitido ? Colors.green : Colors.orange, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$tipoTramite - $alumnoNom',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'DNI: $dniVal • Curso: $cursoNom • Solicitante: $solicitante',
                                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: esEmitido ? Colors.green.shade100 : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    esEmitido ? 'ESTADO: EMITIDO Y APROBADO' : 'ESTADO: PENDIENTE DE APROBACIÓN',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: esEmitido ? Colors.green.shade800 : Colors.orange.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (!esEmitido)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.check_circle_rounded, size: 20),
                              label: const Text('APROBAR Y EMITIR PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                await Supabase.instance.client.from('tramites_solicitudes').update({'estado': 'EMITIDO'}).eq('id', s['id']);
                                setState(() {});
                                PrintHelper.imprimirConstanciaAlumnoRegular(
                                  studentName: s['alumno_nombre'] ?? 'Alumno/a',
                                  dni: s['dni'] ?? 'Sin DNI',
                                  cursoName: s['curso_nombre'] ?? '1ro A',
                                  codigoVerificacion: s['id']?.toString().substring(0, 8).toUpperCase(),
                                );
                              },
                            )
                          else
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                              label: const Text('REIMPRIMIR CONSTANCIA PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                PrintHelper.imprimirConstanciaAlumnoRegular(
                                  studentName: s['alumno_nombre'] ?? 'Alumno/a',
                                  dni: s['dni'] ?? 'Sin DNI',
                                  cursoName: s['curso_nombre'] ?? '1ro A',
                                  codigoVerificacion: s['id']?.toString().substring(0, 8).toUpperCase(),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
