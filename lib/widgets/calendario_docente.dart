import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Calendario unificado para docentes.
/// Carga eventos de TODOS los cursos asignados al docente y los muestra juntos.
/// Permite agregar eventos por curso desde esta misma vista.
class CalendarioDocente extends StatefulWidget {
  /// Si se pasa un cursoId y materiaId, el formulario de nuevo evento
  /// pre-selecciona ese curso (usado desde PanelGestionMateria).
  final String? cursoIdInicial;
  final String? materiaIdInicial;
  final String? cursNombreInicial;

  /// Día a mostrar seleccionado al abrir (para saltar directo a un evento).
  final DateTime? fechaInicial;

  const CalendarioDocente({
    super.key,
    this.cursoIdInicial,
    this.materiaIdInicial,
    this.cursNombreInicial,
    this.fechaInicial,
  });

  @override
  State<CalendarioDocente> createState() => _CalendarioDocenteState();
}

/// Ámbito de eventos que se muestran cuando el calendario se abre desde una materia.
enum _FiltroCal { estaMateria, esteCurso, todas }

/// Filtro por tipo de evento (para admin/preceptor y también útil al docente).
enum _TipoFiltro { todos, evaluaciones, actividades, actos, reuniones }

class _CalendarioDocenteState extends State<CalendarioDocente> {
  final _service = SupabaseService();

  DateTime _mesActual = DateTime.now();
  DateTime? _diaSeleccionado;

  // Mapa: claveYYYY-MM-DD → lista de eventos de Supabase
  Map<String, List<Map<String, dynamic>>> _eventosPorDia = {};
  // Todos los eventos únicos ya cargados, sin filtrar por ámbito.
  List<Map<String, dynamic>> _eventosCrudos = [];

  // Lista de cursos del docente (para el selector al agregar evento)
  List<Map<String, dynamic>> _cursos = [];
  bool _cargando = true;

  /// Sólo se ofrece el selector de ámbito cuando se entró desde una materia.
  bool get _desdeMateria => widget.cursoIdInicial != null;
  late _FiltroCal _filtro = !_desdeMateria
      ? _FiltroCal.todas
      : (widget.materiaIdInicial != null
          ? _FiltroCal.estaMateria
          : _FiltroCal.esteCurso);

  _TipoFiltro _tipoFiltro = _TipoFiltro.todos;

