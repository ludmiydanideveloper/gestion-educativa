import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/alumno_asistencia.dart';
import '../services/print_helper.dart';
import '../utils/logo_base64.dart';

class PanelCalificaciones extends StatefulWidget {
  final String? materiaId;
  final String? cursoId;
  const PanelCalificaciones({super.key, this.materiaId, this.cursoId});

  @override
  State<PanelCalificaciones> createState() => _PanelCalificacionesState();
}

class _PanelCalificacionesState extends State<PanelCalificaciones> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _materias = [];
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _actividades = [];
  List<Map<String, dynamic>> _calificaciones = [];
  List<AlumnoAsistencia> _alumnos = [];

  String? _selectedMateriaId;

  /// Modo de cálculo del RITE:
  /// 'GRUPOS'      → promedio por categoría ponderado por el peso de la categoría (default)
  /// 'PORCENTAJE'  → cada actividad pesa su propio peso_porcentaje_actividad
  String _modoCalificacion = 'GRUPOS';

  // Definición fija de los 7 criterios del boletín cualitativo
  static const List<Map<String, String>> _kCriterios = [
    {'key': 'criterio_apropiacion',   'label': 'Apropiación\nde Contenidos'},
    {'key': 'criterio_resolucion',    'label': 'Resolución\nde Problemas'},
    {'key': 'criterio_participacion', 'label': 'Participación'},
    {'key': 'criterio_planteos',      'label': 'Planteos\ny Dudas'},
    {'key': 'criterio_entrega',       'label': 'Entrega en\nTiempo y Forma'},
    {'key': 'criterio_prolijidad',    'label': 'Prolijidad\ny Orden'},
    {'key': 'criterio_aic',           'label': 'AIC'},
  ];

  // Memoria de calificaciones local: alumnoId -> actividadId -> nota
  final Map<String, Map<String, double?>> _grades = {};
  
  // Controladores de texto para evitar regeneración y mantener el cursor: alumnoId_actividadId -> Controller
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _inicializarDatos() async {
    setState(() => _isLoading = true);
    try {
      // 1. Cargar materias
      _materias = await _supabaseService.obtenerMateriasParaRol();
      
      if (widget.materiaId != null) {
        _selectedMateriaId = widget.materiaId;
      } else if (_materias.isNotEmpty) {
        _selectedMateriaId = _materias.first['materia_id'] as String;
      }

      // 2. Cargar categorías para la materia seleccionada (propias + globales)
      //    y el modo de calificación configurado por el docente
      if (_selectedMateriaId != null) {
        _categorias = await _supabaseService.obtenerCategoriasMateria(_selectedMateriaId!);
        _modoCalificacion = await _supabaseService.obtenerModoCalificacion(_selectedMateriaId!);
      } else {
        _categorias = await _supabaseService.obtenerCategoriasCalificaciones();
      }

      // 3. Cargar alumnos vinculados específicamente al año/curso de la materia
      String? cursoId = widget.cursoId;
      if (_selectedMateriaId != null && _materias.isNotEmpty) {
        final mat = _materias.firstWhere((m) => m['materia_id'] == _selectedMateriaId, orElse: () => <String, dynamic>{});
        if (mat.isNotEmpty && mat['curso_id'] != null) {
          cursoId = mat['curso_id'].toString();
        }
      }
      if (cursoId != null) {
        _alumnos = await _supabaseService.fetchAlumnos(cursoId: cursoId);
      } else {
        _alumnos = await _supabaseService.fetchAlumnos();
      }

      // 4. Si hay materia seleccionada, cargar sus actividades y calificaciones
      if (_selectedMateriaId != null) {
        await _cargarPlanillaMateria();
      }
    } catch (e) {
      _mostrarError('Error al inicializar datos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cargarPlanillaMateria() async {
    if (_selectedMateriaId == null) return;

    // Recargar categorías propias + globales y modo de calificación para la nueva materia
    _categorias = await _supabaseService.obtenerCategoriasMateria(_selectedMateriaId!);
    _modoCalificacion = await _supabaseService.obtenerModoCalificacion(_selectedMateriaId!);

    // Guardar focos actuales o limpiar controladores
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    _grades.clear();

    // 1. Obtener el curso de la materia seleccionada para cargar ÚNICAMENTE los alumnos de ese curso/año
    String? cursoId = widget.cursoId;
    if (_materias.isNotEmpty && _selectedMateriaId != null) {
      final mat = _materias.firstWhere((m) => m['materia_id'] == _selectedMateriaId, orElse: () => <String, dynamic>{});
      if (mat.isNotEmpty && mat['curso_id'] != null) {
        cursoId = mat['curso_id'].toString();
      }
    }
    if (cursoId != null) {
      _alumnos = await _supabaseService.fetchAlumnos(cursoId: cursoId);
    } else {
      _alumnos = await _supabaseService.fetchAlumnos();
    }

    // Obtener actividades de la materia
    _actividades = await _supabaseService.obtenerActividades(_selectedMateriaId!);
    
    // Obtener todas las calificaciones
    final actIds = _actividades.map((a) => a['id'] as String).toList();
    _calificaciones = await _supabaseService.obtenerCalificacionesPorActividades(actIds);

    // Mapear calificaciones cargadas a la memoria local
    for (final calif in _calificaciones) {
      final alumnoId = calif['alumno_id'] as String;
      final actividadId = calif['actividad_id'] as String;
      final nota = calif['nota_numerica'] != null ? (calif['nota_numerica'] as num).toDouble() : null;
      
      _grades.putIfAbsent(alumnoId, () => {})[actividadId] = nota;
    }

    // Inicializar controladores de texto y nodos de foco para las celdas
    for (final alumno in _alumnos) {
      for (final actividad in _actividades) {
        final key = '${alumno.id}_${actividad['id']}';
        final nota = _grades[alumno.id]?[actividad['id']];
        final controller = TextEditingController(text: nota != null ? nota.toStringAsFixed(1) : '');
        _controllers[key] = controller;
        
        final focusNode = FocusNode();
        _focusNodes[key] = focusNode;

        // Listener para guardar al perder el foco
        focusNode.addListener(() {
          if (!focusNode.hasFocus) {
            _guardarNotaCelda(alumno.id, actividad['id'] as String, controller.text);
          }
        });
      }
    }
  }

  Future<void> _guardarNotaCelda(String alumnoId, String actividadId, String text) async {
    final double? anteriorNota = _grades[alumnoId]?[actividadId];
    double? nuevaNota;

    if (text.trim().isNotEmpty) {
      // Reemplazar coma por punto por si usan teclado móvil en español
      final normalizada = text.replaceAll(',', '.').trim();
      final parsed = double.tryParse(normalizada);
      
      if (parsed == null || parsed < 1.0 || parsed > 10.0) {
        _mostrarError('La nota debe ser un número decimal entre 1.0 y 10.0');
        // Revertir texto al valor anterior
        final key = '${alumnoId}_$actividadId';
        _controllers[key]?.text = anteriorNota != null ? anteriorNota.toStringAsFixed(1) : '';
        return;
      }
      nuevaNota = parsed;
    }

    // Si la nota no cambió, no guardamos
    if (nuevaNota == anteriorNota) return;

    setState(() {
      _grades.putIfAbsent(alumnoId, () => {})[actividadId] = nuevaNota;
    });

    try {
      await _supabaseService.upsertCalificacion(
        actividadId: actividadId,
        alumnoId: alumnoId,
        notaNumerica: nuevaNota,
      );
    } catch (e) {
      _mostrarError('Error al guardar en la base de datos: $e');
      // Revertir localmente
      setState(() {
        _grades[alumnoId]?[actividadId] = anteriorNota;
        final key = '${alumnoId}_$actividadId';
        _controllers[key]?.text = anteriorNota != null ? anteriorNota.toStringAsFixed(1) : '';
      });
    }
  }

  Future<void> _guardarTodasLasNotas() async {
    setState(() => _isSaving = true);
    int guardadas = 0;
    List<String> errores = [];

    try {
      for (final alumno in _alumnos) {
        for (final actividad in _actividades) {
          final actId = actividad['id'] as String;
          final key = '${alumno.id}_$actId';
          final controller = _controllers[key];
          if (controller == null) continue;

          final text = controller.text.trim();
          final double? anteriorNota = _grades[alumno.id]?[actId];
          double? nuevaNota;

          if (text.isNotEmpty) {
            final normalizada = text.replaceAll(',', '.').trim();
            final parsed = double.tryParse(normalizada);
            if (parsed == null || parsed < 1.0 || parsed > 10.0) {
              errores.add('Nota inválida para ${alumno.nombre} ($text). Debe ser entre 1.0 y 10.0.');
              continue;
            }
            nuevaNota = parsed;
          }

          if (nuevaNota != anteriorNota) {
            await _supabaseService.upsertCalificacion(
              actividadId: actId,
              alumnoId: alumno.id,
              notaNumerica: nuevaNota,
            );
            _grades.putIfAbsent(alumno.id, () => {})[actId] = nuevaNota;
            guardadas++;
          }
        }
      }

      if (!mounted) return;
      if (errores.isNotEmpty) {
        _mostrarError(errores.join('\n'));
      } else if (guardadas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Se guardaron $guardadas calificaciones correctamente!'),
            backgroundColor: Colors.green.shade800,
          ),
        );
        setState(() {}); // Re-renderizar RITE Final
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay cambios pendientes para guardar.'),
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error al guardar calificaciones: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Color _obtenerColorCategoria(String nombreCat) {
    final nombreLower = nombreCat.toLowerCase();
    if (nombreLower.contains('evidencia')) {
      return Colors.teal.shade700;
    } else if (nombreLower.contains('desempeñ')) {
      return Colors.orange.shade800;
    } else if (nombreLower.contains('auto')) {
      return Colors.purple.shade700;
    }
    return Colors.blueGrey;
  }

  void _abrirModalNuevaNota() {
    if (_selectedMateriaId == null) {
      _mostrarError('Primero debe seleccionar una materia.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final tituloController = TextEditingController();
    String? selectedCategoriaId;
    if (_categorias.isNotEmpty) {
      selectedCategoriaId = _categorias.first['id'] as String;
    }
    String tipoNota = 'NUMERICA'; // 'NUMERICA', 'TAREA', 'INFORMATIVA', 'CONDUCTA'
    DateTime selectedFecha = DateTime.now();
    bool agendarEnCalendario = true;
    double? pesoActividad; // Solo se usa en modo PORCENTAJE
    final pesoCtrlModal = TextEditingController();

    final matSeleccionada = _materias.firstWhere((m) => m['materia_id'] == _selectedMateriaId, orElse: () => <String, dynamic>{});
    final nombreMateria = matSeleccionada['nombre_asignatura']?.toString() ?? 'Materia';
    final cursoIdMateria = matSeleccionada['curso_id']?.toString() ?? widget.cursoId;

    final currentUser = Supabase.instance.client.auth.currentUser;
    final nombreRegistro = currentUser?.userMetadata?['nombre'] ??
        currentUser?.userMetadata?['first_name'] ??
        currentUser?.email ??
        'Docente / Administrador';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setModalState) {
            final fechaStr = "${selectedFecha.day.toString().padLeft(2, '0')}/${selectedFecha.month.toString().padLeft(2, '0')}/${selectedFecha.year}";
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
              title: const Row(
                children: [
                  Icon(Icons.add_task_rounded, color: Colors.blueAccent),
                  SizedBox(width: 12),
                  Text('Nueva Nota / Calificación', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_pin_rounded, color: Colors.blue.shade700, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Registrado por: $nombreRegistro',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900)),
                                Text('Materia: $nombreMateria',
                                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título de la Nota / Tarea / Evaluación',
                        hintText: 'Ej: Examen Trimestral, Trabajo Práctico N°1',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Selector de Fecha
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: builderContext,
                          initialDate: selectedFecha,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2027),
                        );
                        if (picked != null) {
                          setModalState(() => selectedFecha = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 20, color: Colors.blueGrey),
                                const SizedBox(width: 10),
                                Text('Fecha de Evaluación: $fechaStr', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const Icon(Icons.edit_calendar_rounded, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Switch / Checkbox para publicar en Calendario
                    Container(
                      decoration: BoxDecoration(
                        color: agendarEnCalendario ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: agendarEnCalendario ? Colors.green.shade300 : Colors.grey.shade300),
                      ),
                      child: SwitchListTile(
                        value: agendarEnCalendario,
                        onChanged: (val) => setModalState(() => agendarEnCalendario = val),
                        activeColor: Colors.green.shade700,
                        title: const Text('Publicar en Calendario Familiar y Docente',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('Las familias verán esta evaluación programada en su cronograma.',
                            style: TextStyle(fontSize: 11)),
                        dense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tipo de Registro:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('Nota Numérica 1-10 (Promedia)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: const Text('Promedia según el peso de la categoría asignada.'),
                            value: 'NUMERICA',
                            groupValue: tipoNota,
                            dense: true,
                            onChanged: (val) => setModalState(() => tipoNota = val!),
                          ),
                          RadioListTile<String>(
                            title: const Text('Check de Tareas Sí / No (Evidencias 60%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                            subtitle: const Text('Entra directamente en el 60% de las evidencias.'),
                            value: 'TAREA',
                            groupValue: tipoNota,
                            dense: true,
                            onChanged: (val) {
                              setModalState(() {
                                tipoNota = val!;
                                if (_categorias.isNotEmpty) {
                                  final catEvidencia = _categorias.firstWhere(
                                    (c) => c['nombre'].toString().toLowerCase().contains('evidencia'),
                                    orElse: () => _categorias.first,
                                  );
                                  selectedCategoriaId = catEvidencia['id'] as String;
                                }
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('Nota de Informe (No suma / No promedia)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple)),
                            subtitle: const Text('Casillero informativo sobre cómo van hasta el momento.'),
                            value: 'INFORMATIVA',
                            groupValue: tipoNota,
                            dense: true,
                            onChanged: (val) => setModalState(() => tipoNota = val!),
                          ),
                          RadioListTile<String>(
                            title: const Text('Nota de Conducta Diaria (No suma en RITE)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber)),
                            subtitle: const Text('Casillero para el seguimiento de comportamiento y conducta diaria.'),
                            value: 'CONDUCTA',
                            groupValue: tipoNota,
                            dense: true,
                            onChanged: (val) => setModalState(() => tipoNota = val!),
                          ),
                        ],
                      ),
                    ),
                    if (tipoNota != 'TAREA') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedCategoriaId,
                        decoration: const InputDecoration(
                          labelText: 'Grupo / Categoría de Nota',
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        ),
                        items: _categorias.map((cat) {
                          final peso = (cat['peso_porcentaje'] as num).toInt();
                          return DropdownMenuItem<String>(
                            value: cat['id'] as String,
                            child: Text('${cat['nombre']} ($peso%)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setModalState(() => selectedCategoriaId = val);
                        },
                      ),
                    ],
                    // Campo de peso % solo en modo "% por Actividad"
                    if (_modoCalificacion == 'PORCENTAJE' && tipoNota == 'NUMERICA') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.percent, size: 16, color: Colors.purple.shade700),
                              const SizedBox(width: 6),
                              Text('¿Qué porcentaje de la nota final vale esta evaluación?',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple.shade800)),
                            ]),
                            const SizedBox(height: 8),
                            TextField(
                              controller: pesoCtrlModal,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Peso %',
                                hintText: 'Ej: 30',
                                suffixText: '%',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (val) {
                                pesoActividad = double.tryParse(val.replaceAll(',', '.'));
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(builderContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final titulo = tituloController.text.trim();
                          if (titulo.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Por favor ingrese un título')),
                            );
                            return;
                          }
                          if (selectedCategoriaId == null) return;

                          String finalTitulo = titulo;
                          if (tipoNota == 'TAREA' && !finalTitulo.startsWith('[TAREA]')) {
                            finalTitulo = '[TAREA] $finalTitulo';
                          } else if (tipoNota == 'INFORMATIVA' && !finalTitulo.startsWith('[INFO]')) {
                            finalTitulo = '[INFO] $finalTitulo';
                          } else if (tipoNota == 'CONDUCTA' && !finalTitulo.startsWith('[CONDUCTA]')) {
                            finalTitulo = '[CONDUCTA] $finalTitulo';
                          }

                          Navigator.of(builderContext).pop(); // Cerrar modal usando el context interno
                          setState(() => _isSaving = true);

                          try {
                            await _supabaseService.crearActividad(
                              materiaId: _selectedMateriaId!,
                              categoriaId: selectedCategoriaId!,
                              titulo: finalTitulo,
                              fecha: selectedFecha,
                              pesoPorc: (_modoCalificacion == 'PORCENTAJE' && tipoNota == 'NUMERICA')
                                  ? pesoActividad
                                  : null,
                            );

                            if (agendarEnCalendario) {
                              try {
                                await _supabaseService.crearEventoCalendario(
                                  titulo: '$nombreMateria: $finalTitulo',
                                  descripcion: 'Evaluación / Calificación programada en planilla de $nombreMateria.',
                                  fecha: selectedFecha.toIso8601String().substring(0, 10),
                                  tipoEvento: 'EVALUACION',
                                  cursoId: cursoIdMateria,
                                );
                              } catch (calErr) {
                                print('Aviso: no se pudo sincronizar con calendario: $calErr');
                              }
                            }
                            
                            // Recargar planilla
                            await _cargarPlanillaMateria();
                            
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Nota y agendamiento en calendario creados exitosamente'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error al crear nota: $e'),
                                  backgroundColor: Colors.red.shade800,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isSaving = false);
                            }
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Crear y Agendar'),
                ),
              ],
            );
          },
        );
      },
    );

    // Liberar controllers del modal
    tituloController.dispose();
    pesoCtrlModal.dispose();
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _abrirModalRubrica() {
    if (_actividades.isEmpty) {
      _mostrarError('Primero debe crear al menos una nota para poder calcular o configurar la rúbrica.');
      return;
    }

    // Default weight values
    double pesoExamen = 50.0;
    double pesoTrabajos = 30.0;
    double pesoParticipacion = 20.0;

    // Student scores maps
    final Map<String, double> notaExamen = {};
    final Map<String, double> notaTrabajos = {};
    final Map<String, double> notaParticipacion = {};

    // Initialize students with default scores (7.0)
    for (final a in _alumnos) {
      notaExamen[a.id] = 7.0;
      notaTrabajos[a.id] = 7.0;
      notaParticipacion[a.id] = 7.0;
    }

    String? selectedActivityId = _actividades.first['id'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double totalPeso = pesoExamen + pesoTrabajos + pesoParticipacion;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Asistente de Rúbrica Pedagógica'),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paso 1: Defina el peso porcentual de cada criterio de evaluación',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: pesoExamen.toString(),
                              decoration: const InputDecoration(labelText: 'Examen (%)'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                setModalState(() => pesoExamen = double.tryParse(val) ?? 0.0);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: pesoTrabajos.toString(),
                              decoration: const InputDecoration(labelText: 'Trabajos (%)'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                setModalState(() => pesoTrabajos = double.tryParse(val) ?? 0.0);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: pesoParticipacion.toString(),
                              decoration: const InputDecoration(labelText: 'Participación (%)'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                setModalState(() => pesoParticipacion = double.tryParse(val) ?? 0.0);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total Porcentual: ${totalPeso.toStringAsFixed(0)}% (Debe sumar 100%)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: totalPeso == 100 ? Colors.green : Colors.red,
                        ),
                      ),
                      const Divider(height: 24),
                      const Text(
                        'Paso 2: Seleccione la Actividad destino en la planilla',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: selectedActivityId,
                        isExpanded: true,
                        items: _actividades.map((a) {
                          return DropdownMenuItem<String>(
                            value: a['id'] as String,
                            child: Text(a['titulo'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedActivityId = val);
                          }
                        },
                      ),
                      const Divider(height: 24),
                      const Text(
                        'Paso 3: Cargue el desempeño de cada estudiante',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _alumnos.length,
                        itemBuilder: (context, idx) {
                          final student = _alumnos[idx];
                          final currentEx = notaExamen[student.id] ?? 7.0;
                          final currentTr = notaTrabajos[student.id] ?? 7.0;
                          final currentPa = notaParticipacion[student.id] ?? 7.0;

                          final double computedFinal = totalPeso > 0
                              ? ((currentEx * pesoExamen) +
                                      (currentTr * pesoTrabajos) +
                                      (currentPa * pesoParticipacion)) /
                                  totalPeso
                              : 0.0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.nombre,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: currentEx.toString(),
                                        decoration: const InputDecoration(labelText: 'Examen', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          notaExamen[student.id] = double.tryParse(val) ?? 0.0;
                                          setModalState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: currentTr.toString(),
                                        decoration: const InputDecoration(labelText: 'T.P.', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          notaTrabajos[student.id] = double.tryParse(val) ?? 0.0;
                                          setModalState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: currentPa.toString(),
                                        decoration: const InputDecoration(labelText: 'Partic.', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          notaParticipacion[student.id] = double.tryParse(val) ?? 0.0;
                                          setModalState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.purple.shade200),
                                      ),
                                      child: Text(
                                        computedFinal.toStringAsFixed(1),
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade800),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: totalPeso == 100 ? Colors.purple : Colors.grey,
                  ),
                  onPressed: totalPeso == 100
                      ? () {
                          setState(() {
                            for (final a in _alumnos) {
                              final ex = notaExamen[a.id] ?? 7.0;
                              final tr = notaTrabajos[a.id] ?? 7.0;
                              final pa = notaParticipacion[a.id] ?? 7.0;
                              final finalGrade = ((ex * pesoExamen) +
                                      (tr * pesoTrabajos) +
                                      (pa * pesoParticipacion)) /
                                  100;

                              if (!_grades.containsKey(a.id)) {
                                _grades[a.id] = {};
                              }
                              _grades[a.id]![selectedActivityId!] = finalGrade;

                              final key = '${a.id}_$selectedActivityId';
                              if (_controllers.containsKey(key)) {
                                _controllers[key]!.text = finalGrade.toStringAsFixed(1);
                              }
                            }
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notas calculadas por rúbrica e insertadas con éxito en la planilla.')),
                          );
                        }
                      : null,
                  child: const Text('Cargar en Planilla'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double? _calcularPromedioTareas(String alumnoId) {
    final studentGrades = _grades[alumnoId] ?? {};
    final tareas = _actividades.where((a) => a['titulo'].toString().startsWith('[TAREA]')).toList();
    if (tareas.isEmpty) return null;

    List<double> notas = [];
    for (final t in tareas) {
      final actId = t['id'];
      final n = studentGrades[actId];
      if (n != null) notas.add(n);
    }
    if (notas.isEmpty) return null;
    return notas.reduce((a, b) => a + b) / notas.length;
  }

  void _generarNotaSeguimientoInforme() async {
    if (_selectedMateriaId == null) {
      _mostrarError('Primero debe seleccionar una materia.');
      return;
    }

    final informes = _actividades.where((a) => a['titulo'].toString().startsWith('[INFO]')).toList();
    if (informes.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.purple),
              SizedBox(width: 8),
              Text('Crear Columna de Informe'),
            ],
          ),
          content: const Text(
            'No tienes creada ninguna columna de tipo "Informe (No suma)".\n\n¿Deseas crear automáticamente la columna "[INFO] Seguimiento" y rellenarla con el promedio RITE actual de cada alumno hasta la fecha de hoy?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Crear y Rellenar'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      if (_categorias.isEmpty) {
        _mostrarError('No hay categorías configuradas para esta materia.');
        return;
      }

      setState(() => _isLoading = true);
      try {
        await _supabaseService.crearActividad(
          materiaId: _selectedMateriaId!,
          categoriaId: _categorias.first['id'] as String,
          titulo: '[INFO] Seguimiento del Proceso',
          fecha: DateTime.now(),
        );
        await _cargarPlanillaMateria();
      } catch (e) {
        _mostrarError('Error al crear la columna de informe: $e');
        setState(() => _isLoading = false);
        return;
      }
    }

    final informesActualizados = _actividades.where((a) => a['titulo'].toString().startsWith('[INFO]')).toList();
    if (informesActualizados.isEmpty) return;

    Map<String, dynamic> actSeleccionada = informesActualizados.first;
    if (informesActualizados.length > 1) {
      final sel = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Selecciona en qué columna de Informe volcar el promedio actual:'),
          children: informesActualizados.map((act) {
            return SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(act),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(act['titulo'].toString().replaceAll('[INFO] ', '').replaceAll('[INFO]', ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            );
          }).toList(),
        ),
      );
      if (sel == null) return;
      actSeleccionada = sel;
    }

    final infoActId = actSeleccionada['id'] as String;
    final infoTitulo = actSeleccionada['titulo'].toString().replaceAll('[INFO] ', '').replaceAll('[INFO]', '');

    final confirmVolcar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.purple),
            SizedBox(width: 8),
            Text('Volcar Promedio Actual'),
          ],
        ),
        content: Text(
          'Se rellenará la columna "$infoTitulo" con el promedio RITE que lleva cada alumno hasta el momento.\n\nAl cargarse, podrás hacer clic en el casillero de cualquier alumno para modificar su nota manualmente según tu criterio pedagógico. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Generar Seguimiento'),
          ),
        ],
      ),
    );

    if (confirmVolcar != true) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      int guardados = 0;
      for (final alumno in _alumnos) {
        final riteActual = _calculateLocalRite(alumno.id);
        if (riteActual != null) {
          final rounded = double.parse(riteActual.toStringAsFixed(1));
          _grades[alumno.id] ??= {};
          _grades[alumno.id]![infoActId] = rounded;
          _controllers['${alumno.id}_$infoActId']?.text = rounded.toStringAsFixed(1);

          await _supabaseService.upsertCalificacion(
            actividadId: infoActId,
            alumnoId: alumno.id,
            notaNumerica: rounded,
          );
          guardados++;
        }
      }

      setState(() => _isSaving = false);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ Se generó el seguimiento en "$infoTitulo" para $guardados alumnos. ¡Ya puedes modificar las notas que consideres!'),
            backgroundColor: Colors.purple.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _mostrarError('Error al volcar promedios: $e');
    }
  }

  /// Muestra un diálogo para elegir el tipo de boletín antes de imprimir.
  Future<void> _mostrarDialogoImpresion({AlumnoAsistencia? alumnoEspecifico}) async {
    String? elegido = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Imprimir Boletín', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('¿Qué período querés imprimir?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, '1°C'), child: const Text('1° Cuatrimestre')),
          TextButton(onPressed: () => Navigator.pop(ctx, '2°C'), child: const Text('2° Cuatrimestre')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'ANUAL'), child: const Text('Anual')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ],
      ),
    );
    if (elegido == null) return;
    await _imprimirBoletinGeneralCurso(alumnoEspecifico: alumnoEspecifico, tipoBoletin: elegido);
  }

  Future<void> _imprimirBoletinGeneralCurso({AlumnoAsistencia? alumnoEspecifico, String tipoBoletin = 'ANUAL'}) async {
    setState(() => _isLoading = true);
    try {
      String? cursoId = widget.cursoId;
      if (_materias.isNotEmpty && _selectedMateriaId != null) {
        final mat = _materias.firstWhere(
          (m) => m['materia_id'] == _selectedMateriaId,
          orElse: () => <String, dynamic>{},
        );
        if (mat.isNotEmpty && mat['curso_id'] != null) {
          cursoId = mat['curso_id'].toString();
        }
      }

      final alumnosIds = alumnoEspecifico != null
          ? [alumnoEspecifico.id]
          : _alumnos.map((a) => a.id).toList();

      final datos = await _supabaseService.obtenerDatosBoletinCompleto(
        cursoId: cursoId,
        alumnosIds: alumnosIds,
      );

      final List<Map<String, dynamic>> materiasCurso =
          List<Map<String, dynamic>>.from(datos['materias'] ?? []);
      final List<Map<String, dynamic>> rubricas =
          List<Map<String, dynamic>>.from(datos['rubricas'] ?? []);
      final List<Map<String, dynamic>> cierres =
          List<Map<String, dynamic>>.from(datos['cierres'] ?? []);
      final String identificadorDivision =
          datos['identificadorDivision']?.toString() ?? '';
      final Map<String, dynamic> alumnosDemoData =
          Map<String, dynamic>.from(datos['alumnosDemoData'] ?? {});

      if (materiasCurso.isEmpty) {
        _mostrarError('No se encontraron materias para este curso.');
        return;
      }

      final alumnosAPrint =
          alumnoEspecifico != null ? [alumnoEspecifico] : _alumnos;
      final List<String> boletinesHtml = [];

      for (final alumno in alumnosAPrint) {
        final demo =
            alumnosDemoData[alumno.id] as Map<String, dynamic>? ?? {};
        final dni = demo['dni']?.toString() ?? '-';

        final List<String> filasMaterias = [];

        for (final mat in materiasCurso) {
          final matId = mat['materia_id'] as String;
          final nombreMat =
              (mat['nombre_asignatura'] ?? 'Materia').toString().toUpperCase();

          // Todas las rubricas de este alumno/materia
          final rubricasMat = rubricas
              .where((r) =>
                  r['alumno_id'] == alumno.id && r['materia_id'] == matId)
              .toList();

          // Etapa base según tipo de boletín
          final etapaSeg = tipoBoletin == '2°C' ? '2° SEGUIMIENTO' : '1° SEGUIMIENTO';
          final etapaCierre = tipoBoletin == '2°C' ? '2° CIERRE' : '1° CIERRE';

          Map<String, dynamic>? buscarRubrica(String et) =>
              rubricasMat.where((r) => r['etapa'] == et).isNotEmpty
                  ? rubricasMat.firstWhere((r) => r['etapa'] == et)
                  : null;

          // Para ANUAL: criterios del 1° CIERRE; para cuatrimestre: del cierre correspondiente
          final rubricaSeg = buscarRubrica(etapaSeg);
          final rubricaCierre = buscarRubrica(etapaCierre);
          // Fallback para ANUAL
          final rubrica = rubricaCierre ?? rubricaSeg ??
              (rubricasMat.isNotEmpty ? rubricasMat.first : null);

          // Cierres de etapa para esta materia/alumno
          final cierresMat = cierres
              .where((c) =>
                  c['alumno_id'] == alumno.id && c['materia_id'] == matId)
              .toList();

          Map<String, dynamic>? buscarCierre(String etapa) {
            final matches =
                cierresMat.where((c) => c['etapa'] == etapa).toList();
            return matches.isNotEmpty ? matches.first : null;
          }

          final cierre1   = buscarCierre('1° CIERRE');
          final cierre2   = buscarCierre('2° CIERRE');
          final cierreDic = buscarCierre('INTENSIFICACION_DIC');
          final cierreFeb = buscarCierre('INTENSIFICACION_FEB');

          // Criterios de rúbrica (usados en boletín ANUAL)
          String cr(String key) => rubrica?[key]?.toString() ?? '';
          // Criterios del seguimiento (cuatrimestre)
          String crs(String key) => rubricaSeg?[key]?.toString() ?? '';
          // Criterios del cierre (cuatrimestre)
          String crc(String key) => rubricaCierre?[key]?.toString() ?? '';

          String formatNota(Map<String, dynamic>? c) =>
              c?['calificacion_numerica'] != null
                  ? (c!['calificacion_numerica'] as num).toStringAsFixed(1)
                  : '';

          if (tipoBoletin == 'ANUAL') {
            // ── Boletín ANUAL: 1 set criterios (del cierre) + ambas calificaciones ──
            final ap  = cr('criterio_apropiacion');
            final res = cr('criterio_resolucion');
            final par = cr('criterio_participacion');
            final pla = cr('criterio_planteos');
            final ent = cr('criterio_entrega');
            final pro = cr('criterio_prolijidad');
            final aic = cr('criterio_aic');

            final resumen1 = cierre1?['condicion_trayectoria']?.toString() ?? '';
            final resumen2 = cierre2?['condicion_trayectoria']?.toString() ?? '';
            final intDic = formatNota(cierreDic);
            final intFeb = formatNota(cierreFeb);

            final nota1 = cierre1?['calificacion_numerica'] != null
                ? (cierre1!['calificacion_numerica'] as num).toDouble() : null;
            final nota2 = cierre2?['calificacion_numerica'] != null
                ? (cierre2!['calificacion_numerica'] as num).toDouble() : null;
            String calFinal = '';
            if (nota1 != null && nota2 != null) {
              calFinal = ((nota1 + nota2) / 2).toStringAsFixed(1);
            } else if (nota1 != null) {
              calFinal = nota1.toStringAsFixed(1);
            } else if (nota2 != null) {
              calFinal = nota2.toStringAsFixed(1);
            }
            final nota1Str = nota1 != null ? nota1.toStringAsFixed(0) : '';
            final nota2Str = nota2 != null ? nota2.toStringAsFixed(0) : '';

            filasMaterias.add('''
              <tr>
                <td class="td-mat">$nombreMat</td>
                <td class="td-c">$ap</td><td class="td-c">$res</td><td class="td-c">$par</td>
                <td class="td-c">$pla</td><td class="td-c">$ent</td><td class="td-c">$pro</td>
                <td class="td-c">$aic</td>
                <td class="td-c"></td>
                <td class="td-c td-tray">$resumen1</td>
                <td class="td-c td-final">$nota1Str</td>
                <td class="td-c td-tray">$resumen2</td>
                <td class="td-c td-final">$nota2Str</td>
                <td class="td-c">$intDic</td>
                <td class="td-c">$intFeb</td>
                <td class="td-c td-final">$calFinal</td>
              </tr>
            ''');
          } else {
            // ── Boletín CUATRIMESTRAL: seguimiento + cierre, 1 calificación ──
            final cierreCuat = tipoBoletin == '2°C' ? cierre2 : cierre1;
            final resumenCuat = cierreCuat?['condicion_trayectoria']?.toString() ?? '';
            final notaCuat = cierreCuat?['calificacion_numerica'] != null
                ? (cierreCuat!['calificacion_numerica'] as num).toStringAsFixed(0) : '';
            final intDic = formatNota(cierreDic);
            final intFeb = formatNota(cierreFeb);
            // Datos de seguimiento
            final cierreSeg = buscarCierre(etapaSeg);
            final riteSeg    = cierreSeg?['condicion_trayectoria']?.toString() ?? '';
            final calSeg     = cierreSeg?['calificacion_numerica'] != null
                ? (cierreSeg!['calificacion_numerica'] as num).toStringAsFixed(0) : '';
            // calFinal solo para 2° cuatrimestre
            String calFinal = '';
            if (tipoBoletin == '2°C') {
              final n1 = cierre1?['calificacion_numerica'] != null
                  ? (cierre1!['calificacion_numerica'] as num).toDouble() : null;
              final n2 = cierre2?['calificacion_numerica'] != null
                  ? (cierre2!['calificacion_numerica'] as num).toDouble() : null;
              if (n1 != null && n2 != null) calFinal = ((n1 + n2) / 2).toStringAsFixed(1);
              else if (n2 != null) calFinal = n2.toStringAsFixed(1);
            }
            final colsExtra = tipoBoletin == '2°C'
                ? '<td class="td-c">$intDic</td><td class="td-c">$intFeb</td><td class="td-c td-final">$calFinal</td>'
                : '';
            filasMaterias.add('''
              <tr>
                <td class="td-mat">$nombreMat</td>
                <td class="td-c">${crs('criterio_apropiacion')}</td>
                <td class="td-c">${crs('criterio_resolucion')}</td>
                <td class="td-c">${crs('criterio_participacion')}</td>
                <td class="td-c">${crs('criterio_planteos')}</td>
                <td class="td-c">${crs('criterio_entrega')}</td>
                <td class="td-c">${crs('criterio_prolijidad')}</td>
                <td class="td-c">${crs('criterio_aic')}</td>
                <td class="td-c"></td>
                <td class="td-c td-tray">$riteSeg</td>
                <td class="td-c td-final">$calSeg</td>
                <td class="td-c">${crc('criterio_apropiacion')}</td>
                <td class="td-c">${crc('criterio_resolucion')}</td>
                <td class="td-c">${crc('criterio_participacion')}</td>
                <td class="td-c">${crc('criterio_planteos')}</td>
                <td class="td-c">${crc('criterio_entrega')}</td>
                <td class="td-c">${crc('criterio_prolijidad')}</td>
                <td class="td-c">${crc('criterio_aic')}</td>
                <td class="td-c"></td>
                <td class="td-c td-tray">$resumenCuat</td>
                <td class="td-c td-final">$notaCuat</td>
                $colsExtra
              </tr>
            ''');
          }
        }

        final tablaMateriaHtml = filasMaterias.join('');

        // Encabezado de tabla según tipo de boletín
        final String tablaHeader;
        final String tablaFooter;
        if (tipoBoletin == 'ANUAL') {
          tablaHeader = '''
            <tr>
              <th rowspan="2" class="th-mat">MATERIA</th>
              <th colspan="15" class="th-group">CRITERIOS Y CALIFICACIÓN</th>
            </tr>
            <tr>
              <th class="th-r"><span class="rot">Apropiación de los contenidos</span></th>
              <th class="th-r"><span class="rot">Resolución de actividades</span></th>
              <th class="th-r"><span class="rot">Participación en clases</span></th>
              <th class="th-r"><span class="rot">Planteos y dudas</span></th>
              <th class="th-r"><span class="rot">Entrega en tiempo y forma</span></th>
              <th class="th-r"><span class="rot">Prolijidad y carpeta</span></th>
              <th class="th-r"><span class="rot">Cumplimiento AIC*</span></th>
              <th class="th-r"><span class="rot">TOTAL INASISTENCIAS</span></th>
              <th class="th-r"><span class="rot">RITE 1° ETAPA</span></th>
              <th class="th-r"><span class="rot">CALIFICACIÓN 1° ETAPA</span></th>
              <th class="th-r"><span class="rot">RITE 2° ETAPA</span></th>
              <th class="th-r"><span class="rot">CALIFICACIÓN 2° ETAPA</span></th>
              <th class="th-r"><span class="rot">INTENS. DICIEMBRE</span></th>
              <th class="th-r"><span class="rot">INTENS. FEBRERO</span></th>
              <th class="th-r"><span class="rot">CALIFICACIÓN FINAL</span></th>
            </tr>''';
          tablaFooter = '''
            <tr>
              <td class="td-foot" colspan="9">TOTAL DE INASISTENCIAS DIARIAS</td>
              <td class="td-c" colspan="7"></td>
            </tr>
            <tr>
              <td class="td-foot" colspan="16" style="height:28px;">INFORME DE PRECEPTORÍA</td>
            </tr>''';
        } else {
          final labelCuat = tipoBoletin == '1°C' ? '1° CUATRIMESTRE' : '2° CUATRIMESTRE';
          // Seguimiento: 7 criterios + INAS + RITE + CAL = 10 cols
          // Cierre:      7 criterios + INAS + RITE + CAL = 10 cols
          // Extra 2°C: INTENS DIC + INTENS FEB + CAL FINAL = 3 cols
          final colsExtraHeader = tipoBoletin == '2°C'
              ? '<th colspan="3" class="th-group">INTENSIFICACIONES</th>'
              : '';
          final colsExtraHeader2 = tipoBoletin == '2°C'
              ? '<th class="th-r"><span class="rot">INTENS. DIC</span></th>'
                '<th class="th-r"><span class="rot">INTENS. FEB</span></th>'
                '<th class="th-r"><span class="rot">CAL. FINAL</span></th>'
              : '';
          final totalColsCuat = tipoBoletin == '2°C' ? 24 : 21;
          tablaHeader = '''
            <tr>
              <th rowspan="2" class="th-mat">MATERIA</th>
              <th colspan="10" class="th-group">SEGUIMIENTO — $labelCuat</th>
              <th colspan="10" class="th-group">CIERRE — $labelCuat</th>
              $colsExtraHeader
            </tr>
            <tr>
              <th class="th-r th-grp-seg"><span class="rot">Apropiación</span></th>
              <th class="th-r th-grp-seg"><span class="rot">Resolución</span></th>
              <th class="th-r th-grp-seg"><span class="rot">Participación</span></th>
              <th class="th-r th-grp-seg"><span class="rot">Planteos</span></th>
              <th class="th-r th-grp-seg"><span class="rot">Entrega</span></th>
              <th class="th-r th-grp-seg"><span class="rot">Prolijidad</span></th>
              <th class="th-r th-grp-seg"><span class="rot">AIC*</span></th>
              <th class="th-r th-grp-seg"><span class="rot">INAS.</span></th>
              <th class="th-r th-grp-seg"><span class="rot">RITE</span></th>
              <th class="th-r th-grp-seg"><span class="rot">CAL.</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Apropiación</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Resolución</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Participación</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Planteos</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Entrega</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Prolijidad</span></th>
              <th class="th-r th-grp-cie"><span class="rot">AIC*</span></th>
              <th class="th-r th-grp-cie"><span class="rot">INAS.</span></th>
              <th class="th-r th-grp-cie"><span class="rot">RITE</span></th>
              <th class="th-r th-grp-cie"><span class="rot">CAL.</span></th>
              $colsExtraHeader2
            </tr>''';
          tablaFooter = '''
            <tr>
              <td class="td-foot" colspan="${totalColsCuat}" style="height:20px;">INFORME DE PRECEPTORÍA</td>
            </tr>''';
        }

        boletinesHtml.add('''
          <div class="boletin-page">

            <!-- ===== ENCABEZADO ===== -->
            <div class="header-wrap" style="position:relative;">
              <div class="header-left">
                <img src="$kLogoBase64" alt="Logo Instituto" style="height:100px; width:auto; object-fit:contain;">
                <div class="inst-sep"></div>
                <div class="inst-loc">B&nbsp;A&nbsp;R&nbsp;A&nbsp;D&nbsp;E&nbsp;R&nbsp;O</div>
              </div>
              <div class="header-center">BOLETÍN ACADÉMICO</div>
              <div class="header-right">NIVEL SECUNDARIO</div>
            </div>
            <hr class="hr-thin">

            <!-- ===== DATOS DEL ALUMNO ===== -->
            <div class="alumno-row">
              <span><span class="lbl">ALUMNO/A:</span>&nbsp;<strong>${alumno.nombre.toUpperCase()}</strong></span>
              <span><span class="lbl">DNI:</span>&nbsp;<strong>$dni</strong></span>
              <span><span class="lbl">AÑO:</span>&nbsp;<strong>$identificadorDivision</strong></span>
            </div>

            <!-- ===== TABLA PRINCIPAL ===== -->
            <table class="tbl">
              <thead>
                $tablaHeader
              </thead>
              <tbody>
                $tablaMateriaHtml
                $tablaFooter
              </tbody>
            </table>

            <!-- ===== FIRMAS ===== -->
            <div class="firmas">
              <div class="firma"><div class="firma-linea"></div>Firma Dirección</div>
              <div class="firma"><div class="firma-linea"></div>Firma Docente / Preceptor</div>
              <div class="firma"><div class="firma-linea"></div>Firma Madre / Padre / Tutor</div>
            </div>

            <!-- ===== LEYENDA ===== -->
            <div class="leyenda">
              <strong>Apreciaciones:</strong>&nbsp; S: Sobresaliente &ndash; MB: Muy bueno &ndash; B: Bueno &ndash; R: Regular<br>
              <strong>TEA:</strong> Trayectoria Educativa Avanzada &nbsp;&ndash;&nbsp;
              <strong>TEP:</strong> Trayectoria Educativa en Proceso &nbsp;&ndash;&nbsp;
              <strong>TED:</strong> Trayectoria Educativa Discontinua<br>
              <strong>*AIC:</strong> Acuerdos Institucionales de Convivencia.&nbsp;&nbsp;
              <strong>*INASISTENCIAS:</strong> Actualización según Resolución 1650/24 Régimen Académico; tardanzas se computará &frac14; de falta, total de inasistencias anuales 28.
            </div>

            <!-- ===== PIE INSTITUCIONAL ===== -->
            <div class="pie-inst">
              DIEGEP 8942 &nbsp;&bull;&nbsp; Jujuy y Saavedra, (2942) Baradero, Buenos Aires, Argentina<br>
              +54 9 3329 489305 &nbsp;&bull;&nbsp; iabar.educacionadventista.com &nbsp;&bull;&nbsp; instituto.iabar@educacionadventista.org.ar
            </div>

          </div>
        ''');
      }

      final contenidoTotal = boletinesHtml.join('');

      PrintHelper.imprimirHTML(
        titulo: alumnoEspecifico != null
            ? 'Boletín - ${alumnoEspecifico.nombre}'
            : 'Boletín',
        mostrarEncabezado: false,
        htmlContentBody: '''
          <style>
            @page { size: A4 landscape; margin: 4mm; }
            * { box-sizing: border-box; }
            body { font-family: Arial, Helvetica, sans-serif; font-size: 10px; color: #111; margin: 0; padding: 0; }

            .boletin-page {
              padding: 2mm 3mm;
              page-break-after: always;
              background: #fff;
            }

            /* --- ENCABEZADO --- */
            .header-wrap {
              display: flex;
              justify-content: space-between;
              align-items: center;
              margin-bottom: 1px;
            }
            .header-left { display: flex; align-items: center; gap: 8px; }
            .inst-sep { width: 1px; height: 36px; background: #bbb; }
            .inst-loc { font-size: 10px; letter-spacing: 2px; color: #1565C0; font-weight: bold; }
            .header-center {
              position: absolute; left: 50%; transform: translateX(-50%);
              font-size: 13px; font-weight: bold; color: #111;
              letter-spacing: 1px;
            }
            .header-right { font-size: 14px; font-weight: bold; letter-spacing: 1px; }
            .hr-thin { border: none; border-top: 1.5px solid #1565C0; margin: 1px 0 3px; }

            /* --- ALUMNO --- */
            .alumno-row {
              display: flex;
              justify-content: flex-end;
              align-items: center;
              font-size: 12px;
              margin-bottom: 3px;
              gap: 20px;
            }
            .lbl { font-weight: bold; }

            /* --- TABLA --- */
            .tbl {
              width: 92%;
              margin: 0 auto;
              border-collapse: collapse;
            }
            .tbl th, .tbl td { border: 1px solid #333; }

            .th-mat {
              background: #D9E1F2; font-weight: bold;
              text-align: center; vertical-align: middle;
              font-size: 10px; padding: 2px 3px;
              width: 15%;
            }
            .th-group {
              background: #D9E1F2; font-weight: bold;
              text-align: center; font-size: 10px; padding: 2px;
            }
            .th-r {
              width: 4.5%; padding: 2px 1px;
              vertical-align: middle; text-align: center;
              background: #fff;
            }
            .th-grp-seg { background: #E8F4FD; }
            .th-grp-cie { background: #F0F7EC; }
            .rot {
              display: block;
              font-size: 8px;
              font-weight: bold;
              white-space: normal;
              word-break: break-word;
              line-height: 1.2;
            }

            .td-mat {
              text-align: left; font-weight: bold;
              font-size: 10px; padding: 3px 4px;
            }
            .td-c {
              text-align: center; font-size: 10px;
              padding: 2px 1px;
            }
            .td-tray { font-weight: bold; font-size: 9px; }
            .td-final { font-weight: bold; font-size: 10px; }
            .td-foot {
              background: #f2f2f2; font-weight: bold;
              font-size: 9.5px; padding: 2px 4px;
              text-align: left;
            }

            /* --- FIRMAS --- */
            .firmas {
              display: flex;
              justify-content: space-around;
              margin-top: 10px;
              text-align: center;
              font-size: 11px;
            }
            .firma { width: 26%; }
            .firma-linea {
              border-top: 1.5px solid #444;
              margin: 32px 0 4px;
            }

            /* --- LEYENDA --- */
            .leyenda {
              margin-top: 4px;
              border-top: 1px solid #ccc;
              padding-top: 2px;
              font-size: 8.5px;
              line-height: 1.4;
            }

            /* --- PIE INSTITUCIONAL --- */
            .pie-inst {
              margin-top: 3px;
              border-top: 1px solid #1565C0;
              padding-top: 2px;
              text-align: center;
              font-size: 8px;
              color: #444;
              line-height: 1.5;
            }
          </style>
          $contenidoTotal
        ''',
      );
    } catch (e) {
      _mostrarError('Error al generar boletín: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _imprimirPlanillaCalificaciones() {
    final String subjectName = _materias.firstWhere(
      (m) => m['materia_id'] == _selectedMateriaId,
      orElse: () => {'nombre_asignatura': 'Materia'},
    )['nombre_asignatura'];

    final headerCols = _actividades.map((a) {
      final rawTitulo = a['titulo'].toString();
      final clean = rawTitulo.replaceAll('[INFO] ', '').replaceAll('[INFO]', '').replaceAll('[TAREA] ', '').replaceAll('[TAREA]', '').trim();
      if (rawTitulo.startsWith('[INFO]')) {
        return '<th>$clean <br><small style="color:purple;">(Info/No suma)</small></th>';
      } else if (rawTitulo.startsWith('[TAREA]')) {
        return '<th>$clean <br><small style="color:green;">(Tarea Sí/No)</small></th>';
      }
      return '<th>$clean</th>';
    }).join('');

    final rowsHtml = _alumnos.map((alumno) {
      final cells = _actividades.map((act) {
        final double? grade = _grades[alumno.id]?[act['id']];
        if (grade == null) return '<td>-</td>';
        final rawTitulo = act['titulo'].toString();
        if (rawTitulo.startsWith('[TAREA]')) {
          if (grade >= 9.0) return '<td style="color:green; font-weight:bold;">SÍ</td>';
          if (grade <= 4.0) return '<td style="color:red; font-weight:bold;">NO</td>';
          return '<td style="color:orange; font-weight:bold;">REG.</td>';
        }
        return '<td>${grade.toStringAsFixed(1)}</td>';
      }).join('');

      final double? localRite = _calculateLocalRite(alumno.id);
      final riteState = localRite != null
          ? (localRite >= 7.0 ? 'badge-green' : 'badge-red')
          : '';

      return '''
        <tr>
          <td><strong>${alumno.nombre}</strong></td>
          $cells
          <td><span class="badge $riteState">${localRite != null ? localRite.toStringAsFixed(1) : "-"}</span></td>
        </tr>
      ''';
    }).join('');

    final tableHtml = '''
      <h2>Planilla de Calificaciones RITE: $subjectName</h2>
      <table>
        <thead>
          <tr>
            <th>Alumno</th>
            $headerCols
            <th>RITE Final</th>
          </tr>
        </thead>
        <tbody>
          $rowsHtml
        </tbody>
      </table>
    ''';

    PrintHelper.imprimirHTML(
      titulo: 'Planilla RITE - IA Baradero',
      htmlContentBody: tableHtml,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planilla RITE', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _isSaving ? null : _guardarTodasLasNotas,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Configurar Rúbrica', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: _abrirModalRubrica,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.category_outlined, size: 18),
                  label: const Text('Gestionar Grupos', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: _mostrarGestionCategorias,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: const Text('Generar Seguimiento', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: _generarNotaSeguimientoInforme,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Planilla Materia', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: _imprimirPlanillaCalificaciones,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.grade_outlined, size: 18),
                  label: const Text('Boletín Cualitativo', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _mostrarBoletinCualitativoGrid(),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Boletín General', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _mostrarDialogoImpresion(),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirModalNuevaNota,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Nota', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabecera: Selector de materia
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 550) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.menu_book_rounded, color: colorScheme.primary),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Materia Seleccionada:',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: _materias.isEmpty
                                      ? const Text('Sin materias asignadas')
                                      : DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedMateriaId,
                                            isExpanded: true,
                                            items: _materias.map((m) {
                                              return DropdownMenuItem<String>(
                                                value: m['materia_id'] as String,
                                                child: Text(m['nombre_asignatura'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              );
                                            }).toList(),
                                            onChanged: (val) async {
                                              if (val != null) {
                                                setState(() {
                                                  _selectedMateriaId = val;
                                                  _isLoading = true;
                                                });
                                                try {
                                                  await _cargarPlanillaMateria();
                                                } catch (e) {
                                                  _mostrarError('Error al cambiar de materia: $e');
                                                } finally {
                                                  setState(() => _isLoading = false);
                                                }
                                              }
                                            },
                                          ),
                                        ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Icon(Icons.menu_book_rounded, color: colorScheme.primary),
                              const SizedBox(width: 16),
                              const Text(
                                'Materia Seleccionada:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _materias.isEmpty
                                    ? const Text('Sin materias asignadas')
                                    : DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedMateriaId,
                                          isExpanded: true,
                                          items: _materias.map((m) {
                                            return DropdownMenuItem<String>(
                                              value: m['materia_id'] as String,
                                              child: Text(m['nombre_asignatura'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                                            );
                                          }).toList(),
                                          onChanged: (val) async {
                                            if (val != null) {
                                              setState(() {
                                                _selectedMateriaId = val;
                                                _isLoading = true;
                                              });
                                              try {
                                                await _cargarPlanillaMateria();
                                              } catch (e) {
                                                _mostrarError('Error al cambiar de materia: $e');
                                              } finally {
                                                setState(() => _isLoading = false);
                                              }
                                            }
                                          },
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Selector de modo de calificación ──────────────────────
                  if (_selectedMateriaId != null)
                    Row(
                      children: [
                        const Icon(Icons.calculate_outlined, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        const Text('Modo de calificación:',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(width: 12),
                        SegmentedButton<String>(
                          style: ButtonStyle(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          segments: const [
                            ButtonSegment(
                              value: 'GRUPOS',
                              label: Text('% por Grupo', style: TextStyle(fontSize: 12)),
                              icon: Icon(Icons.category_outlined, size: 15),
                            ),
                            ButtonSegment(
                              value: 'PORCENTAJE',
                              label: Text('% por Actividad', style: TextStyle(fontSize: 12)),
                              icon: Icon(Icons.percent, size: 15),
                            ),
                          ],
                          selected: {_modoCalificacion},
                          onSelectionChanged: (sel) async {
                            final nuevo = sel.first;
                            setState(() => _modoCalificacion = nuevo);
                            if (_selectedMateriaId != null) {
                              try {
                                await _supabaseService.guardarModoCalificacion(
                                    _selectedMateriaId!, nuevo);
                              } catch (_) {}
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _modoCalificacion == 'GRUPOS'
                              ? 'Promedio por grupo → ponderado por peso de categoría'
                              : 'Cada nota tiene su propio peso % al crearla',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // Leyenda de Categorías de Evaluación
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _categorias.map((cat) {
                      final color = _obtenerColorCategoria(cat['nombre']);
                      final peso = (cat['peso_porcentaje'] as num).toInt();
                      return Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                        avatar: CircleAvatar(
                          backgroundColor: Colors.white24,
                          child: Text(
                            '${peso}%',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        label: Text(
                          cat['nombre'],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        backgroundColor: color,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  
                  // Planilla Principal (Matriz)
                  Expanded(
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _actividades.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.assignment_late_rounded, size: 64, color: colorScheme.secondary.withAlpha(128)),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Sin notas registradas',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Cree una nueva nota desde el botón inferior para comenzar a calificar.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Scrollbar(
                              thickness: 8.0,
                              radius: const Radius.circular(8),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest.withAlpha(128)),
                                    columnSpacing: 6.0,
                                    horizontalMargin: 10.0,
                                    columns: [
                                      // Columna Alumno
                                      const DataColumn(
                                        label: Text('Alumno', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      // Columnas de Actividades creadas
                                      ..._actividades.map((act) {
                                        final catName = act['aca_categorias_nota']?['nombre'] ?? '';
                                        final catColor = _obtenerColorCategoria(catName);
                                        final rawTitulo = act['titulo'].toString();
                                        final esInfo = rawTitulo.startsWith('[INFO]');
                                        final esTarea = rawTitulo.startsWith('[TAREA]');
                                        final esConducta = rawTitulo.startsWith('[CONDUCTA]');
                                        final cleanTitulo = rawTitulo.replaceAll('[INFO] ', '').replaceAll('[INFO]', '').replaceAll('[TAREA] ', '').replaceAll('[TAREA]', '').replaceAll('[CONDUCTA] ', '').replaceAll('[CONDUCTA]', '').trim();

                                        Color headerColor = catColor;
                                        String subTexto = catName;
                                        if (esInfo) {
                                          headerColor = Colors.purple.shade700;
                                          subTexto = 'INFORME (No promedia)';
                                        } else if (esTarea) {
                                          headerColor = Colors.green.shade700;
                                          subTexto = 'TAREA (Evidencias 60%)';
                                        } else if (esConducta) {
                                          headerColor = Colors.amber.shade900;
                                          subTexto = 'CONDUCTA DIARIA (No promedia RITE)';
                                        }

                                        return DataColumn(
                                          label: SizedBox(
                                            width: 100,
                                            child: InkWell(
                                            onTap: () {
                                              final fStr = act['created_at'] != null ? act['created_at'].toString().split('T')[0] : (act['fecha']?.toString().split('T')[0] ?? 'Fecha actual');
                                              final regPor = act['registrado_por'] ?? Supabase.instance.client.auth.currentUser?.email ?? 'Docente / Administrador';
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  title: Row(
                                                    children: [
                                                      Icon(Icons.info_outline, color: headerColor),
                                                      const SizedBox(width: 8),
                                                      Expanded(child: Text(cleanTitulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                                    ],
                                                  ),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('📌 Categoría: $subTexto', style: const TextStyle(fontWeight: FontWeight.w600)),
                                                      const SizedBox(height: 8),
                                                      Text('👤 Registrado por: $regPor'),
                                                      const SizedBox(height: 4),
                                                      Text('📅 Fecha de Carga: $fStr'),
                                                    ],
                                                  ),
                                                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
                                                ),
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                              decoration: BoxDecoration(
                                                color: headerColor.withAlpha(30),
                                                border: Border.all(color: headerColor),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (esInfo) const Icon(Icons.info_outline, size: 14, color: Colors.purple),
                                                      if (esTarea) const Icon(Icons.check_box, size: 14, color: Colors.green),
                                                      if (esConducta) Icon(Icons.psychology_alt_outlined, size: 14, color: Colors.amber.shade900),
                                                      if (esInfo || esTarea || esConducta) const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          cleanTitulo,
                                                          style: TextStyle(fontWeight: FontWeight.bold, color: headerColor, fontSize: 11),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    subTexto,
                                                    style: TextStyle(fontSize: 10, color: headerColor.withAlpha(200)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          ), // SizedBox width:100
                                        );
                                      }),
                                      if (_actividades.any((act) => act['titulo'].toString().startsWith('[TAREA]')))
                                        DataColumn(
                                          label: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withAlpha(30),
                                              border: Border.all(color: Colors.green),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.analytics_outlined, size: 14, color: Colors.green),
                                                    SizedBox(width: 4),
                                                    Text('Prom. Tareas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                                  ],
                                                ),
                                                Text('Evidencias (60%)', style: TextStyle(fontSize: 10, color: Colors.green)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      // Columna RITE Final
                                      const DataColumn(
                                        label: Text('RITE Final', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                      ),
                                    ],
                                    rows: _alumnos.map((alumno) {
                                      // Re-calcular con las notas del mapa local para actualización inmediata en UI
                                      final localRite = _calculateLocalRite(alumno.id);

                                      return DataRow(
                                        cells: [
                                          // Nombre del alumno
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  alumno.nombre,
                                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                                ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(Icons.description_outlined, size: 16, color: Colors.blueGrey),
                                                  tooltip: 'Ver Boletín General de ${alumno.nombre}',
                                                  onPressed: () => _mostrarDialogoImpresion(alumnoEspecifico: alumno),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Celdas de Notas
                                          ..._actividades.map((act) {
                                            final key = '${alumno.id}_${act['id']}';
                                            final controller = _controllers[key];
                                            final focusNode = _focusNodes[key];
                                            final rawTitulo = act['titulo'].toString();
                                            final esTarea = rawTitulo.startsWith('[TAREA]');
                                            final double? notaActual = _grades[alumno.id]?[act['id']];
                                            
                                            if (esTarea) {
                                              Color chipColor = Colors.grey.shade200;
                                              Color textColor = Colors.black87;
                                              String chipText = '---';
                                              IconData? icon;

                                              if (notaActual != null) {
                                                if (notaActual >= 9.0) {
                                                  chipColor = Colors.green.shade100;
                                                  textColor = Colors.green.shade900;
                                                  chipText = 'SÍ';
                                                  icon = Icons.check_circle;
                                                } else if (notaActual <= 4.0) {
                                                  chipColor = Colors.red.shade100;
                                                  textColor = Colors.red.shade900;
                                                  chipText = 'NO';
                                                  icon = Icons.cancel;
                                                } else {
                                                  chipColor = Colors.orange.shade100;
                                                  textColor = Colors.orange.shade900;
                                                  chipText = 'REG.';
                                                  icon = Icons.remove_circle;
                                                }
                                              }

                                              return DataCell(
                                                PopupMenuButton<double?>(
                                                  tooltip: 'Seleccionar estado de la tarea',
                                                  onSelected: (val) {
                                                    if (val != null) {
                                                      _guardarNotaCelda(alumno.id, act['id'] as String, val.toString());
                                                    } else {
                                                      _guardarNotaCelda(alumno.id, act['id'] as String, '');
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    const PopupMenuItem(
                                                      value: 10.0,
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.check_circle, color: Colors.green),
                                                          SizedBox(width: 8),
                                                          Text('✅ SÍ - Hizo la tarea (10 pts)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 6.0,
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.remove_circle, color: Colors.orange),
                                                          SizedBox(width: 8),
                                                          Text('⚠️ REGULAR - Incompleta (6 pts)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 1.0,
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.cancel, color: Colors.red),
                                                          SizedBox(width: 8),
                                                          Text('❌ NO - No hizo la tarea (1 pt)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuDivider(),
                                                    const PopupMenuItem(
                                                      value: null,
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.delete_outline, color: Colors.grey),
                                                          SizedBox(width: 8),
                                                          Text('Sin calificar / Limpiar'),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  child: Container(
                                                    width: 75,
                                                    height: 36,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: chipColor,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: textColor.withAlpha(80)),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        if (icon != null) ...[
                                                          Icon(icon, size: 14, color: textColor),
                                                          const SizedBox(width: 4),
                                                        ],
                                                        Text(chipText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor)),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }

                                            return DataCell(
                                              SizedBox(
                                                width: 70,
                                                height: 40,
                                                child: TextField(
                                                  controller: controller,
                                                  focusNode: focusNode,
                                                  textInputAction: TextInputAction.next,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  textAlign: TextAlign.center,
                                                  decoration: InputDecoration(
                                                    contentPadding: EdgeInsets.zero,
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: BorderSide(color: colorScheme.outline),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                                                    ),
                                                  ),
                                                  onSubmitted: (val) {
                                                    _guardarNotaCelda(alumno.id, act['id'] as String, val);
                                                    final idx = _alumnos.indexOf(alumno);
                                                    if (idx != -1 && idx + 1 < _alumnos.length) {
                                                      final nextAlumno = _alumnos[idx + 1];
                                                      final nextKey = '${nextAlumno.id}_${act['id']}';
                                                      _focusNodes[nextKey]?.requestFocus();
                                                    }
                                                  },
                                                ),
                                              ),
                                            );
                                          }),
                                          if (_actividades.any((act) => act['titulo'].toString().startsWith('[TAREA]'))) ...[
                                            (() {
                                              final promTareas = _calcularPromedioTareas(alumno.id);
                                              return DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: promTareas != null ? Colors.green.shade50 : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: promTareas != null ? Colors.green.shade300 : Colors.grey.shade300),
                                                  ),
                                                  child: Text(
                                                    promTareas != null ? promTareas.toStringAsFixed(1) : '-',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: promTareas != null ? Colors.green.shade800 : Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            })(),
                                          ],
                                          // Celda RITE Final
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: localRite != null
                                                    ? (localRite >= 7.0 ? Colors.green.shade50 : Colors.red.shade50)
                                                    : Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: localRite != null
                                                      ? (localRite >= 7.0 ? Colors.green.shade300 : Colors.red.shade300)
                                                      : Colors.grey.shade300,
                                                ),
                                              ),
                                              child: Text(
                                                localRite != null ? localRite.toStringAsFixed(1) : '-',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: localRite != null
                                                      ? (localRite >= 7.0 ? Colors.green.shade800 : Colors.red.shade800)
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
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
                  ),
                ],
              ),
            ),
    );
  }

  double? _calculateLocalRite(String alumnoId) {
    final studentGrades = _grades[alumnoId] ?? {};
    if (studentGrades.isEmpty) return null;

    if (_modoCalificacion == 'PORCENTAJE') {
      // Modo A: cada actividad tiene su propio peso_porcentaje_actividad
      double totalPonderado = 0.0;
      double totalPeso = 0.0;
      double sumaSimple = 0.0;
      int countSimple = 0;

      for (final entry in studentGrades.entries) {
        final actId = entry.key;
        final nota = entry.value;
        if (nota == null) continue;
        final act = _actividades.firstWhere((a) => a['id'] == actId, orElse: () => <String, dynamic>{});
        if (act.isEmpty) continue;
        final rawTitulo = act['titulo']?.toString() ?? '';
        if (rawTitulo.startsWith('[INFO]') || rawTitulo.startsWith('[CONDUCTA]')) continue;
        final pesoAct = (act['peso_porcentaje_actividad'] as num?)?.toDouble();
        if (pesoAct != null && pesoAct > 0) {
          totalPonderado += nota * pesoAct;
          totalPeso += pesoAct;
        } else {
          sumaSimple += nota;
          countSimple++;
        }
      }

      if (totalPeso > 0) return totalPonderado / totalPeso;
      if (countSimple > 0) return sumaSimple / countSimple;
      return null;
    }

    // Modo B (default): promedio por categoría ponderado por el peso de la categoría
    final Map<String, List<double>> notasPorCategoria = {};
    for (final entry in studentGrades.entries) {
      final actId = entry.key;
      final nota = entry.value;
      if (nota == null) continue;
      final act = _actividades.firstWhere((a) => a['id'] == actId, orElse: () => <String, dynamic>{});
      if (act.isNotEmpty) {
        final rawTitulo = act['titulo']?.toString() ?? '';
        if (rawTitulo.startsWith('[INFO]') || rawTitulo.startsWith('[CONDUCTA]')) continue;
        final catId = act['categoria_id'];
        notasPorCategoria.putIfAbsent(catId, () => []).add(nota);
      }
    }

    if (notasPorCategoria.isEmpty) return null;

    double totalPonderado = 0.0;
    double totalPeso = 0.0;

    for (final cat in _categorias) {
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

  // ─── Helpers para boletín cualitativo ───────────────────────────────────

  /// Sugiere una apreciación cualitativa a partir del promedio RITE numérico.
  String? _sugerirApreciacion(double? promedio) {
    if (promedio == null) return null;
    if (promedio >= 9.0) return 'S';
    if (promedio >= 7.0) return 'MB';
    if (promedio >= 6.0) return 'B';
    return 'R';
  }

  /// Mezcla rubricas del servidor en el mapa de valores del grid.
  void _mergeRubricas(
    Map<String, Map<String, String?>> vals,
    List<Map<String, dynamic>> rubricas,
  ) {
    for (final alumno in _alumnos) {
      final r = rubricas.firstWhere(
        (r) => r['alumno_id'] == alumno.id,
        orElse: () => <String, dynamic>{},
      );
      if (r.isNotEmpty) {
        vals[alumno.id] ??= {};
        for (final c in _kCriterios) {
          vals[alumno.id]![c['key']!] = r[c['key']]?.toString();
        }
      }
    }
  }

  // ─── Widget: celda con botones S/MB/B/R ─────────────────────────────────

  Widget _buildCriterioCell({
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    const opciones = ['S', 'MB', 'B', 'R'];

    Color bgFor(String v) {
      if (v == 'S')  return const Color(0xFFD1FAE5);
      if (v == 'MB') return const Color(0xFFDBEAFE);
      if (v == 'B')  return const Color(0xFFFEF3C7);
      return const Color(0xFFFEE2E2);
    }
    Color fgFor(String v) {
      if (v == 'S')  return const Color(0xFF065F46);
      if (v == 'MB') return const Color(0xFF1E3A8A);
      if (v == 'B')  return const Color(0xFF92400E);
      return const Color(0xFF991B1B);
    }
    Color bdrFor(String v) {
      if (v == 'S')  return const Color(0xFF34D399);
      if (v == 'MB') return const Color(0xFF60A5FA);
      if (v == 'B')  return const Color(0xFFFBBF24);
      return const Color(0xFFF87171);
    }

    return SizedBox(
      width: 142,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: opciones.map((v) {
          final sel = value == v;
          return Padding(
            padding: const EdgeInsets.only(right: 3),
            child: InkWell(
              onTap: () => onChanged(sel ? null : v),
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? bgFor(v) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: sel ? bdrFor(v) : Colors.grey.shade300,
                    width: sel ? 1.5 : 1.0,
                  ),
                ),
                child: Text(
                  v,
                  style: TextStyle(
                    color: sel ? fgFor(v) : Colors.grey.shade500,
                    fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Chip de leyenda ─────────────────────────────────────────────────────

  Widget _legendChip(String label, String tooltip, Color bg, Color fg) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: fg.withOpacity(0.4)),
        ),
        child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    );
  }

  // ─── Modal: Boletín Cualitativo del Curso (grid completo) ────────────────

  Future<void> _mostrarBoletinCualitativoGrid() async {
    if (_selectedMateriaId == null) {
      _mostrarError('Seleccione una materia primero.');
      return;
    }
    if (_alumnos.isEmpty) {
      _mostrarError('No hay alumnos vinculados a esta materia.');
      return;
    }

    const etapas = ['1° SEGUIMIENTO', '1° CIERRE', '2° SEGUIMIENTO', '2° CIERRE'];
    String etapa = '1° SEGUIMIENTO';

    // Mapa de valores: alumnoId → criterioKey → 'S'/'MB'/'B'/'R'/null
    final Map<String, Map<String, String?>> vals = {};

    // Pre-llenar con sugerencias del RITE actual
    for (final a in _alumnos) {
      final sug = _sugerirApreciacion(_calculateLocalRite(a.id));
      vals[a.id] = { for (final c in _kCriterios) c['key']!: sug };
    }

    // Cargar rubricas ya guardadas para la etapa inicial
    try {
      final existing = await _supabaseService.obtenerRubricasCualitativasPorMateria(
        materiaId: _selectedMateriaId!,
        etapa: etapa,
      );
      _mergeRubricas(vals, existing);
    } catch (_) {}

    if (!mounted) return;

    final nombreMateria = _materias.firstWhere(
      (m) => m['materia_id'] == _selectedMateriaId,
      orElse: () => <String, dynamic>{'nombre_asignatura': 'Materia'},
    )['nombre_asignatura']?.toString() ?? 'Materia';

    bool isLoadingEtapa = false;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        return StatefulBuilder(builder: (ctx, setS) {
          // Recarga rubricas cuando el docente cambia de etapa
          Future<void> cambiarEtapa(String nueva) async {
            setS(() { etapa = nueva; isLoadingEtapa = true; });
            // Resetear a sugerencias RITE
            for (final a in _alumnos) {
              final sug = _sugerirApreciacion(_calculateLocalRite(a.id));
              vals[a.id] = { for (final c in _kCriterios) c['key']!: sug };
            }
            try {
              final existing = await _supabaseService.obtenerRubricasCualitativasPorMateria(
                materiaId: _selectedMateriaId!,
                etapa: nueva,
              );
              _mergeRubricas(vals, existing);
            } catch (_) {}
            if (ctx.mounted) setS(() => isLoadingEtapa = false);
          }

          return Dialog.fullscreen(
            child: Scaffold(
              backgroundColor: Colors.grey.shade50,
              appBar: AppBar(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(dlgCtx).pop(),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Boletín Cualitativo del Curso',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(nombreMateria,
                        style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  ],
                ),
                actions: [
                  // Selector de etapa
                  DropdownButton<String>(
                    value: etapa,
                    dropdownColor: const Color(0xFF334155),
                    iconEnabledColor: Colors.white,
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    items: etapas.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (isLoadingEtapa || isSaving) ? null : (v) {
                      if (v != null && v != etapa) cambiarEtapa(v);
                    },
                  ),
                  const SizedBox(width: 16),
                  // Botón guardar
                  FilledButton.icon(
                    icon: isSaving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Guardar Todo',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: (isSaving || isLoadingEtapa) ? null : () async {
                      setS(() => isSaving = true);
                      try {
                        final payload = _alumnos.map((a) {
                          final v = vals[a.id] ?? {};
                          return <String, dynamic>{
                            'alumno_id': a.id,
                            'materia_id': _selectedMateriaId!,
                            'etapa': etapa,
                            for (final c in _kCriterios) c['key']!: v[c['key']],
                          };
                        }).toList();
                        await _supabaseService.guardarRubricasCualitativas(payload);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('¡Boletín guardado para ${_alumnos.length} alumnos — Etapa: $etapa!'),
                            backgroundColor: Colors.green.shade800,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Error al guardar: $e'),
                            backgroundColor: Colors.red.shade800,
                          ));
                        }
                      } finally {
                        if (ctx.mounted) setS(() => isSaving = false);
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              body: Column(
                children: [
                  // ── Barra de leyenda ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFFF1F5F9),
                    child: Row(
                      children: [
                        const Text('Leyenda: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        _legendChip('S',  'Satisfactorio', const Color(0xFFD1FAE5), const Color(0xFF065F46)),
                        const SizedBox(width: 6),
                        _legendChip('MB', 'Muy Bueno',     const Color(0xFFDBEAFE), const Color(0xFF1E3A8A)),
                        const SizedBox(width: 6),
                        _legendChip('B',  'Bueno',         const Color(0xFFFEF3C7), const Color(0xFF92400E)),
                        const SizedBox(width: 6),
                        _legendChip('R',  'Regular',       const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
                        const SizedBox(width: 16),
                        Icon(Icons.auto_awesome, size: 14, color: Colors.purple.shade400),
                        const SizedBox(width: 4),
                        Text(
                          'Valores pre-sugeridos por el RITE actual del alumno (editables)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueGrey.shade200),
                          ),
                          child: Text(
                            '$etapa  •  ${_alumnos.length} alumnos',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Tabla ──
                  Expanded(
                    child: isLoadingEtapa
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
                                headingTextStyle: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                dataRowMinHeight: 54,
                                dataRowMaxHeight: 54,
                                columnSpacing: 6,
                                dividerThickness: 0.5,
                                columns: [
                                  const DataColumn(label: SizedBox(width: 175, child: Text('ALUMNO/A'))),
                                  const DataColumn(
                                    label: SizedBox(
                                      width: 55,
                                      child: Text('RITE\nActual', textAlign: TextAlign.center),
                                    ),
                                  ),
                                  for (final c in _kCriterios)
                                    DataColumn(
                                      label: SizedBox(
                                        width: 142,
                                        child: Text(c['label']!,
                                            style: const TextStyle(fontSize: 10),
                                            textAlign: TextAlign.center),
                                      ),
                                    ),
                                ],
                                rows: List.generate(_alumnos.length, (idx) {
                                  final alumno = _alumnos[idx];
                                  final localRite = _calculateLocalRite(alumno.id);
                                  final isAprobado = localRite != null && localRite >= 7.0;
                                  final v = vals[alumno.id] ?? {};

                                  return DataRow(
                                    color: WidgetStateProperty.all(
                                        idx.isEven ? Colors.white : const Color(0xFFF8FAFC)),
                                    cells: [
                                      // Nombre
                                      DataCell(SizedBox(
                                        width: 175,
                                        child: Text(alumno.nombre,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                            overflow: TextOverflow.ellipsis),
                                      )),
                                      // RITE actual
                                      DataCell(Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: localRite != null
                                                ? (isAprobado ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2))
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            localRite?.toStringAsFixed(1) ?? '—',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: localRite != null
                                                  ? (isAprobado ? const Color(0xFF166534) : const Color(0xFF991B1B))
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      )),
                                      // 7 criterios
                                      for (final c in _kCriterios)
                                        DataCell(_buildCriterioCell(
                                          value: v[c['key']],
                                          onChanged: (newVal) {
                                            setS(() {
                                              vals[alumno.id] ??= {};
                                              vals[alumno.id]![c['key']!] = newVal;
                                            });
                                          },
                                        )),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ─── Modal: Gestión de grupos de calificación ─────────────────────────────

  Future<void> _mostrarGestionCategorias() async {
    if (_selectedMateriaId == null) {
      _mostrarError('Seleccione una materia primero.');
      return;
    }

    // Estado mutable fuera del builder para sobrevivir a setS
    final categoriasLocales = List<Map<String, dynamic>>.from(_categorias);
    final nombreCtrl = TextEditingController();
    final pesoCtrl = TextEditingController();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(builder: (ctx, setS) {
          final double totalPeso = categoriasLocales.fold(
            0.0, (s, c) => s + (c['peso_porcentaje'] as num).toDouble());
          final bool totalOk = (totalPeso - 100.0).abs() < 0.01;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            title: Row(children: [
              const Icon(Icons.category_outlined, color: Colors.blueGrey),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Grupos de Calificación',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              // Modo actual como chip informativo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _modoCalificacion == 'GRUPOS' ? Colors.green.shade50 : Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _modoCalificacion == 'GRUPOS' ? Colors.green.shade300 : Colors.purple.shade300,
                  ),
                ),
                child: Text(
                  _modoCalificacion == 'GRUPOS' ? 'Modo: Grupos' : 'Modo: % por Actividad',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold,
                    color: _modoCalificacion == 'GRUPOS' ? Colors.green.shade800 : Colors.purple.shade800,
                  ),
                ),
              ),
            ]),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    // Barra de total
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (totalPeso / 100).clamp(0.0, 1.2),
                        minHeight: 7,
                        backgroundColor: Colors.grey.shade200,
                        color: totalOk ? Colors.green : (totalPeso > 100 ? Colors.red : Colors.orange),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: ${totalPeso.toStringAsFixed(0)}%  ${totalOk ? "✓ Correcto" : "— debe sumar 100%"}',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: totalOk ? Colors.green.shade800 : Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Lista de categorías
                    ...categoriasLocales.map((cat) {
                      final esPropia = cat['materia_id'] != null;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                esPropia ? Colors.green.shade50 : Colors.blue.shade50,
                            child: Text(
                              '${(cat['peso_porcentaje'] as num).toInt()}%',
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold,
                                color: esPropia ? Colors.green.shade800 : Colors.blue.shade800,
                              ),
                            ),
                          ),
                          title: Text(cat['nombre'].toString(),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text(esPropia ? 'Grupo propio' : 'Grupo global compartido',
                              style: const TextStyle(fontSize: 10)),
                          trailing: esPropia
                              ? IconButton(
                                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                                  tooltip: 'Eliminar grupo',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: ctx,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Eliminar grupo'),
                                        content: Text(
                                          '¿Eliminar "${cat['nombre']}"?\n'
                                          'Las actividades en este grupo quedarán sin categoría.',
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                          TextButton(
                                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                                            onPressed: () => Navigator.pop(c, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        await _supabaseService.eliminarCategoriaMateria(cat['id'] as String);
                                        setState(() => _categorias.removeWhere((c) => c['id'] == cat['id']));
                                        setS(() => categoriasLocales.removeWhere((c) => c['id'] == cat['id']));
                                      } catch (e) {
                                        if (ctx.mounted) _mostrarError('Error: $e');
                                      }
                                    }
                                  },
                                )
                              : null,
                        ),
                      );
                    }),
                    const Divider(height: 20),
                    // Formulario para agregar nuevo grupo
                    const Text('Agregar nuevo grupo:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: nombreCtrl,
                            decoration: InputDecoration(
                              labelText: 'Nombre',
                              hintText: 'Ej: Evaluaciones Escritas',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: pesoCtrl,
                            decoration: InputDecoration(
                              labelText: 'Peso %',
                              hintText: '30',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final nombre = nombreCtrl.text.trim();
                                  final peso = double.tryParse(pesoCtrl.text.replaceAll(',', '.').trim());
                                  if (nombre.isEmpty || peso == null || peso <= 0 || peso > 100) {
                                    _mostrarError('Ingrese un nombre y un peso entre 1 y 100.');
                                    return;
                                  }
                                  setS(() => isSaving = true);
                                  try {
                                    final nuevo = await _supabaseService.crearCategoriaMateria(
                                      materiaId: _selectedMateriaId!,
                                      nombre: nombre,
                                      pesoPorc: peso,
                                    );
                                    setState(() => _categorias.add(nuevo));
                                    setS(() {
                                      categoriasLocales.add(nuevo);
                                      nombreCtrl.clear();
                                      pesoCtrl.clear();
                                      isSaving = false;
                                    });
                                  } catch (e) {
                                    if (ctx.mounted) _mostrarError('Error: $e');
                                    if (ctx.mounted) setS(() => isSaving = false);
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Agregar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dlgCtx).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        });
      },
    );

    nombreCtrl.dispose();
    pesoCtrl.dispose();
  }
}
