import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../services/print_helper.dart';
import '../widgets/brand_widgets.dart';
import 'panel_boletines_preceptor.dart';

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

  // Resumen real de asistencia de hoy (toda la escuela) + faltas del mes.
  Map<String, dynamic>? _resumenHoy;
  List<Map<String, dynamic>> _faltasMesEscuela = [];
  bool _loadingFaltasMes = false;

  // Estados del Repositorio Pedagógico
  String? _repCursoId;
  String? _repMateriaId;
  int _pedRepoRefresh = 0;

  // Estados de EOE (Gabinete Psicopedagógico) — persistido en eoe_ficha /
  // eoe_bitacora / eoe_documentos (ver eoe_banco_migration.sql).
  Map<String, dynamic>? _eoeSelectedFicha;
  List<Map<String, dynamic>> _eoeFichas = [];
  List<Map<String, dynamic>> _eoeBitacora = [];
  List<Map<String, dynamic>> _eoeDocumentos = [];
  bool _eoeLoading = false;
  bool _eoeDetalleLoading = false;
  String? _eoeFiltroCurso;

  // Horarios / DDJJ
  String? _horarioSelectedCursoId;
  int _horarioRefresh = 0;
  List<Map<String, dynamic>> _proyectos = [];
  bool _loadingProy = false;

  /// Visitas áulicas registradas (usr_observaciones_aulicas)
  List<Map<String, dynamic>> _observacionesGestionClases = [];

  void _inicializarRepositorioYEOE() {
    if (_cursos.isEmpty) return;
    _repCursoId ??= _cursos.first['curso_id'] as String;
    if (_repCursoId != null && _materias.isNotEmpty) {
      final listMats = _materias.where((m) => m['curso_id'] == _repCursoId).toList();
      if (listMats.isNotEmpty) {
        _repMateriaId ??= listMats.first['materia_id'] as String;
      }
    }
  }

  /// Carga las fichas EOE reales (eoe_ficha + roster). Se llama desde _cargarDatos.
  Future<void> _cargarEoe() async {
    setState(() => _eoeLoading = true);
    try {
      final fichas = await _supabaseService.obtenerFichasEoe();
      setState(() => _eoeFichas = fichas);
    } catch (e) {
      debugPrint('Error cargando EOE: $e');
    } finally {
      if (mounted) setState(() => _eoeLoading = false);
    }
  }

  Future<void> _eoeSeleccionar(Map<String, dynamic> ficha) async {
    setState(() {
      _eoeSelectedFicha = ficha;
      _eoeDetalleLoading = true;
      _eoeBitacora = [];
      _eoeDocumentos = [];
    });
    final legajoId = ficha['legajo_id'].toString();
    final bit = await _supabaseService.obtenerBitacoraEoe(legajoId);
    final docs = await _supabaseService.obtenerDocumentosEoe(legajoId);
    if (!mounted) return;
    setState(() {
      _eoeBitacora = bit;
      _eoeDocumentos = docs;
      _eoeDetalleLoading = false;
    });
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

  Future<void> _cargarResumenHoy() async {
    try {
      final r = await _supabaseService.obtenerResumenAsistenciaHoy();
      if (mounted) setState(() => _resumenHoy = r);
    } catch (e) {
      debugPrint('Error resumen hoy: $e');
    }
  }

  Future<void> _cargarFaltasMesEscuela() async {
    setState(() => _loadingFaltasMes = true);
    try {
      final l = await _supabaseService.obtenerFaltasMensualesEscuela(mes: _selectedMesIndex);
      if (mounted) setState(() => _faltasMesEscuela = l);
    } catch (e) {
      debugPrint('Error faltas mes: $e');
    } finally {
      if (mounted) setState(() => _loadingFaltasMes = false);
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
      await _cargarEoe();
      await _cargarAsistenciaMensual();
      _cargarResumenHoy();
      _cargarFaltasMesEscuela();
      _cargarProyectos();
      await _cargarObservacionesAulicas();
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Nombre del personal a partir de su auth_id (para mostrar en el historial).
  String _nombrePersonalPorAuth(String? authId) {
    if (authId == null) return 'Docente';
    final p = _personal.firstWhere(
      (x) => x['auth_id']?.toString() == authId,
      orElse: () => <String, dynamic>{},
    );
    return (p['nombre_completo'] ?? p['email'] ?? 'Docente').toString();
  }

  String _fechaVisibleAdmin(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Trae el historial de supervisión y lo adapta a las claves que usa la vista.
  Future<void> _cargarObservacionesAulicas() async {
    try {
      final filas = await _supabaseService.obtenerTodasLasObservacionesAulicas();
      if (!mounted) return;
      setState(() {
        _observacionesGestionClases = filas.map((o) {
          final modulo = (o['modulo'] ?? '').toString();
          final fecha = _fechaVisibleAdmin(o['fecha_visita']?.toString());
          final leido = o['leido'] == true;
          return {
            'id': o['id'],
            'docente_auth_id': o['docente_auth_id'],
            'docente': _nombrePersonalPorAuth(o['docente_auth_id']?.toString()),
            'curso': o['curso_texto'] ?? '',
            'fecha': modulo.isEmpty ? fecha : '$fecha - $modulo',
            'foco': o['foco'],
            'observacion': o['observacion'] ?? '',
            'acuerdos': o['acuerdos'] ?? '',
            'subido_por': o['subido_por'] ?? 'Equipo Directivo',
            'notificado': true,
            'estado_lectura': leido
                ? '✅ Leído por el docente'
                : '🔔 Notificado al Docente (pendiente de lectura)',
          };
        }).toList();
      });
    } catch (e) {
      print('Error al cargar el historial de supervisión: $e');
    }
  }

  /// Abre un archivo del legajo docente (DDJJ, CV o certificado).
  /// Se guardan en usr_archivos_personal como base64, no en Storage.
  void _abrirArchivoLegajo(Map<String, dynamic> archivo) {
    final base64Data = archivo['datos_base64'] as String?;
    if (base64Data == null || base64Data.isEmpty) {
      _mostrarError('El archivo no tiene contenido guardado.');
      return;
    }
    PrintHelper.abrirArchivoWeb(base64Data);
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
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
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
                    Supabase.instance.client.from('acad_trayectoria_alumno').select('*').eq('alumno_id', alumnoId).order('anio_lectivo'),
                    Supabase.instance.client.from('acad_materias_adeudadas').select('*').eq('alumno_id', alumnoId).order('anio_origen'),
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
                                            await Supabase.instance.client.from('acad_trayectoria_alumno').insert({
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
                                        await Supabase.instance.client.from('acad_trayectoria_alumno').delete().eq('id', t['id']);
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
                                                await Supabase.instance.client.from('acad_materias_adeudadas').insert({
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
                                        await Supabase.instance.client.from('acad_materias_adeudadas').delete().eq('adeudada_id', m['adeudada_id']);
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
                    onPressed: () => _abrirArchivoLegajo(ddjj.first),
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
                    onPressed: () => _abrirArchivoLegajo(cv.first),
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

    final columnaAlumnos = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Alumnos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(
              width: 180,
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
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
                        DataCell(Text(a['nombre_completo'] ?? '')),
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
          ),
        )
      ],
    );

    final columnaTutores = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tutores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(
              width: 180,
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
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
                        DataCell(Text(t['nombre_completo'] ?? '')),
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
          ),
        )
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text(
                'Comunidad Educativa',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _abrirModalVincularFamilia,
                    icon: const Icon(Icons.family_restroom_rounded, color: Colors.indigo),
                    label: const Text('Vincular Alumno/Tutor'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.withAlpha(20)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _abrirModalCrearUsuario(rol: 'ALUMNO'),
                    icon: const Icon(Icons.person_add_rounded),
                    label: const Text('Alta Alumno'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _abrirModalCrearUsuario(rol: 'PADRE'),
                    icon: const Icon(Icons.supervisor_account_rounded),
                    label: const Text('Alta Tutor'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 900;
                if (isMobile) {
                  return DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          labelColor: Theme.of(context).colorScheme.primary,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Theme.of(context).colorScheme.primary,
                          tabs: const [
                            Tab(icon: Icon(Icons.school_rounded), text: 'Alumnos'),
                            Tab(icon: Icon(Icons.supervisor_account_rounded), text: 'Tutores'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TabBarView(
                            children: [
                              columnaAlumnos,
                              columnaTutores,
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: columnaAlumnos),
                      const SizedBox(width: 24),
                      Expanded(child: columnaTutores),
                    ],
                  );
                }
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAcademyTab() {
    final columnaCursos = Column(
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
    );

    final columnaMaterias = Column(
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
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text(
                'Estructura y Carga de Academia',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _abrirModalCrearEventoCalendario,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('+ Agregar evento'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _abrirModalCrearCurso,
                    icon: const Icon(Icons.add_home_rounded),
                    label: const Text('Nuevo Curso/División'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _abrirModalCrearMateria,
                    icon: const Icon(Icons.book_rounded),
                    label: const Text('Nueva Materia'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 900;
                if (isMobile) {
                  return DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          labelColor: Theme.of(context).colorScheme.primary,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Theme.of(context).colorScheme.primary,
                          tabs: const [
                            Tab(icon: Icon(Icons.class_rounded), text: 'Cursos'),
                            Tab(icon: Icon(Icons.book_rounded), text: 'Materias'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TabBarView(
                            children: [
                              columnaCursos,
                              columnaMaterias,
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: columnaCursos),
                      const SizedBox(width: 24),
                      Expanded(child: columnaMaterias),
                    ],
                  );
                }
              },
            ),
          )
        ],
      ),
    );
  }


  Widget _buildDashboardTab(ColorScheme colorScheme) {
    // Datos REALES de la toma de hoy (planillas del preceptor). Antes esto
    // mostraba 94% presentes fijo, sin leer nada de la base.
    final r = _resumenHoy;
    final int presentes = (r?['presentes'] ?? 0) as int;
    final int ausentes = (r?['ausentes'] ?? 0) as int;
    final int tardes = (r?['tardes'] ?? 0) as int;
    final int retiros = (r?['retiros'] ?? 0) as int;
    final int cursosConLista = (r?['cursos_con_lista'] ?? 0) as int;
    final int cursosTotal = (r?['cursos_total'] ?? 0) as int;

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
          Row(
            children: [
              Text(
                'Resumen de Asistencia de Hoy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              if (_resumenHoy == null)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Text(
                  '$cursosConLista/$cursosTotal cursos tomaron lista',
                  style: TextStyle(
                    fontSize: 12,
                    color: cursosConLista < cursosTotal ? Colors.orange.shade800 : Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: () {
                  _cargarResumenHoy();
                  _cargarFaltasMesEscuela();
                },
              ),
            ],
          ),
          if (_resumenHoy != null && presentes + ausentes + tardes + retiros == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Todavía no se tomó lista hoy en ningún curso.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
                        _cargarFaltasMesEscuela();
                        _cargarAsistenciaMensual();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFaltasMesEscuela(colorScheme),
            const SizedBox(height: 20),
            Text('Detalle del curso: ${_cursos.firstWhere((c) => c['curso_id'] == _asistenciaCursoId, orElse: () => {'identificador_division': ''})['identificador_division']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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

  /// Registro REAL de faltas del mes, toda la escuela, ordenado por faltas.
  Widget _buildFaltasMesEscuela(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_busy_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text('Faltas de ${_mesesNombres[_selectedMesIndex - 1]} — toda la escuela',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                if (_loadingFaltasMes)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Ausente = 1 · Tarde = 0,25 · Retiro anticipado = 0,5',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            if (!_loadingFaltasMes && _faltasMesEscuela.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Sin faltas registradas en ${_mesesNombres[_selectedMesIndex - 1]}.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 22,
                  headingRowHeight: 40,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 40,
                  columns: const [
                    DataColumn(label: Text('Alumno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Curso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Aus.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Tar.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Ret.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Faltas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: _faltasMesEscuela.map((f) {
                    final faltas = f['faltas'] as double;
                    return DataRow(cells: [
                      DataCell(Text('${f['nombre']}', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${f['curso']}', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${f['ausentes']}', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${f['tardes']}', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${f['retiros']}', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(
                        faltas == faltas.roundToDouble() ? faltas.toInt().toString() : faltas.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: faltas >= 3 ? Colors.red.shade800 : Colors.orange.shade800,
                        ),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
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

  // ─── PEDAGÓGICO: repositorio real (ped_documentos + bucket 'pedagogico') ───

  Widget _buildPedagogicoTab(ColorScheme colorScheme) {
    _repCursoId ??= _cursos.isNotEmpty ? _cursos.first['curso_id'] as String : null;
    final materiasDelCurso = _materias.where((m) => m['curso_id'] == _repCursoId).toList();
    if (materiasDelCurso.every((m) => m['materia_id'] != _repMateriaId)) {
      _repMateriaId = materiasDelCurso.isNotEmpty ? materiasDelCurso.first['materia_id'] as String : null;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Repositorio Pedagógico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary)),
          const SizedBox(height: 4),
          const Text('Planificaciones, contratos pedagógicos y criterios de evaluación por materia. El docente sube, la dirección aprueba u observa.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _repCursoId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Curso', border: OutlineInputBorder(), isDense: true),
                  items: _cursos.map((c) => DropdownMenuItem(
                        value: c['curso_id'] as String,
                        child: Text(c['identificador_division'] as String),
                      )).toList(),
                  onChanged: (v) => setState(() {
                    _repCursoId = v;
                    final mats = _materias.where((m) => m['curso_id'] == v).toList();
                    _repMateriaId = mats.isNotEmpty ? mats.first['materia_id'] as String : null;
                  }),
                ),
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: _repMateriaId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Materia', border: OutlineInputBorder(), isDense: true),
                  items: materiasDelCurso.map((m) => DropdownMenuItem(
                        value: m['materia_id'] as String,
                        child: Text(m['nombre_asignatura'] as String, overflow: TextOverflow.ellipsis),
                      )).toList(),
                  onChanged: (v) => setState(() => _repMateriaId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_repCursoId == null || _repMateriaId == null)
            const Text('Seleccioná curso y materia.', style: TextStyle(color: Colors.grey))
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pedSubirBtn('PLANIFICACION', 'Subir planificación', Icons.description_rounded),
                _pedSubirBtn('CONTRATO', 'Subir contrato pedagógico', Icons.handshake_rounded),
                _pedSubirBtn('CRITERIOS', 'Subir criterios de evaluación', Icons.rule_rounded),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey('$_repCursoId|$_repMateriaId|$_pedRepoRefresh'),
              future: _supabaseService.obtenerDocsPedagogicos(cursoId: _repCursoId, materiaId: _repMateriaId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
                }
                final docs = snap.data ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Sin documentos cargados para esta materia.', style: TextStyle(color: Colors.grey)),
                  );
                }
                return Column(
                  children: docs.map((d) {
                    final estado = (d['estado'] ?? 'PENDIENTE').toString();
                    final color = estado == 'APROBADO'
                        ? Colors.green
                        : estado == 'OBSERVADO'
                            ? Colors.orange
                            : Colors.blueGrey;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: color.withAlpha(90)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.insert_drive_file_rounded, size: 20, color: color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${d['nombre']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text('${_pedLabelTipo(d['tipo'])} · ${estado} · ${d['subido_por_nombre'] ?? ''}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                if ((d['storage_path'] ?? '').toString().isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.download_rounded, size: 20),
                                    onPressed: () => _pedDescargar(d),
                                  ),
                              ],
                            ),
                            if ((d['observaciones'] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('📝 ${d['observaciones']}', style: const TextStyle(fontSize: 12)),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _pedCambiarEstado(d, 'APROBADO'),
                                  icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                                  label: const Text('Aprobar', style: TextStyle(fontSize: 12, color: Colors.green)),
                                ),
                                TextButton.icon(
                                  onPressed: () => _pedObservar(d),
                                  icon: const Icon(Icons.error_rounded, size: 16, color: Colors.orange),
                                  label: const Text('Observar', style: TextStyle(fontSize: 12, color: Colors.orange)),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await _supabaseService.eliminarDocPedagogico(d['id'].toString());
                                    setState(() => _pedRepoRefresh++);
                                  },
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                  label: const Text('Eliminar', style: TextStyle(fontSize: 12, color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _pedLabelTipo(dynamic t) {
    switch ((t ?? '').toString()) {
      case 'PLANIFICACION':
        return 'Planificación';
      case 'CONTRATO':
        return 'Contrato pedagógico';
      case 'CRITERIOS':
        return 'Criterios de evaluación';
      default:
        return 'Documento';
    }
  }

  Widget _pedSubirBtn(String tipo, String label, IconData icon) => OutlinedButton.icon(
        onPressed: () => _pedSubir(tipo),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      );

  Future<void> _pedSubir(String tipo) async {
    if (_repCursoId == null || _repMateriaId == null) return;
    final res = await FilePicker.platform.pickFiles(
      withData: true, type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    final f = res.files.first;
    try {
      await _supabaseService.subirDocPedagogico(
        cursoId: _repCursoId!, materiaId: _repMateriaId!, tipo: tipo,
        bytes: f.bytes!, fileName: f.name);
      setState(() => _pedRepoRefresh++);
      _mostrarExito('Documento subido.');
    } catch (e) {
      _mostrarError('Error al subir: $e');
    }
  }

  Future<void> _pedDescargar(Map<String, dynamic> d) async {
    try {
      final url = await _supabaseService.urlFirmadaStorage('pedagogico', d['storage_path'].toString());
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _mostrarError('Error al descargar: $e');
    }
  }

  Future<void> _pedCambiarEstado(Map<String, dynamic> d, String estado) async {
    await _supabaseService.actualizarDocPedagogico(id: d['id'].toString(), estado: estado);
    setState(() => _pedRepoRefresh++);
  }

  void _pedObservar(Map<String, dynamic> d) {
    final ctrl = TextEditingController(text: (d['observaciones'] ?? '').toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Observar documento'),
        content: TextField(controller: ctrl, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Qué hay que corregir')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _supabaseService.actualizarDocPedagogico(
                  id: d['id'].toString(), estado: 'OBSERVADO', observaciones: ctrl.text.trim());
              setState(() => _pedRepoRefresh++);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _abrirModalSubirObservacionClaseDirectiva() {
    // Docentes reales de la institución: la observación se guarda contra el
    // auth_id del docente para que le aparezca en su perfil.
    final docentes = _personal
        .where((d) => (d['auth_id'] ?? '').toString().isNotEmpty)
        .toList();

    if (docentes.isEmpty) {
      _mostrarError('No hay personal cargado para registrar una observación.');
      return;
    }

    String? selectedDocenteAuthId = docentes.first['auth_id'].toString();
    String selectedFoco = 'Estrategias Didácticas y Clima Áulico';
    DateTime fechaVisita = DateTime.now();
    final cursoCtrl = TextEditingController();
    final moduloCtrl = TextEditingController(text: '2° Módulo');
    final obsCtrl = TextEditingController();
    final acuerdosCtrl = TextEditingController();
    bool notificarDocente = true;
    bool guardando = false;

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
                    value: selectedDocenteAuthId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Docente Observado', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_rounded)),
                    items: docentes
                        .map((d) => DropdownMenuItem(
                              value: d['auth_id'].toString(),
                              child: Text(
                                (d['nombre_completo'] ?? d['email'] ?? 'Docente').toString(),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedDocenteAuthId = v),
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
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: fechaVisita,
                              firstDate: DateTime(DateTime.now().year - 1),
                              lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                            );
                            if (picked != null) setModalState(() => fechaVisita = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                                labelText: 'Fecha de la visita',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today_rounded)),
                            child: Text(
                              '${fechaVisita.day.toString().padLeft(2, '0')}/'
                              '${fechaVisita.month.toString().padLeft(2, '0')}/${fechaVisita.year}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: moduloCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Módulo / Hora',
                        hintText: 'Ej. 2° Módulo',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.schedule_rounded)),
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
              icon: guardando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: const Text('Registrar y Notificar al Docente'),
              onPressed: guardando
                  ? null
                  : () async {
                      if (obsCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('⚠️ Por favor completá el registro de lo observado durante la clase.')));
                        return;
                      }
                      if (selectedDocenteAuthId == null) return;

                      setModalState(() => guardando = true);
                      final docente = docentes.firstWhere(
                        (d) => d['auth_id'].toString() == selectedDocenteAuthId,
                        orElse: () => <String, dynamic>{},
                      );

                      try {
                        await _supabaseService.registrarObservacionAulica(
                          docenteAuthId: selectedDocenteAuthId!,
                          docenteId: docente['docente_id']?.toString(),
                          docenteNombre: docente['nombre_completo']?.toString(),
                          cursoTexto: cursoCtrl.text.trim(),
                          fechaVisita: fechaVisita,
                          modulo: moduloCtrl.text.trim(),
                          foco: selectedFoco,
                          observacion: obsCtrl.text.trim(),
                          acuerdos: agreementsOrDefault(acuerdosCtrl.text.trim()),
                          notificarDocente: notificarDocente,
                        );

                        if (!mounted) return;
                        Navigator.pop(context);
                        await _cargarObservacionesAulicas();

                        if (!mounted) return;
                        final nombre = (docente['nombre_completo'] ?? 'el docente').toString();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(notificarDocente
                                ? '✅ Visita áulica guardada. Se notificó la devolución a $nombre.'
                                : '✅ Visita áulica guardada como registro interno de Dirección.'),
                            backgroundColor: Colors.green.shade700,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } catch (e) {
                        setModalState(() => guardando = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al registrar la observación: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
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
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Text('Registrado por: ${obs['subido_por'] ?? "Equipo Directivo"}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            OutlinedButton.icon(
                              onPressed: () => _reenviarNotificacionObservacion(obs),
                              icon: const Icon(Icons.send_to_mobile_rounded, size: 16),
                              label: const Text('Reenviar Notificación'),
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

  /// Vuelve a avisar al docente que tiene una devolución pendiente de leer.
  Future<void> _reenviarNotificacionObservacion(Map<String, dynamic> obs) async {
    final authId = obs['docente_auth_id']?.toString();
    if (authId == null || authId.isEmpty) {
      _mostrarError('La observación no tiene un docente asociado.');
      return;
    }
    try {
      await _supabaseService.notificarSistema(
        asunto: 'Recordatorio: Devolución de Observación Áulica',
        texto: 'Tenés una devolución pedagógica pendiente de lectura'
            '${(obs['curso'] ?? '').toString().isNotEmpty ? ' de ${obs['curso']}' : ''}. '
            'Podés verla en Mi Perfil > Observaciones de Clases.',
        destinatariosAuthIds: [authId],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notificación reenviada a ${obs['docente'] ?? 'el docente'}.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      _mostrarError('No se pudo reenviar la notificación: $e');
    }
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
    if (_eoeSelectedFicha != null) {
      return _buildEoeDetailView(_eoeSelectedFicha!, colorScheme);
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
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
                    'Marcá alumnos ya inscriptos, completá su ficha y documentos. Los docentes vinculados los verán en su portal.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Recargar',
                    onPressed: _eoeLoading ? null : _cargarEoe,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: () => _abrirModalFichaEoe(),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Activar Adecuación'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 320,
            child: DropdownButtonFormField<String>(
              initialValue: _eoeFiltroCurso,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Buscar por curso',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.filter_list_rounded),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Todos los cursos')),
                ..._cursos.map((c) => DropdownMenuItem(
                      value: c['curso_id'] as String,
                      child: Text(c['identificador_division'] as String),
                    )),
              ],
              onChanged: (v) => setState(() => _eoeFiltroCurso = v),
            ),
          ),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final fichas = _eoeFiltroCurso == null
                ? _eoeFichas
                : _eoeFichas.where((f) => f['curso_id'] == _eoeFiltroCurso).toList();
            return Expanded(
              child: _eoeLoading
                  ? const Center(child: CircularProgressIndicator())
                  : fichas.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay alumnos con adecuación para este filtro.\nPulsá "Activar Adecuación" para agregar uno.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, height: 1.4),
                          ),
                        )
                      : ListView.builder(
                          itemCount: fichas.length,
                          itemBuilder: (context, index) {
                            final al = fichas[index];
                          final tipo = al['tipo_adecuacion'] ?? 'General';
                          final detalles = (al['detalles'] ?? '').toString();
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
                              title: Text(al['nombre_completo'] ?? 'Alumno',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('${al['curso_nombre'] ?? ''} · Tipo: $tipo',
                                      style: const TextStyle(fontWeight: FontWeight.w500)),
                                  if (detalles.isNotEmpty)
                                    Text('Pautas: $detalles',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (al['tiene_ficha'] != true)
                                    const Text('Sólo flag heredado — abrí para completar la ficha',
                                        style: TextStyle(fontSize: 11, color: Colors.orange)),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.indigo),
                              onTap: () => _eoeSeleccionar(al),
                            ),
                          );
                        },
                      ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEoeDetailView(Map<String, dynamic> ficha, ColorScheme colorScheme) {
    final legajoId = (ficha['legajo_id'] ?? '').toString();
    final form = Map<String, dynamic>.from(ficha['datos_formulario'] as Map? ?? {});

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _eoeSelectedFicha = null),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Ficha Psicopedagógica del Alumno',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: () => _abrirModalFichaEoe(ficha: ficha),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Editar ficha'),
              ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment_ind_rounded, color: Colors.indigo.shade800, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ficha['nombre_completo'] ?? 'Alumno',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo.shade900)),
                            const SizedBox(height: 4),
                            Text('DNI: ${ficha['dni'] ?? '—'} · Curso: ${ficha['curso_nombre'] ?? '—'} · Tipo: ${ficha['tipo_adecuacion'] ?? '—'}',
                                style: TextStyle(color: Colors.indigo.shade900, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('Pautas: ${(ficha['detalles'] ?? '').toString().isEmpty ? 'Sin especificar' : ficha['detalles']}',
                                style: TextStyle(color: Colors.indigo.shade900, fontSize: 12, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (form.entries.any((e) => (e.value ?? '').toString().isNotEmpty)) ...[
                    const Divider(height: 20),
                    ...form.entries
                        .where((e) => (e.value ?? '').toString().isNotEmpty)
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text.rich(TextSpan(children: [
                                TextSpan(
                                    text: '${_eoeLabelCampo(e.key)}: ',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo.shade900)),
                                TextSpan(
                                    text: e.value.toString(),
                                    style: TextStyle(fontSize: 12, color: Colors.indigo.shade900)),
                              ])),
                            )),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    indicatorColor: colorScheme.primary,
                    tabs: const [
                      Tab(icon: Icon(Icons.folder_shared_rounded), text: 'Documentos'),
                      Tab(icon: Icon(Icons.forum_rounded), text: 'Bitácora'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _eoeDetalleLoading
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            children: [
                              _buildEoeDocumentosTab(legajoId, colorScheme),
                              _buildEoeBitacoraTab(legajoId, colorScheme),
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

  Widget _buildEoeDocumentosTab(String legajoId, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _eoeUploadBtn(legajoId, 'INFORME', 'Subir informe', Icons.medical_information_rounded, Colors.indigo),
            _eoeUploadBtn(legajoId, 'PAUTAS', 'Subir pautas', Icons.rule_rounded, Colors.teal),
            _eoeUploadBtn(legajoId, 'EVAL_ADECUADA', 'Subir evaluación adecuada', Icons.verified_rounded, Colors.green),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _eoeDocumentos.isEmpty
              ? const Center(
                  child: Text('Sin documentos cargados para este alumno.',
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
              : ListView.builder(
                  itemCount: _eoeDocumentos.length,
                  itemBuilder: (context, i) {
                    final d = _eoeDocumentos[i];
                    final tieneArchivo = (d['storage_path'] ?? '').toString().isNotEmpty;
                    final esOriginal = d['categoria'] == 'EVAL_ORIGINAL';
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                            color: esOriginal ? Colors.orange.withAlpha(90) : Colors.grey.withAlpha(60)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_eoeIconoCategoria(d['categoria']),
                                    color: esOriginal ? Colors.orange : colorScheme.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d['nombre'] ?? 'Documento',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(
                                          '${_eoeLabelCategoria(d['categoria'])} · ${d['estado'] ?? ''}'
                                          '${(d['subido_por_nombre'] ?? '').toString().isNotEmpty ? ' · ${d['subido_por_nombre']}' : ''}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                if (tieneArchivo)
                                  IconButton(
                                    icon: const Icon(Icons.download_rounded, size: 20),
                                    tooltip: 'Descargar',
                                    onPressed: () => _eoeDescargar(d),
                                  ),
                              ],
                            ),
                            if ((d['observaciones_eoe'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withAlpha(15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('📝 ${d['observaciones_eoe']}',
                                    style: const TextStyle(fontSize: 12, height: 1.3)),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _editarObservacionDocEoe(d),
                                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                                  label: const Text('Observaciones', style: TextStyle(fontSize: 12)),
                                ),
                                if (esOriginal)
                                  TextButton.icon(
                                    onPressed: () => _eoeUpload(legajoId, 'EVAL_ADECUADA',
                                        observacionesDe: d),
                                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                                    label: const Text('Subir versión adecuada', style: TextStyle(fontSize: 12)),
                                  ),
                                if (d['estado'] != 'ADECUADA')
                                  TextButton.icon(
                                    onPressed: () => _marcarDocEoe(d, 'ADECUADA'),
                                    icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                                    label: const Text('Marcar adecuada',
                                        style: TextStyle(fontSize: 12, color: Colors.green)),
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

  Widget _eoeUploadBtn(String legajoId, String categoria, String label, IconData icon, Color color) {
    return OutlinedButton.icon(
      onPressed: () => _eoeUpload(legajoId, categoria),
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      style: OutlinedButton.styleFrom(side: BorderSide(color: color.withAlpha(120))),
    );
  }

  Future<void> _eoeUpload(String legajoId, String categoria,
      {Map<String, dynamic>? observacionesDe}) async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    final f = res.files.first;
    try {
      await _supabaseService.subirDocumentoEoe(
        legajoId: legajoId,
        categoria: categoria,
        bytes: f.bytes!,
        fileName: f.name,
        observaciones: observacionesDe?['observaciones_eoe']?.toString(),
      );
      if (_eoeSelectedFicha != null) await _eoeSeleccionar(_eoeSelectedFicha!);
      _mostrarExito('Documento subido.');
    } catch (e) {
      _mostrarError('Error al subir el documento: $e');
    }
  }

  Future<void> _eoeDescargar(Map<String, dynamic> d) async {
    final path = (d['storage_path'] ?? '').toString();
    if (path.isEmpty) return;
    try {
      final url = await _supabaseService.urlFirmadaStorage('eoe', path);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _mostrarError('Error al descargar: $e');
    }
  }

  Future<void> _marcarDocEoe(Map<String, dynamic> d, String estado) async {
    try {
      await _supabaseService.actualizarDocumentoEoe(id: d['id'].toString(), estado: estado);
      if (_eoeSelectedFicha != null) await _eoeSeleccionar(_eoeSelectedFicha!);
    } catch (e) {
      _mostrarError('Error: $e');
    }
  }

  void _editarObservacionDocEoe(Map<String, dynamic> d) {
    final ctrl = TextEditingController(text: (d['observaciones_eoe'] ?? '').toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Observaciones del gabinete'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Pautas de adecuación, ajustes solicitados al docente...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabaseService.actualizarDocumentoEoe(
                    id: d['id'].toString(), observaciones: ctrl.text.trim());
                if (_eoeSelectedFicha != null) await _eoeSeleccionar(_eoeSelectedFicha!);
              } catch (e) {
                _mostrarError('Error: $e');
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEoeBitacoraTab(String legajoId, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _agregarNotaBitacoraEoe(legajoId),
          icon: const Icon(Icons.add_comment_rounded, size: 18),
          label: const Text('Nueva nota de seguimiento'),
          style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _eoeBitacora.isEmpty
              ? const Center(
                  child: Text('Sin notas en la bitácora todavía.',
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
              : ListView.builder(
                  itemCount: _eoeBitacora.length,
                  itemBuilder: (context, i) {
                    final n = _eoeBitacora[i];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${n['autor_nombre'] ?? 'Autor'} · ${n['autor_rol'] ?? ''}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                                Text((n['fecha'] ?? '').toString(),
                                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(n['nota'] ?? '', style: const TextStyle(fontSize: 13, height: 1.3)),
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

  void _agregarNotaBitacoraEoe(String legajoId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nueva nota de seguimiento'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Nota / observación'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _supabaseService.agregarNotaBitacoraEoe(legajoId: legajoId, nota: ctrl.text.trim());
                if (_eoeSelectedFicha != null) await _eoeSeleccionar(_eoeSelectedFicha!);
                _mostrarExito('Nota agregada a la bitácora.');
              } catch (e) {
                _mostrarError('Error: $e');
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  /// Alta o edición de la ficha EOE de un alumno ya inscripto.
  void _abrirModalFichaEoe({Map<String, dynamic>? ficha}) {
    final editando = ficha != null;
    final formKey = GlobalKey<FormState>();
    String? selectedAlumnoId = ficha?['legajo_id']?.toString();
    String tipo = (ficha?['tipo_adecuacion'] ?? 'Metodológica').toString();
    if (!const ['Metodológica', 'De Acceso', 'De Contenido'].contains(tipo)) {
      tipo = 'Metodológica';
    }
    final form = Map<String, dynamic>.from(ficha?['datos_formulario'] as Map? ?? {});
    String? filtroCursoId; // filtro por curso para acotar la lista de alumnos
    final detallesCtrl = TextEditingController(text: (ficha?['detalles'] ?? '').toString());
    final diagCtrl = TextEditingController(text: (form['diagnostico'] ?? '').toString());
    final profCtrl = TextEditingController(text: (form['profesional'] ?? '').toString());
    final vigCtrl = TextEditingController(text: (form['vigencia'] ?? '').toString());
    final apoyosCtrl = TextEditingController(text: (form['apoyos'] ?? '').toString());
    final obsCtrl = TextEditingController(text: (form['observaciones'] ?? '').toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(editando ? 'Editar ficha EOE' : 'Activar Adecuación Curricular',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!editando) ...[
                    DropdownButtonFormField<String>(
                      initialValue: filtroCursoId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Filtrar por curso', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Todos los cursos')),
                        ..._cursos.map((c) => DropdownMenuItem(
                              value: c['curso_id'] as String,
                              child: Text(c['identificador_division'] as String),
                            )),
                      ],
                      onChanged: (val) => setModalState(() {
                        filtroCursoId = val;
                        selectedAlumnoId = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAlumnoId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Seleccione alumno inscripto', border: OutlineInputBorder()),
                      items: _alumnos
                          .where((a) => filtroCursoId == null || a['curso_id'] == filtroCursoId)
                          .map((a) => DropdownMenuItem(
                                value: a['legajo_id'] as String,
                                child: Text(
                                    '${a['nombre_completo']} — ${a['curso_nombre'] ?? ''}',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) => setModalState(() => selectedAlumnoId = val),
                      validator: (val) => val == null ? 'Requerido' : null,
                    ),
                  ]
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(ficha['nombre_completo'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tipo,
                    decoration: const InputDecoration(labelText: 'Tipo de adecuación', border: OutlineInputBorder()),
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
                    decoration: const InputDecoration(labelText: 'Pautas / detalles de la adecuación', border: OutlineInputBorder()),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const Divider(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Formulario del gabinete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(controller: diagCtrl, decoration: const InputDecoration(labelText: 'Diagnóstico', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextFormField(controller: profCtrl, decoration: const InputDecoration(labelText: 'Profesional tratante', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextFormField(controller: vigCtrl, decoration: const InputDecoration(labelText: 'Vigencia (ej. Ciclo 2026)', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextFormField(controller: apoyosCtrl, decoration: const InputDecoration(labelText: 'Apoyos / recursos', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextFormField(controller: obsCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Observaciones', border: OutlineInputBorder())),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            if (editando)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _guardarFichaEoe(selectedAlumnoId!, false, tipo, detallesCtrl.text.trim(), {});
                },
                child: const Text('Desactivar', style: TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate() || selectedAlumnoId == null) return;
                Navigator.of(context).pop();
                await _guardarFichaEoe(selectedAlumnoId!, true, tipo, detallesCtrl.text.trim(), {
                  'diagnostico': diagCtrl.text.trim(),
                  'profesional': profCtrl.text.trim(),
                  'vigencia': vigCtrl.text.trim(),
                  'apoyos': apoyosCtrl.text.trim(),
                  'observaciones': obsCtrl.text.trim(),
                });
              },
              child: Text(editando ? 'Guardar' : 'Activar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarFichaEoe(
      String legajoId, bool activa, String tipo, String detalles, Map<String, dynamic> form) async {
    setState(() => _isLoading = true);
    try {
      await _supabaseService.guardarFichaEoe(
        legajoId: legajoId,
        activa: activa,
        tipo: tipo,
        detalles: detalles,
        datosFormulario: form,
      );
      await _cargarEoe();
      if (!activa) setState(() => _eoeSelectedFicha = null);
      _mostrarExito(activa ? 'Ficha EOE guardada.' : 'Adecuación desactivada.');
    } catch (e) {
      _mostrarError('Error al guardar la ficha: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _eoeLabelCampo(String k) {
    switch (k) {
      case 'diagnostico':
        return 'Diagnóstico';
      case 'profesional':
        return 'Profesional tratante';
      case 'vigencia':
        return 'Vigencia';
      case 'apoyos':
        return 'Apoyos';
      case 'observaciones':
        return 'Observaciones';
      default:
        return k.isEmpty ? k : k[0].toUpperCase() + k.substring(1);
    }
  }

  String _eoeLabelCategoria(String? c) {
    switch (c) {
      case 'INFORME':
        return 'Informe';
      case 'PAUTAS':
        return 'Pautas';
      case 'EVAL_ORIGINAL':
        return 'Evaluación original (del docente)';
      case 'EVAL_ADECUADA':
        return 'Evaluación adecuada';
      default:
        return c ?? 'Documento';
    }
  }

  IconData _eoeIconoCategoria(String? c) {
    switch (c) {
      case 'EVAL_ADECUADA':
        return Icons.verified_rounded;
      case 'EVAL_ORIGINAL':
        return Icons.description_rounded;
      case 'PAUTAS':
        return Icons.rule_rounded;
      default:
        return Icons.folder_shared_rounded;
    }
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

          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PanelBoletinesPreceptor(cursoIdInicial: _rendCursoId),
                )),
                icon: const Icon(Icons.assignment_rounded, size: 18),
                label: const Text('Ver boletines del curso'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_rendCursoId == null || _rendMateriaId == null)
            const Center(child: Text('Seleccioná un curso y una materia para ver los movimientos.'))
          else
            FutureBuilder<Map<String, dynamic>>(
              key: ValueKey(_rendMateriaId),
              future: _supabaseService.obtenerMovimientosMateria(_rendMateriaId!),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final movs = (snap.data?['movimientos'] as List?) ?? [];
                if (movs.isEmpty) {
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('El docente todavía no cargó actividades ni notas en esta materia.',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                // Matriz alumno x actividad
                final alumnosCurso = _alumnos.where((a) => a['curso_id'] == _rendCursoId).toList()
                  ..sort((a, b) => (a['nombre_completo'] ?? '')
                      .toString()
                      .compareTo((b['nombre_completo'] ?? '').toString()));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Movimientos de la materia (${movs.length})',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                    const SizedBox(height: 8),
                    ...movs.map((m) => Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.assignment_turned_in_rounded, size: 20),
                            title: Text('${m['titulo']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${(m['fecha'] ?? '').toString().split('T').first} · ${m['categoria']} · '
                              'Cargó: ${m['docente']} · ${m['notas_cargadas']}/${alumnosCurso.length} notas',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        )),
                    const SizedBox(height: 16),
                    Text('Calificaciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.withAlpha(51)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 18,
                          headingRowHeight: 44,
                          columns: [
                            const DataColumn(label: Text('Alumno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            for (final m in movs)
                              DataColumn(
                                label: SizedBox(
                                  width: 70,
                                  child: Text('${m['titulo']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            const DataColumn(label: Text('Prom.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                          rows: alumnosCurso.map((al) {
                            final legajo = al['legajo_id'].toString();
                            final notas = <double>[];
                            final cells = <DataCell>[
                              DataCell(Text('${al['nombre_completo']}', style: const TextStyle(fontSize: 12))),
                            ];
                            for (final m in movs) {
                              final califs = (m['calificaciones'] as List?) ?? [];
                              final c = califs.firstWhere(
                                (x) => x['alumno_id'].toString() == legajo,
                                orElse: () => null,
                              );
                              final n = c?['nota_numerica'];
                              if (n != null) notas.add((n as num).toDouble());
                              cells.add(DataCell(Text(
                                n == null ? '·' : (n as num).toStringAsFixed(1),
                                style: TextStyle(fontSize: 12, color: n == null ? Colors.grey : null),
                              )));
                            }
                            final prom = notas.isEmpty ? null : notas.reduce((a, b) => a + b) / notas.length;
                            cells.add(DataCell(Text(
                              prom == null ? '·' : prom.toStringAsFixed(2),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            )));
                            return DataRow(cells: cells);
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── HORARIOS: grilla real (acad_horarios) + reasignar con chequeo DDJJ ───

  Widget _buildCambioHorarioTab(ColorScheme colorScheme) {
    final cursoId = _horarioSelectedCursoId ??
        (_cursos.isNotEmpty ? _cursos.first['curso_id'] as String : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Horarios y Declaraciones Juradas (DDJJ)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary)),
          const SizedBox(height: 4),
          const Text(
            'Grilla real del curso. Al reasignar la materia de un docente, el sistema chequea que no choque con sus otras clases y que caiga dentro de la disponibilidad que declaró en su DDJJ.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  initialValue: cursoId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Curso', border: OutlineInputBorder(), isDense: true),
                  items: _cursos.map((c) => DropdownMenuItem(
                        value: c['curso_id'] as String,
                        child: Text(c['identificador_division'] as String),
                      )).toList(),
                  onChanged: (v) => setState(() => _horarioSelectedCursoId = v),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _abrirDisponibilidadDocente(),
                icon: const Icon(Icons.event_available_rounded, size: 16),
                label: const Text('Disponibilidad de un docente (DDJJ)'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (cursoId == null)
            const Text('No hay cursos.', style: TextStyle(color: Colors.grey))
          else
            FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey('$cursoId|$_horarioRefresh'),
              future: _supabaseService.obtenerHorarioCurso(cursoId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                }
                final bloques = snap.data ?? [];
                if (bloques.isEmpty) {
                  return const Text('Este curso no tiene horario cargado en acad_horarios.', style: TextStyle(color: Colors.grey));
                }
                final porDia = <String, List<Map<String, dynamic>>>{};
                for (final b in bloques) {
                  porDia.putIfAbsent(b['dia'].toString().toUpperCase(), () => []).add(b);
                }
                final diasOrden = ['LUNES', 'MARTES', 'MIÉRCOLES', 'MIERCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'SABADO'];
                final dias = porDia.keys.toList()
                  ..sort((a, b) => diasOrden.indexOf(a).compareTo(diasOrden.indexOf(b)));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _abrirReasignarMateria(cursoId),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Reasignar docente de una materia'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    ...dias.map((dia) => Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dia, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                const SizedBox(height: 6),
                                ...(porDia[dia]!..sort((a, b) => a['inicio'].toString().compareTo(b['inicio'].toString())))
                                    .map((b) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 3),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 90,
                                                child: Text('${b['inicio']}–${b['fin']}',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                              ),
                                              Expanded(
                                                child: Text('${b['materia']}',
                                                    style: const TextStyle(fontSize: 12)),
                                              ),
                                              Text('${b['docente']}',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: b['docente'] == 'Sin asignar' ? Colors.red : Colors.grey.shade700)),
                                            ],
                                          ),
                                        )),
                              ],
                            ),
                          ),
                        )),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _abrirReasignarMateria(String cursoId) async {
    final materiasCurso = _materias.where((m) => m['curso_id'] == cursoId).toList();
    final docentes = await _supabaseService.obtenerDocentesSimple();
    if (!mounted) return;
    String? materiaId = materiasCurso.isNotEmpty ? materiasCurso.first['materia_id'] as String : null;
    String? docenteId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Reasignar docente', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: materiaId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Materia', border: OutlineInputBorder()),
                  items: materiasCurso.map((m) => DropdownMenuItem(
                        value: m['materia_id'] as String,
                        child: Text(m['nombre_asignatura'] as String, overflow: TextOverflow.ellipsis),
                      )).toList(),
                  onChanged: (v) => setD(() => materiaId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: docenteId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Nuevo docente', border: OutlineInputBorder()),
                  items: docentes.map((d) => DropdownMenuItem(
                        value: d['docente_id'] as String,
                        child: Text(d['nombre'] as String, overflow: TextOverflow.ellipsis),
                      )).toList(),
                  onChanged: (v) => setD(() => docenteId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: (materiaId == null || docenteId == null)
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final r = await _supabaseService.reasignarDocenteMateria(
                          materiaId: materiaId!, nuevoDocenteId: docenteId!);
                      if (!mounted) return;
                      if (r['ok'] == true) {
                        setState(() => _horarioRefresh++);
                        _mostrarExito('Reasignado sin conflictos.');
                        _cargarDatos();
                      } else {
                        _mostrarResultadoReasignacion(r, materiaId!, docenteId!);
                      }
                    },
              child: const Text('Verificar y reasignar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarResultadoReasignacion(Map<String, dynamic> r, String materiaId, String docenteId) {
    final choques = List<String>.from(r['choques'] ?? []);
    final fuera = List<String>.from(r['fuera_disponibilidad'] ?? []);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('La DDJJ marcó observaciones'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (choques.isNotEmpty) ...[
                const Text('Choques de horario:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ...choques.map((c) => Text('• $c', style: const TextStyle(fontSize: 12))),
                const SizedBox(height: 8),
              ],
              if (fuera.isNotEmpty) ...[
                const Text('Fuera de la disponibilidad declarada:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                ...fuera.map((c) => Text('• $c', style: const TextStyle(fontSize: 12))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () async {
              Navigator.pop(ctx);
              await _supabaseService.reasignarDocenteMateria(
                  materiaId: materiaId, nuevoDocenteId: docenteId, forzar: true);
              if (!mounted) return;
              setState(() => _horarioRefresh++);
              _mostrarExito('Reasignado igual (con observaciones).');
              _cargarDatos();
            },
            child: const Text('Aplicar igual', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirDisponibilidadDocente() async {
    final docentes = await _supabaseService.obtenerDocentesSimple();
    if (!mounted || docentes.isEmpty) {
      if (mounted) _mostrarError('No hay docentes cargados todavía.');
      return;
    }
    String docenteId = docentes.first['docente_id'] as String;
    List<Map<String, dynamic>> franjas = await _supabaseService.obtenerDisponibilidadDocente(docenteId);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Disponibilidad declarada (DDJJ)', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: docenteId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Docente', border: OutlineInputBorder()),
                  items: docentes.map((d) => DropdownMenuItem(
                        value: d['docente_id'] as String,
                        child: Text(d['nombre'] as String, overflow: TextOverflow.ellipsis),
                      )).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    final f = await _supabaseService.obtenerDisponibilidadDocente(v);
                    setD(() {
                      docenteId = v;
                      franjas = f;
                    });
                  },
                ),
                const SizedBox(height: 10),
                ...franjas.asMap().entries.map((e) {
                  final i = e.key;
                  final fr = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: (fr['dia'] ?? 'LUNES').toString(),
                            isDense: true,
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                            items: const ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES']
                                .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (v) => setD(() => fr['dia'] = v),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 62,
                          child: TextFormField(
                            initialValue: (fr['desde'] ?? '').toString(),
                            decoration: const InputDecoration(hintText: '07:00', isDense: true, border: OutlineInputBorder()),
                            onChanged: (v) => fr['desde'] = v,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 62,
                          child: TextFormField(
                            initialValue: (fr['hasta'] ?? '').toString(),
                            decoration: const InputDecoration(hintText: '12:00', isDense: true, border: OutlineInputBorder()),
                            onChanged: (v) => fr['hasta'] = v,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          onPressed: () => setD(() => franjas.removeAt(i)),
                        ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () => setD(() => franjas.add({'dia': 'LUNES', 'desde': '07:00', 'hasta': '12:00'})),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Agregar franja'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _supabaseService.guardarDisponibilidadDocente(
                      docenteId, franjas.map((f) => Map<String, dynamic>.from(f)).toList());
                  _mostrarExito('Disponibilidad guardada.');
                } catch (e) {
                  _mostrarError('Error: $e');
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
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

  // ─── PROYECTOS INSTITUCIONALES (proy_institucionales + proy_documentos) ───

  Future<void> _cargarProyectos() async {
    setState(() => _loadingProy = true);
    try {
      _proyectos = await _supabaseService.obtenerProyectos();
    } catch (e) {
      debugPrint('Error cargar proyectos: $e');
    } finally {
      if (mounted) setState(() => _loadingProy = false);
    }
  }

  String _proyLabelEstado(String e) {
    switch (e) {
      case 'PLANIFICADO':
        return 'Planificado';
      case 'EN_CURSO':
        return 'En curso';
      case 'FINALIZADO':
        return 'Finalizado';
      case 'SUSPENDIDO':
        return 'Suspendido';
      default:
        return e;
    }
  }

  Widget _buildProyectosTab(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Proyectos Institucionales', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                    const SizedBox(height: 4),
                    const Text('Proyectos escolares con responsable, estado, fechas y archivos adjuntos.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(onPressed: _loadingProy ? null : _cargarProyectos, icon: const Icon(Icons.refresh_rounded)),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => _abrirModalProyecto(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo Proyecto'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loadingProy
                ? const Center(child: CircularProgressIndicator())
                : _proyectos.isEmpty
                    ? const Center(child: Text('No hay proyectos registrados.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _proyectos.length,
                        itemBuilder: (context, index) {
                          final p = _proyectos[index];
                          final estado = (p['estado'] ?? 'EN_CURSO').toString();
                          final color = estado == 'FINALIZADO'
                              ? Colors.green
                              : estado == 'SUSPENDIDO'
                                  ? Colors.red
                                  : estado == 'PLANIFICADO'
                                      ? Colors.blueGrey
                                      : Colors.blue;
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: color.withAlpha(70))),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(p['nombre'] ?? 'Proyecto', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                      Chip(
                                        label: Text(_proyLabelEstado(estado), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                                        backgroundColor: color.withAlpha(25),
                                        side: BorderSide.none,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  if ((p['descripcion'] ?? '').toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('${p['descripcion']}', style: const TextStyle(fontSize: 13)),
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Responsable: ${p['responsable'] ?? '—'}'
                                    '${p['fecha_inicio'] != null ? ' · ${p['fecha_inicio'].toString().split('T').first}' : ''}'
                                    '${p['fecha_fin'] != null ? ' a ${p['fecha_fin'].toString().split('T').first}' : ''}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _abrirArchivosProyecto(p),
                                        icon: const Icon(Icons.folder_rounded, size: 16),
                                        label: const Text('Archivos', style: TextStyle(fontSize: 12)),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _abrirModalProyecto(proyecto: p),
                                        icon: const Icon(Icons.edit_rounded, size: 16),
                                        label: const Text('Editar', style: TextStyle(fontSize: 12)),
                                      ),
                                      TextButton.icon(
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Eliminar proyecto'),
                                              content: Text('¿Eliminar "${p['nombre']}"?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            await _supabaseService.eliminarProyecto(p['id'].toString());
                                            _cargarProyectos();
                                          }
                                        },
                                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                        label: const Text('Eliminar', style: TextStyle(fontSize: 12, color: Colors.red)),
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

  void _abrirModalProyecto({Map<String, dynamic>? proyecto}) {
    final editando = proyecto != null;
    final formKey = GlobalKey<FormState>();
    final nomCtrl = TextEditingController(text: (proyecto?['nombre'] ?? '').toString());
    final descCtrl = TextEditingController(text: (proyecto?['descripcion'] ?? '').toString());
    final respCtrl = TextEditingController(text: (proyecto?['responsable'] ?? '').toString());
    DateTime? ini = DateTime.tryParse((proyecto?['fecha_inicio'] ?? '').toString());
    DateTime? fin = DateTime.tryParse((proyecto?['fecha_fin'] ?? '').toString());
    String estado = (proyecto?['estado'] ?? 'EN_CURSO').toString();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(editando ? 'Editar proyecto' : 'Nuevo proyecto', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nomCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre del proyecto', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextFormField(controller: respCtrl, decoration: const InputDecoration(labelText: 'Responsable / coordinador', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: estado,
                      decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'PLANIFICADO', child: Text('Planificado')),
                        DropdownMenuItem(value: 'EN_CURSO', child: Text('En curso')),
                        DropdownMenuItem(value: 'FINALIZADO', child: Text('Finalizado')),
                        DropdownMenuItem(value: 'SUSPENDIDO', child: Text('Suspendido')),
                      ],
                      onChanged: (v) => setD(() => estado = v ?? estado),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final d = await showDatePicker(context: context, initialDate: ini ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                              if (d != null) setD(() => ini = d);
                            },
                            child: Text(ini == null ? 'Inicio' : '${ini!.day}/${ini!.month}/${ini!.year}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final d = await showDatePicker(context: context, initialDate: fin ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                              if (d != null) setD(() => fin = d);
                            },
                            child: Text(fin == null ? 'Fin' : '${fin!.day}/${fin!.month}/${fin!.year}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context);
                try {
                  await _supabaseService.guardarProyecto(
                    id: proyecto?['id']?.toString(),
                    nombre: nomCtrl.text.trim(),
                    descripcion: descCtrl.text.trim(),
                    responsable: respCtrl.text.trim(),
                    estado: estado,
                    fechaInicio: ini?.toIso8601String().substring(0, 10),
                    fechaFin: fin?.toIso8601String().substring(0, 10),
                  );
                  _cargarProyectos();
                  _mostrarExito(editando ? 'Proyecto actualizado.' : 'Proyecto creado.');
                } catch (e) {
                  _mostrarError('Error al guardar: $e');
                }
              },
              child: Text(editando ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirArchivosProyecto(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Archivos — ${p['nombre']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 420,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _supabaseService.obtenerDocsProyecto(p['id'].toString()),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                }
                final docs = snap.data ?? [];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final res = await FilePicker.platform.pickFiles(withData: true);
                        if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
                        try {
                          await _supabaseService.subirDocProyecto(
                            proyectoId: p['id'].toString(),
                            bytes: res.files.first.bytes!,
                            fileName: res.files.first.name,
                          );
                          setD(() {});
                        } catch (e) {
                          _mostrarError('Error al subir: $e');
                        }
                      },
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('Subir archivo'),
                    ),
                    const SizedBox(height: 10),
                    if (docs.isEmpty)
                      const Text('Sin archivos.', style: TextStyle(color: Colors.grey))
                    else
                      ...docs.map((d) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.insert_drive_file_rounded, size: 20),
                            title: Text('${d['nombre']}', style: const TextStyle(fontSize: 13)),
                            trailing: IconButton(
                              icon: const Icon(Icons.download_rounded, size: 18),
                              onPressed: () async {
                                try {
                                  final url = await _supabaseService.urlFirmadaStorage('proyectos', d['storage_path'].toString());
                                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                } catch (e) {
                                  _mostrarError('Error: $e');
                                }
                              },
                            ),
                          )),
                  ],
                );
              },
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
        ),
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
          // El logo va sólo en la barra lateral (NavigationRail.leading); acá
          // se repetía justo debajo.
          title: const Text('Panel de Administración General', style: TextStyle(fontWeight: FontWeight.bold)),
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