  String get _rol =>
      Supabase.instance.client.auth.currentUser?.userMetadata?['rol'] as String? ??
      'DOCENTE';
  bool get _esAdmin => _rol == 'ADMIN' || _rol == 'PRECEPTOR';

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static const _diasSemana = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];

  @override
  void initState() {
    super.initState();
    if (widget.fechaInicial != null) {
      _mesActual = DateTime(widget.fechaInicial!.year, widget.fechaInicial!.month);
      _diaSeleccionado = widget.fechaInicial;
    }
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    try {
      // 1. Cursos para el selector de "nuevo evento".
      //    Admin/preceptor: todos los cursos. Docente: sólo los que dicta.
      if (_esAdmin) {
        final cursos = await _service.fetchCursos();
        _cursos = cursos
            .map((c) => {'curso_id': c['curso_id'], 'nombre': c['identificador_division']})
            .toList();
      } else {
        try {
          final docenteId = await _service.obtenerDocenteIdActual();
          final materias = await _service.fetchMateriasPorDocente(docenteId);
          final cursosMap = <String, Map<String, dynamic>>{};
          for (final m in materias) {
            final cId = m['curso_id'] as String;
            cursosMap[cId] = {'curso_id': cId, 'nombre': m['identificador_division']};
          }
          _cursos = cursosMap.values.toList();
        } catch (_) {
          _cursos = [];
        }
      }

      final Map<String, Map<String, dynamic>> eventosUnicos = {};
      void registrar(Map<String, dynamic> e, String nombreCurso) {
        final id = (e['evento_id'] ?? e['id'])?.toString();
        final clave = id ?? '${e['fecha']}|${e['titulo']}|${e['curso_id']}';
        if (eventosUnicos.containsKey(clave)) return;
        eventosUnicos[clave] = {...e, '_curso_nombre': nombreCurso};
      }

      String nombreDeCurso(String? cursoId) {
        if (cursoId == null || cursoId.isEmpty) return 'General';
        final c = _cursos.firstWhere(
          (x) => x['curso_id'] == cursoId,
          orElse: () => const {},
        );
        return c['nombre']?.toString() ?? 'Curso';
      }

      if (_esAdmin) {
        // Admin/preceptor ve TODOS los eventos de la escuela.
        final todos = await _service.obtenerTodosLosEventosCalendario();
        for (final e in todos) {
          registrar(e, nombreDeCurso(e['curso_id']?.toString()));
        }
      } else {
        // Docente: eventos de sus cursos + los generales (curso_id null).
        // obtenerCalendarioPorCurso() ya incluye los generales, así que se
        // deduplica por id.
        for (final curso in _cursos) {
          final cursoId = curso['curso_id'] as String;
          final eventos =
              await _service.obtenerCalendarioPorCurso(cursoId, soloPublicos: false);
          for (final e in eventos) {
            registrar(e, e['curso_id'] == null ? 'General' : nombreDeCurso(cursoId));
          }
        }
        final generales =
            await _service.obtenerCalendarioPorCurso(null, soloPublicos: false);
        for (final e in generales) {
          registrar(e, 'General');
        }
      }

      _eventosCrudos = eventosUnicos.values.toList();

      if (mounted) {
        setState(() {
          _recomputarEventos();
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando calendario: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Rearma el mapa por día desde los eventos crudos aplicando el ámbito activo.
  /// Se llama al cargar y cada vez que se cambia el selector de ámbito.
  void _recomputarEventos() {
    final Map<String, List<Map<String, dynamic>>> nuevos = {};
    for (final e in _eventosCrudos) {
      if (!_pasaFiltro(e)) continue;
      final fecha = (e['fecha'] as String).substring(0, 10);
      nuevos.putIfAbsent(fecha, () => []).add(e);
    }
    _eventosPorDia = nuevos;
  }

  String _labelFiltroTipo(_TipoFiltro f) {
    switch (f) {
      case _TipoFiltro.todos:
        return 'Todos';
      case _TipoFiltro.evaluaciones:
        return 'Evaluaciones';
      case _TipoFiltro.actividades:
        return 'Actividades';
      case _TipoFiltro.actos:
        return 'Actos';
      case _TipoFiltro.reuniones:
        return 'Reuniones';
    }
  }

  /// ¿El evento pasa el filtro por tipo (Todos / Evaluaciones / …)?
  bool _pasaTipo(Map<String, dynamic> e) {
    final tipo = (e['tipo_evento'] ?? '').toString().toUpperCase();
    final esActo = (e['titulo'] ?? '').toString().toLowerCase().contains('acto');
    switch (_tipoFiltro) {
      case _TipoFiltro.todos:
        return true;
      case _TipoFiltro.evaluaciones:
        return tipo == 'EVALUACION';
      case _TipoFiltro.actividades:
        return tipo == 'ACTIVIDAD' && !esActo;
      case _TipoFiltro.actos:
        return esActo;
      case _TipoFiltro.reuniones:
        return tipo == 'REUNION';
    }
  }

  /// ¿El evento entra en el ámbito + tipo elegidos?
  bool _pasaFiltro(Map<String, dynamic> e) {
    // El Libro de Temas tiene su propia vista; acá nunca se muestran.
    if ((e['tipo_evento'] ?? '').toString().toUpperCase() == 'TEMARIO') return false;
    if (!_pasaTipo(e)) return false;
    if (_filtro == _FiltroCal.todas) return true;
    final cursoEv = e['curso_id']?.toString();
    final materiaEv = e['materia_id']?.toString();
    final tipo = (e['tipo_evento'] ?? '').toString().toUpperCase();
    if (_filtro == _FiltroCal.esteCurso) {
      return cursoEv == null || cursoEv.isEmpty || cursoEv == widget.cursoIdInicial;
    }
    // estaMateria: eventos de la materia + los del curso sin materia (no TEMARIO)
    if (materiaEv != null && materiaEv.isNotEmpty) {
      return materiaEv == widget.materiaIdInicial;
    }
    if (tipo == 'TEMARIO') return false;
    return cursoEv == null || cursoEv.isEmpty || cursoEv == widget.cursoIdInicial;
  }

  String _clave(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _eventosDelDia(DateTime d) =>
      _eventosPorDia[_clave(d)] ?? [];

  Color _colorTipo(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'EVALUACION':
        return Colors.purple;
      case 'ACTIVIDAD':
        return Colors.blue;
      case 'REUNION':
        return Colors.green;
      default:
        return Colors.teal;
    }
  }

  IconData _iconTipo(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'EVALUACION':
        return Icons.quiz_rounded;
      case 'ACTIVIDAD':
        return Icons.assignment_rounded;
      case 'REUNION':
        return Icons.people_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  String _labelTipo(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'EVALUACION':
        return 'Evaluación';
      case 'ACTIVIDAD':
        return 'Actividad';
      case 'REUNION':
        return 'Reunión';
      default:
        return tipo;
    }
  }

  /// curso_id de los cursos que dicta quien está mirando.
  Iterable<String> get _cursosDelDocente =>
      _cursos.map((c) => c['curso_id'].toString());

  /// ¿Este evento lo puede tocar el usuario actual?
  bool _puedeEditar(Map<String, dynamic> evento) =>
      _service.puedeEditarEvento(evento, cursosDelDocente: _cursosDelDocente);

  Future<void> _confirmarEliminarEvento(Map<String, dynamic> evento) async {
    final titulo = (evento['titulo'] ?? 'este evento').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar evento'),
        content: Text('¿Eliminar "$titulo" del calendario?\n\n'
            'Las familias dejan de verlo en su cronograma.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _service.eliminarEventoCalendario(
          (evento['evento_id'] ?? evento['id']).toString());
      await _cargarTodo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se eliminó "$titulo"'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Alta de un evento, o edición si se pasa [evento].
  void _abrirFormNuevoEvento(DateTime fecha, {Map<String, dynamic>? evento}) {
    final editando = evento != null;

    String limpiarInterno(String v) =>
        v.replaceFirst('[INTERNO] ', '').replaceFirst('[INTERNO]', '').trim();

    String tipoSeleccionado = editando
        ? (evento['tipo_evento'] ?? 'EVALUACION').toString().toUpperCase()
        : 'EVALUACION';
    String? cursoSeleccionadoId = editando
        ? evento['curso_id']?.toString()
        : (widget.cursoIdInicial ??
            (_cursos.isNotEmpty ? _cursos.first['curso_id'] as String : null));
    final tituloCtrl = TextEditingController(
        text: editando ? limpiarInterno((evento['titulo'] ?? '').toString()) : '');
    final descCtrl = TextEditingController(
        text: editando ? limpiarInterno((evento['descripcion'] ?? '').toString()) : '');
    bool guardando = false;
    bool esInterno = editando &&
        (evento['titulo'] ?? '').toString().startsWith('[INTERNO]');
    bool notificarPadres = false;
    bool notificarDocentes = false;
    DateTime fechaSel = fecha;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      editando ? 'Editar evento' : 'Nuevo evento',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event_rounded, size: 16),
                      label: Text(
                        '${fechaSel.day.toString().padLeft(2, '0')}/'
                        '${fechaSel.month.toString().padLeft(2, '0')}/${fechaSel.year}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: fechaSel,
                          firstDate: DateTime(fechaSel.year - 1),
                          lastDate: DateTime(fechaSel.year + 2),
                        );
                        if (picked != null) setS(() => fechaSel = picked);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Visibilidad / Público
                SwitchListTile(
                  title: const Text('Exclusivo Personal (Interno)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                  subtitle: const Text('Si se activa, no aparecerá en el portal de padres ni alumnos', style: TextStyle(fontSize: 11)),
                  value: esInterno,
                  activeColor: Colors.indigo,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setS(() => esInterno = val),
                ),
                const Divider(height: 16),
                // ── Notificaciones ────────────────────────────────────
                const Text('Notificar a', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Padres / Tutores', style: TextStyle(fontSize: 12)),
                        value: notificarPadres,
                        activeColor: Colors.teal,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: esInterno ? null : (val) => setS(() => notificarPadres = val),
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Docentes', style: TextStyle(fontSize: 12)),
                        value: notificarDocentes,
                        activeColor: Colors.deepPurple,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (val) => setS(() => notificarDocentes = val),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Selector de tipo
                const Text('Tipo de evento',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _tipoBtn(ctx, setS, tipoSeleccionado, 'EVALUACION',
                        'Evaluación', Icons.quiz_rounded, Colors.purple,
                        onSel: (t) => tipoSeleccionado = t),
                    const SizedBox(width: 8),
                    _tipoBtn(ctx, setS, tipoSeleccionado, 'ACTIVIDAD',
                        'Actividad', Icons.assignment_rounded, Colors.blue,
                        onSel: (t) => tipoSeleccionado = t),
                    const SizedBox(width: 8),
                    _tipoBtn(ctx, setS, tipoSeleccionado, 'REUNION',
                        'Reunión', Icons.people_rounded, Colors.green,
                        onSel: (t) => tipoSeleccionado = t),
                  ],
                ),
                const SizedBox(height: 16),

                // Selector de curso
                if (_cursos.isNotEmpty && !editando) ...[
                  const Text('Curso',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: cursoSeleccionadoId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('General (todos los cursos)')),
                      ..._cursos.map((c) => DropdownMenuItem(
                            value: c['curso_id'] as String,
                            child: Text(c['nombre'] as String),
                          )),
                    ],
                    onChanged: (v) => setS(() => cursoSeleccionadoId = v),
                  ),
                  const SizedBox(height: 16),
                ],

                // Título
                TextField(
                  controller: tituloCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título del evento',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                // Descripción
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: guardando
                        ? null
                        : () async {
                            if (tituloCtrl.text.trim().isEmpty) return;
                            setS(() => guardando = true);
                            try {
                              if (editando) {
                                final t = tituloCtrl.text.trim();
                                final d = descCtrl.text.trim();
                                await _service.actualizarEventoCalendario(
                                  eventoId: (evento['evento_id'] ?? evento['id']).toString(),
                                  titulo: esInterno ? '[INTERNO] $t' : t,
                                  descripcion: esInterno ? '[INTERNO] $d' : d,
                                  fecha: _clave(fechaSel),
                                  tipoEvento: tipoSeleccionado,
                                );
                              } else {
                                await _service.crearEventoCalendario(
                                  titulo: tituloCtrl.text.trim(),
                                  descripcion: descCtrl.text.trim(),
                                  fecha: _clave(fechaSel),
                                  tipoEvento: tipoSeleccionado,
                                  cursoId: cursoSeleccionadoId,
                                  materiaId: _filtro == _FiltroCal.estaMateria
                                      ? widget.materiaIdInicial
                                      : null,
                                  esInterno: esInterno,
                                  notificarPadres: notificarPadres,
                                  notificarDocentes: notificarDocentes,
                                );
                              }
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              await _cargarTodo();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(editando
                                        ? '✅ "${tituloCtrl.text.trim()}" actualizado'
                                        : '✅ "${tituloCtrl.text.trim()}" agregado al calendario'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            } catch (e) {
                              setS(() => guardando = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                    icon: guardando
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(editando ? Icons.save_rounded : Icons.add_rounded),
                    label: Text(editando ? 'Guardar cambios' : 'Guardar evento'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tipoBtn(
    BuildContext ctx,
    StateSetter setS,
    String tipoActual,
    String valor,
    String label,
    IconData icon,
    Color color, {
    required Function(String) onSel,
  }) {
    final sel = tipoActual == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setS(() => onSel(valor)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color : color.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? color : color.withAlpha(60)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: sel ? Colors.white : color),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: sel ? Colors.white : color)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hoy = DateTime.now();
    final primerDia = DateTime(_mesActual.year, _mesActual.month, 1);
    final diasEnMes = DateTime(_mesActual.year, _mesActual.month + 1, 0).day;
    final offsetInicio = primerDia.weekday - 1;

    final user = Supabase.instance.client.auth.currentUser;
    final rol = user?.userMetadata?['rol'] as String? ?? 'DOCENTE';
    final puedeAgregar = rol == 'ADMIN' || rol == 'PRECEPTOR';

    final calendarContent = Column(
      children: [
        // ── Navegación de mes ────────────────────────────────────────
        Container(
          color: colorScheme.primaryContainer.withAlpha(60),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() {
                  _mesActual =
                      DateTime(_mesActual.year, _mesActual.month - 1);
                }),
              ),
              Expanded(
                child: Text(
                  '${_meses[_mesActual.month - 1]} ${_mesActual.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => setState(() {
                  _mesActual =
                      DateTime(_mesActual.year, _mesActual.month + 1);
                }),
              ),
              // Botón agregar evento (Admin/Preceptor). Si no hay día
              // seleccionado, el formulario arranca en el día de hoy.
              if (puedeAgregar)
                FilledButton.icon(
                  onPressed: () => _abrirFormNuevoEvento(
                      _diaSeleccionado ?? DateTime.now()),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+ Agregar evento', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),

        // ── Selector de ámbito (sólo si se entró desde una materia) ───
        if (_desdeMateria)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_FiltroCal>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
                segments: [
                  if (widget.materiaIdInicial != null)
                    const ButtonSegment(
                      value: _FiltroCal.estaMateria,
                      label: Text('Esta materia'),
                      icon: Icon(Icons.book_rounded, size: 14),
                    ),
                  const ButtonSegment(
                    value: _FiltroCal.esteCurso,
                    label: Text('Este curso'),
                    icon: Icon(Icons.groups_rounded, size: 14),
                  ),
                  const ButtonSegment(
                    value: _FiltroCal.todas,
                    label: Text('Todas mis materias'),
                    icon: Icon(Icons.calendar_month_rounded, size: 14),
                  ),
                ],
                selected: {_filtro},
                onSelectionChanged: (s) => setState(() {
                  _filtro = s.first;
                  _recomputarEventos();
                }),
              ),
            ),
          ),

        // ── Filtro por tipo de evento ────────────────────────────────
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: [
              for (final f in _TipoFiltro.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_labelFiltroTipo(f), style: const TextStyle(fontSize: 11)),
                    selected: _tipoFiltro == f,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() {
                      _tipoFiltro = f;
                      _recomputarEventos();
                    }),
                  ),
                ),
            ],
          ),
        ),

        // ── Días de la semana + grid ─────────────────────────────────
        // Ancho acotado: sin esto, en pantalla ancha las celdas quedaban de
        // ~271px y el calendario se veía como una planilla estirada.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: _diasSemana
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant)),
                      ),
                    ))
                .toList(),
          ),
        ),

        // ── Grid del calendario ──────────────────────────────────────
        _cargando
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // mainAxisExtent (alto fijo) en vez de childAspectRatio:
                  // con ratio, en pantalla ancha las celdas se estiraban a
                  // ~190px de alto y empujaban la lista de eventos fuera de
                  // la tarjeta. Con alto fijo el grid mide igual en cualquier
                  // ancho y siempre queda lugar para la lista.
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: 46,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: offsetInicio + diasEnMes,
                  itemBuilder: (context, index) {
                    if (index < offsetInicio) return const SizedBox();
                    final dia = index - offsetInicio + 1;
                    final fecha =
                        DateTime(_mesActual.year, _mesActual.month, dia);
                    final esHoy = fecha.year == hoy.year &&
                        fecha.month == hoy.month &&
                        fecha.day == hoy.day;
                    final esSel = _diaSeleccionado != null &&
                        fecha.year == _diaSeleccionado!.year &&
                        fecha.month == _diaSeleccionado!.month &&
                        fecha.day == _diaSeleccionado!.day;
                    final eventos = _eventosDelDia(fecha);
                    final tieneEv = eventos.isNotEmpty;

                    // Colores de los puntos indicadores (máx 3)
                    final coloresPuntos = eventos
                        .take(3)
                        .map((e) => _colorTipo(
                            (e['tipo_evento'] ?? e['tipo'] ?? '') as String))
                        .toList();

                    return GestureDetector(
                      onTap: () =>
                          setState(() => _diaSeleccionado = fecha),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: esSel
                              ? colorScheme.primary
                              : esHoy
                                  ? colorScheme.primaryContainer
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: esHoy && !esSel
                              ? Border.all(
                                  color: colorScheme.primary, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dia',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: esHoy || esSel
                                    ? FontWeight.bold
                                    : null,
                                color: esSel
                                    ? colorScheme.onPrimary
                                    : esHoy
                                        ? colorScheme.primary
                                        : null,
                              ),
                            ),
                            if (tieneEv) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: coloresPuntos
                                    .map((c) => Container(
                                          width: 5,
                                          height: 5,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 1),
                                          decoration: BoxDecoration(
                                            color: esSel
                                                ? colorScheme.onPrimary
                                                : c,
                                            shape: BoxShape.circle,
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        // ── Lista de eventos del día seleccionado ────────────────────
        Expanded(
          child: _diaSeleccionado == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 40,
                          color:
                              colorScheme.onSurfaceVariant.withAlpha(80)),
                      const SizedBox(height: 8),
                      Text('Tocá un día para ver eventos',
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : _eventosDelDia(_diaSeleccionado!).isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available_rounded,
                              size: 40,
                              color: colorScheme.onSurfaceVariant
                                  .withAlpha(80)),
                          const SizedBox(height: 8),
                          Text(
                            'Sin eventos el ${_diaSeleccionado!.day}/${_diaSeleccionado!.month}',
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () =>
                                _abrirFormNuevoEvento(_diaSeleccionado!),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Agregar evento'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _eventosDelDia(_diaSeleccionado!).length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final e =
                            _eventosDelDia(_diaSeleccionado!)[i];
                        final tipo = (e['tipo_evento'] ?? e['tipo'] ?? '')
                            as String;
                        final color = _colorTipo(tipo);
                        final cursoNombre =
                            (e['_curso_nombre'] ?? 'General') as String;
                        final puedeEditar = _puedeEditar(e);

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: color.withAlpha(80)),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withAlpha(30),
                              child: Icon(_iconTipo(tipo),
                                  color: color, size: 20),
                            ),
                            title: Text(
                              (e['titulo'] ?? 'Sin título') as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            subtitle: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(20),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text(_labelTipo(tipo),
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer
                                        .withAlpha(60),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text(cursoNombre,
                                      style: TextStyle(
                                          color: colorScheme.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                                if (!puedeEditar)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('De otro docente',
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            // Sólo quien creó el evento (o dirección) lo edita
                            // o lo borra; la base aplica la misma regla.
                            trailing: puedeEditar
                                ? PopupMenuButton<String>(
                                    tooltip: 'Acciones',
                                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                                    onSelected: (v) {
                                      if (v == 'editar') {
                                        _abrirFormNuevoEvento(
                                            _diaSeleccionado!, evento: e);
                                      } else if (v == 'eliminar') {
                                        _confirmarEliminarEvento(e);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'editar',
                                        child: Row(children: [
                                          Icon(Icons.edit_rounded, size: 18),
                                          SizedBox(width: 10),
                                          Text('Modificar'),
                                        ]),
                                      ),
                                      PopupMenuItem(
                                        value: 'eliminar',
                                        child: Row(children: [
                                          Icon(Icons.delete_outline_rounded,
                                              size: 18, color: Colors.red),
                                          SizedBox(width: 10),
                                          Text('Eliminar',
                                              style: TextStyle(color: Colors.red)),
                                        ]),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );

    // Si hay ModalRoute activa (se navegó aquí como página), envolvemos en Scaffold
    final route = ModalRoute.of(context);
    if (route != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.cursNombreInicial != null
                ? 'Calendario — ${widget.cursNombreInicial}'
                : 'Calendario',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar',
              onPressed: _cargarTodo,
            ),
          ],
        ),
        body: calendarContent,
      );
    }

    return calendarContent;
  }
}
