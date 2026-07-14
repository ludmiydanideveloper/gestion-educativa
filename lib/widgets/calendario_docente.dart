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
  final String? cursNombreInicial;

  const CalendarioDocente({
    super.key,
    this.cursoIdInicial,
    this.cursNombreInicial,
  });

  @override
  State<CalendarioDocente> createState() => _CalendarioDocenteState();
}

class _CalendarioDocenteState extends State<CalendarioDocente> {
  final _service = SupabaseService();

  DateTime _mesActual = DateTime.now();
  DateTime? _diaSeleccionado;

  // Mapa: claveYYYY-MM-DD → lista de eventos de Supabase
  Map<String, List<Map<String, dynamic>>> _eventosPorDia = {};

  // Lista de cursos del docente (para el selector al agregar evento)
  List<Map<String, dynamic>> _cursos = [];
  bool _cargando = true;

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static const _diasSemana = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    try {
      // 1. Obtener cursos del docente
      final docenteId = await _service.obtenerDocenteIdActual();
      final materias = await _service.fetchMateriasPorDocente(docenteId);

      // Agrupar cursos únicos
      final cursosMap = <String, Map<String, dynamic>>{};
      for (final m in materias) {
        final cId = m['curso_id'] as String;
        cursosMap[cId] = {'curso_id': cId, 'nombre': m['identificador_division']};
      }
      _cursos = cursosMap.values.toList();

      // 2. Cargar eventos de todos los cursos
      final Map<String, List<Map<String, dynamic>>> nuevosEventos = {};
      for (final curso in _cursos) {
        final eventos = await _service.obtenerCalendarioPorCurso(curso['curso_id'] as String, soloPublicos: false);
        for (final e in eventos) {
          final fecha = (e['fecha'] as String).substring(0, 10);
          nuevosEventos.putIfAbsent(fecha, () => []).add({
            ...e,
            '_curso_nombre': curso['nombre'],
          });
        }
      }

      // También cargar eventos generales (sin curso)
      final generales = await _service.obtenerCalendarioPorCurso(null, soloPublicos: false);
      for (final e in generales) {
        final fecha = (e['fecha'] as String).substring(0, 10);
        final clave = fecha;
        if (!nuevosEventos.containsKey(clave) ||
            !nuevosEventos[clave]!.any((ev) => ev['id'] == e['id'])) {
          nuevosEventos.putIfAbsent(clave, () => []).add({
            ...e,
            '_curso_nombre': 'General',
          });
        }
      }

      if (mounted) {
        setState(() {
          _eventosPorDia = nuevosEventos;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando calendario: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _clave(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _eventosDelDia(DateTime d) =>
      _eventosPorDia[_clave(d)] ?? [];

  Color _colorTipo(String tipo) {
    switch (tipo?.toUpperCase()) {
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
    switch (tipo?.toUpperCase()) {
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
    switch (tipo?.toUpperCase()) {
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

  void _abrirFormNuevoEvento(DateTime fecha) {
    String tipoSeleccionado = 'EVALUACION';
    String? cursoSeleccionadoId = widget.cursoIdInicial ?? 
        (_cursos.isNotEmpty ? _cursos.first['curso_id'] as String : null);
    final tituloCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool guardando = false;
    bool esInterno = false;

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
                Text(
                  'Nuevo evento — ${fecha.day}/${fecha.month}/${fecha.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),

                // Visibilidad / Público
                SwitchListTile(
                  title: const Text('Exclusivo Personal (Interno)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                  subtitle: const Text('Si se activa, no aparecerá en el portal de padres ni alumnos (ej: Reunión de Profes)', style: TextStyle(fontSize: 11)),
                  value: esInterno,
                  activeColor: Colors.indigo,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setS(() => esInterno = val),
                ),
                const SizedBox(height: 12),

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
                if (_cursos.isNotEmpty) ...[
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
                              await _service.crearEventoCalendario(
                                titulo: tituloCtrl.text.trim(),
                                descripcion: descCtrl.text.trim(),
                                fecha: _clave(fecha),
                                tipoEvento: tipoSeleccionado,
                                cursoId: cursoSeleccionadoId,
                                esInterno: esInterno,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              await _cargarTodo();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '✅ "${tituloCtrl.text.trim()}" agregado al calendario'),
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
                        : const Icon(Icons.add_rounded),
                    label: const Text('Guardar evento'),
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

    return Column(
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
              // Botón agregar evento (solo Admin/Preceptor y si hay día seleccionado)
              if (puedeAgregar)
                FilledButton.icon(
                  onPressed: _diaSeleccionado != null
                      ? () => _abrirFormNuevoEvento(_diaSeleccionado!)
                      : null,
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

        // ── Días de la semana ────────────────────────────────────────
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
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
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
                            subtitle: Row(
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
                                const SizedBox(width: 6),
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
}
