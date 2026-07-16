import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/alumno_asistencia.dart';
import '../services/print_helper.dart';

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

      // 2. Cargar categorías fijas
      _categorias = await _supabaseService.obtenerCategoriasCalificaciones();

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
                          labelText: 'Categoría de Nota',
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
                          setModalState(() {
                            selectedCategoriaId = val;
                          });
                        },
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

  Future<void> _imprimirBoletinGeneralCurso({AlumnoAsistencia? alumnoEspecifico}) async {
    setState(() => _isLoading = true);
    try {
      String? cursoId = widget.cursoId;
      if (_materias.isNotEmpty && _selectedMateriaId != null) {
        final mat = _materias.firstWhere((m) => m['materia_id'] == _selectedMateriaId, orElse: () => <String, dynamic>{});
        if (mat.isNotEmpty && mat['curso_id'] != null) {
          cursoId = mat['curso_id'].toString();
        }
      }

      final datos = await _supabaseService.obtenerDatosBoletinCompleto(
        cursoId: cursoId,
        alumnosIds: alumnoEspecifico != null ? [alumnoEspecifico.id] : _alumnos.map((a) => a.id).toList(),
      );

      final List<Map<String, dynamic>> materiasCurso = List<Map<String, dynamic>>.from(datos['materias'] ?? []);
      final List<Map<String, dynamic>> actividades = List<Map<String, dynamic>>.from(datos['actividades'] ?? []);
      final List<Map<String, dynamic>> calificaciones = List<Map<String, dynamic>>.from(datos['calificaciones'] ?? []);
      final List<Map<String, dynamic>> categorias = List<Map<String, dynamic>>.from(datos['categorias'] ?? []);

      if (materiasCurso.isEmpty) {
        _mostrarError('No se encontraron materias para este curso.');
        return;
      }

      final alumnosAPrint = alumnoEspecifico != null ? [alumnoEspecifico] : _alumnos;

      final List<String> boletinesHtml = [];

      for (final alumno in alumnosAPrint) {
        final List<String> filasMaterias = [];
        for (final mat in materiasCurso) {
          final matId = mat['materia_id'] as String;
          final nombreMat = mat['nombre_asignatura']?.toString() ?? 'Materia';

          final actsMat = actividades.where((a) => a['materia_id'] == matId).toList();
          final catsMat = categorias.where((c) => c['materia_id'] == matId).toList();

          // Informe de Seguimiento Docente
          final infoActs = actsMat.where((a) => a['titulo'].toString().startsWith('[INFO]')).toList();
          String textoSeguimiento = 'En proceso';
          if (infoActs.isNotEmpty) {
            final califInfo = calificaciones.firstWhere(
              (c) => c['actividad_id'] == infoActs.first['id'] && c['alumno_id'] == alumno.id && c['nota_numerica'] != null,
              orElse: () => <String, dynamic>{},
            );
            if (califInfo.isNotEmpty && califInfo['nota_numerica'] != null) {
              final val = (califInfo['nota_numerica'] as num).toDouble();
              textoSeguimiento = 'Promedio Seguimiento: ${val.toStringAsFixed(1)}';
            } else {
              textoSeguimiento = 'Sin observaciones registradas';
            }
          }

          // Nota de Conducta Diaria
          final conductaActs = actsMat.where((a) => a['titulo'].toString().startsWith('[CONDUCTA]')).toList();
          String textoConducta = '-';
          if (conductaActs.isNotEmpty) {
            final califConducta = calificaciones.firstWhere(
              (c) => c['actividad_id'] == conductaActs.first['id'] && c['alumno_id'] == alumno.id && c['nota_numerica'] != null,
              orElse: () => <String, dynamic>{},
            );
            if (califConducta.isNotEmpty && califConducta['nota_numerica'] != null) {
              final val = (califConducta['nota_numerica'] as num).toDouble();
              textoConducta = val.toStringAsFixed(1);
            } else {
              textoConducta = 'En proc.';
            }
          }

          final double? promedioRite = _supabaseService.calcularPromedioRite(
            actividades: actsMat,
            calificaciones: calificaciones,
            categorias: catsMat,
            alumnoId: alumno.id,
          );

          String condicionRite = 'En Proceso';
          String badgeClass = 'badge-grey';
          if (promedioRite != null) {
            if (promedioRite >= 7.0) {
              condicionRite = 'TEA (Aprobado)';
              badgeClass = 'badge-green';
            } else if (promedioRite >= 4.0) {
              condicionRite = 'TEP (En Proceso)';
              badgeClass = 'badge-orange';
            } else {
              condicionRite = 'TED (Discontinuo)';
              badgeClass = 'badge-red';
            }
          }

          filasMaterias.add('''
            <tr>
              <td style="font-weight:bold; text-align:left;">$nombreMat</td>
              <td><span class="badge $badgeClass">${promedioRite != null ? promedioRite.toStringAsFixed(1) : "-"}</span></td>
              <td style="font-weight:bold;">$condicionRite</td>
              <td style="font-weight:bold; color:#b76e00;">$textoConducta</td>
              <td style="text-align:left; font-style:italic; color:#444;">$textoSeguimiento</td>
            </tr>
          ''');
        }

        final tablaMateriaHtml = filasMaterias.join('');

        boletinesHtml.add('''
          <div style="padding: 25px; border: 2px solid #333; border-radius: 8px; margin-bottom: 40px; page-break-after: always; background: #fff;">
            <div style="text-align: center; border-bottom: 2px solid #333; padding-bottom: 15px; margin-bottom: 20px;">
              <h1 style="margin: 0; font-size: 24px; text-transform: uppercase; letter-spacing: 1px;">Instituto Alejandro Baradero</h1>
              <h2 style="margin: 5px 0 0 0; font-size: 18px; color: #444;">Boletín Oficial de Calificaciones, Conducta y Seguimiento</h2>
            </div>

            <div style="display: flex; justify-content: space-between; margin-bottom: 20px; font-size: 15px;">
              <div><strong>Alumno/a:</strong> ${alumno.nombre}</div>
              <div><strong>Fecha de Emisión:</strong> ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}</div>
            </div>

            <table style="width: 100%; border-collapse: collapse; margin-bottom: 30px;">
              <thead>
                <tr style="background-color: #f2f2f2;">
                  <th style="padding: 10px; border: 1px solid #ccc; text-align: left; width: 26%;">Asignatura / Materia</th>
                  <th style="padding: 10px; border: 1px solid #ccc; text-align: center; width: 14%;">Nota RITE Final</th>
                  <th style="padding: 10px; border: 1px solid #ccc; text-align: center; width: 20%;">Condición RITE</th>
                  <th style="padding: 10px; border: 1px solid #ccc; text-align: center; width: 14%;">Conducta Diaria</th>
                  <th style="padding: 10px; border: 1px solid #ccc; text-align: left; width: 26%;">Informe / Seguimiento</th>
                </tr>
              </thead>
              <tbody>
                $tablaMateriaHtml
              </tbody>
            </table>

            <div style="margin-top: 60px; display: flex; justify-content: space-around; text-align: center;">
              <div style="width: 28%; border-top: 1px solid #333; padding-top: 8px;"><strong>Firma Dirección</strong></div>
              <div style="width: 28%; border-top: 1px solid #333; padding-top: 8px;"><strong>Firma Docente / Preceptor</strong></div>
              <div style="width: 28%; border-top: 1px solid #333; padding-top: 8px;"><strong>Firma Madre / Padre / Tutor</strong></div>
            </div>
          </div>
        ''');
      }

      final contenidoTotal = boletinesHtml.join('');

      PrintHelper.imprimirHTML(
        titulo: alumnoEspecifico != null ? 'Boletín - ${alumnoEspecifico.nombre}' : 'Boletines de Curso - IA Baradero',
        htmlContentBody: '''
          <style>
            .badge-green { background-color: #d4edda; color: #155724; padding: 4px 8px; border-radius: 4px; font-weight: bold; }
            .badge-orange { background-color: #fff3cd; color: #856404; padding: 4px 8px; border-radius: 4px; font-weight: bold; }
            .badge-red { background-color: #f8d7da; color: #721c24; padding: 4px 8px; border-radius: 4px; font-weight: bold; }
            .badge-grey { background-color: #e2e3e5; color: #383d41; padding: 4px 8px; border-radius: 4px; font-weight: bold; }
            table td { padding: 10px; border: 1px solid #ddd; text-align: center; font-size: 14px; }
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
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Boletín General', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _imprimirBoletinGeneralCurso(),
          ),
          const SizedBox(width: 12),
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
                      child: Row(
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
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Leyenda de Categorías de Evaluación
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _categorias.map((cat) {
                      final color = _obtenerColorCategoria(cat['nombre']);
                      final peso = (cat['peso_porcentaje'] as num).toInt();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Chip(
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
                        ),
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
                                    columnSpacing: 24.0,
                                    horizontalMargin: 16.0,
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
                                          label: InkWell(
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
                                                      Text(
                                                        cleanTitulo,
                                                        style: TextStyle(fontWeight: FontWeight.bold, color: headerColor),
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
                                                  onPressed: () => _imprimirBoletinGeneralCurso(alumnoEspecifico: alumno),
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

    final Map<String, List<double>> notasPorCategoria = {};
    for (final entry in studentGrades.entries) {
      final actId = entry.key;
      final nota = entry.value;
      if (nota == null) continue;

      final act = _actividades.firstWhere((a) => a['id'] == actId, orElse: () => {});
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
}
