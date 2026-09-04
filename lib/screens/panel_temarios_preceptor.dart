import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/horarios_data.dart';
import '../services/supabase_service.dart';
import '../widgets/app_drawer.dart';

/// Una clase del Libro de Temas: una fecha de dictado con su temario
/// cargado (o pendiente, si todavía no se registró).
class _ClaseLibro {
  final DateTime fecha;
  final Map<String, dynamic>? temario;

  const _ClaseLibro({required this.fecha, this.temario});

  bool get registrado => temario != null;
}

/// Agrupación mensual de clases: es la tarjeta que ve el docente.
class _MesLibro {
  final int mes;
  final int anio;
  final List<_ClaseLibro> clases;

  const _MesLibro({required this.mes, required this.anio, required this.clases});

  int get registradas => clases.where((c) => c.registrado).length;
  int get total => clases.length;
  double get progreso => total == 0 ? 0 : registradas / total;
}

class PanelTemariosPreceptor extends StatefulWidget {
  final String? cursoIdInicial;
  final bool isReadOnly;
  const PanelTemariosPreceptor({super.key, this.cursoIdInicial, this.isReadOnly = false});

  @override
  State<PanelTemariosPreceptor> createState() => _PanelTemariosPreceptorState();
}

class _PanelTemariosPreceptorState extends State<PanelTemariosPreceptor> {
  final _service = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final _temaCtrl = TextEditingController();
  final _actividadesCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  bool _loadingCursos = true;
  bool _loadingTemarios = false;
  bool _saving = false;

  /// Cursos disponibles: [{curso_id, nombre}]
  List<Map<String, dynamic>> _cursos = [];
  String? _selectedCursoId;

  /// Materias del curso seleccionado: [{materia_id, nombre_asignatura}]
  List<Map<String, dynamic>> _materias = [];
  String? _selectedMateriaId;

  /// Pares curso/materia asignados al docente (sólo cuando el rol es DOCENTE)
  List<Map<String, dynamic>> _asignacionesDocente = [];
  bool _esDocente = false;

  List<Map<String, dynamic>> _temarios = [];

  /// Meses desplegados en la vista (clave: mes del año lectivo)
  final Set<int> _mesesAbiertos = {};

  static const _mesesNombres = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  /// Meses del ciclo lectivo (marzo a diciembre)
  static const _primerMesLectivo = 3;
  static const _ultimoMesLectivo = 12;

  @override
  void initState() {
    super.initState();
    _selectedCursoId = widget.cursoIdInicial;
    _mesesAbiertos.add(DateTime.now().month);
    final rol = Supabase.instance.client.auth.currentUser?.userMetadata?['rol'] as String?;
    _esDocente = !widget.isReadOnly && (rol == null || rol == 'DOCENTE');
    _cargarCursos();
  }

  @override
  void dispose() {
    _temaCtrl.dispose();
    _actividadesCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  // ── Formatos de fecha ───────────────────────────────────────────────────
  /// Formato que guarda la base (yyyy-MM-dd)
  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Formato que ve el usuario (dd/MM/yyyy)
  String _fechaVisible(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _diaSemana(DateTime d) {
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return dias[d.weekday - 1];
  }

  // ── Carga de datos ──────────────────────────────────────────────────────
  Future<void> _cargarCursos() async {
    setState(() => _loadingCursos = true);
    try {
      if (_esDocente) {
        // El docente sólo ve los cursos y materias que tiene asignados.
        final docenteId = await _service.obtenerDocenteIdActual();
        _asignacionesDocente = await _service.fetchMateriasPorDocente(docenteId);

        final cursosMap = <String, Map<String, dynamic>>{};
        for (final a in _asignacionesDocente) {
          cursosMap[a['curso_id'] as String] = {
            'curso_id': a['curso_id'],
            'nombre': a['identificador_division'],
          };
        }
        _cursos = cursosMap.values.toList()
          ..sort((a, b) => (a['nombre'] ?? '').toString().compareTo((b['nombre'] ?? '').toString()));
      } else {
        final res = await _service.fetchCursos();
        _cursos = res
            .map((c) => {
                  'curso_id': c['curso_id'],
                  'nombre': c['identificador_division'] ?? 'Curso',
                })
            .toList();
      }

      if (_selectedCursoId == null || !_cursos.any((c) => c['curso_id'] == _selectedCursoId)) {
        _selectedCursoId = _cursos.isNotEmpty ? _cursos.first['curso_id'] as String : null;
      }

      if (!mounted) return;
      setState(() => _loadingCursos = false);

      if (_selectedCursoId != null) {
        await _cargarMateriasYTemarios(_selectedCursoId!);
      }
    } catch (e) {
      debugPrint('Error al cargar cursos del libro de temas: $e');
      if (mounted) setState(() => _loadingCursos = false);
    }
  }

  Future<void> _cargarMateriasYTemarios(String cursoId) async {
    setState(() => _loadingTemarios = true);
    try {
      List<Map<String, dynamic>> mats;
      if (_esDocente) {
        mats = _asignacionesDocente
            .where((a) => a['curso_id'] == cursoId)
            .map((a) => {
                  'materia_id': a['materia_id'],
                  'nombre_asignatura': a['nombre_asignatura'],
                })
            .toList();
      } else {
        mats = await _service.fetchMaterias(cursoId: cursoId);
      }
      mats.sort((a, b) => (a['nombre_asignatura'] ?? '')
          .toString()
          .compareTo((b['nombre_asignatura'] ?? '').toString()));

      final tems = await _service.obtenerTemarios(cursoId: cursoId);

      if (!mounted) return;
      setState(() {
        _materias = mats;
        if (_selectedMateriaId == null || !mats.any((m) => m['materia_id'] == _selectedMateriaId)) {
          _selectedMateriaId = mats.isNotEmpty ? mats.first['materia_id'] as String : null;
        }
        _temarios = tems;
        _loadingTemarios = false;
      });
    } catch (e) {
      debugPrint('Error al cargar el libro de temas: $e');
      if (mounted) setState(() => _loadingTemarios = false);
    }
  }

  String get _nombreCursoSeleccionado {
    final c = _cursos.firstWhere((c) => c['curso_id'] == _selectedCursoId, orElse: () => {});
    return (c['nombre'] ?? '').toString();
  }

  String get _nombreMateriaSeleccionada {
    final m = _materias.firstWhere((m) => m['materia_id'] == _selectedMateriaId, orElse: () => {});
    return (m['nombre_asignatura'] ?? '').toString();
  }

  // ── Armado del libro ────────────────────────────────────────────────────
  /// Temarios que corresponden a la materia seleccionada.
  /// Se filtra por materia_id cuando está disponible y, si no, por el título
  /// (registrarTemario guarda ahí el nombre de la asignatura).
  List<Map<String, dynamic>> get _temariosDeLaMateria {
    final nombre = _nombreMateriaSeleccionada;
    return _temarios.where((t) {
      final matId = t['materia_id'];
      if (matId != null && _selectedMateriaId != null) return matId == _selectedMateriaId;
      return (t['titulo'] ?? '').toString() == nombre;
    }).toList();
  }

  /// Construye las tarjetas mensuales del ciclo lectivo con las fechas de
  /// dictado reales de la asignatura (grilla horaria oficial del curso).
  List<_MesLibro> _construirLibro() {
    final anio = DateTime.now().year;
    final diasDictado = HorariosData.diasDeDictado(
      _nombreCursoSeleccionado,
      _nombreMateriaSeleccionada,
    );

    // Indexar los temarios ya cargados por fecha
    final porFecha = <String, Map<String, dynamic>>{};
    for (final t in _temariosDeLaMateria) {
      final f = (t['fecha'] ?? '').toString();
      if (f.length >= 10) porFecha[f.substring(0, 10)] = t;
    }

    final meses = <_MesLibro>[];
    for (int mes = _primerMesLectivo; mes <= _ultimoMesLectivo; mes++) {
      final fechas = <DateTime>{};

      if (diasDictado.isNotEmpty) {
        final ultimoDia = DateTime(anio, mes + 1, 0).day;
        for (int d = 1; d <= ultimoDia; d++) {
          final fecha = DateTime(anio, mes, d);
          if (diasDictado.contains(fecha.weekday)) fechas.add(fecha);
        }
      }

      // Sumar clases cargadas a mano en fechas fuera de la grilla, para que
      // ningún temario registrado quede invisible.
      for (final clave in porFecha.keys) {
        final f = DateTime.tryParse(clave);
        if (f != null && f.year == anio && f.month == mes) fechas.add(DateTime(f.year, f.month, f.day));
      }

      if (fechas.isEmpty) continue;

      final ordenadas = fechas.toList()..sort();
      meses.add(_MesLibro(
        mes: mes,
        anio: anio,
        clases: ordenadas
            .map((f) => _ClaseLibro(fecha: f, temario: porFecha[_isoDate(f)]))
            .toList(),
      ));
    }
    return meses;
  }

  /// Separa la descripción guardada en sus tres campos.
  Map<String, String> _parsearTemario(Map<String, dynamic> datos) {
    final desc = (datos['descripcion'] ?? '').toString();
    final res = {'tema': desc, 'actividades': '', 'observaciones': ''};
    final partes = desc.split('\n');
    for (final p in partes) {
      if (p.startsWith('Tema: ')) res['tema'] = p.substring(6).trim();
      if (p.startsWith('Actividades: ')) res['actividades'] = p.substring(13).trim();
      if (p.startsWith('Observaciones: ')) res['observaciones'] = p.substring(15).trim();
    }
    return res;
  }

  // ── Modal de carga / edición ────────────────────────────────────────────
  void _abrirModalRegistroTema({DateTime? fecha, Map<String, dynamic>? temarioExistente}) {
    if (_selectedCursoId == null || _selectedMateriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná primero el curso y la asignatura.')),
      );
      return;
    }

    var fechaSeleccionada = fecha ?? DateTime.now();
    if (temarioExistente != null) {
      final datos = _parsearTemario(temarioExistente);
      _temaCtrl.text = datos['tema'] ?? '';
      _actividadesCtrl.text = datos['actividades'] ?? '';
      _observacionesCtrl.text = datos['observaciones'] ?? '';
    } else {
      _temaCtrl.clear();
      _actividadesCtrl.clear();
      _observacionesCtrl.clear();
    }

    final size = MediaQuery.of(context).size;
    final anchoDialogo = size.width < 560 ? size.width - 32 : 520.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.menu_book_rounded, color: Theme.of(ctx).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  temarioExistente == null ? 'Registrar Temario de Aula' : 'Editar Temario de Aula',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: anchoDialogo,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.primaryContainer.withAlpha(60),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_nombreMateriaSeleccionada,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text('Curso: $_nombreCursoSeleccionado',
                              style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: fechaSeleccionada,
                          firstDate: DateTime(fechaSeleccionada.year - 1, 1, 1),
                          lastDate: DateTime(fechaSeleccionada.year + 1, 12, 31),
                        );
                        if (picked != null) setDialog(() => fechaSeleccionada = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fecha Asignada de la Clase',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.calendar_month_rounded),
                        ),
                        child: Text(
                          '${_fechaVisible(fechaSeleccionada)}  ·  ${_diaSemana(fechaSeleccionada)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _temaCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Tema Principal Desarrollado',
                        hintText: 'Ej. Sistema Nervioso Central y Sinapsis',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Debe ingresar el tema dictado' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _actividadesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Actividades Pedagógicas / Prácticas',
                        hintText: 'Ej. Lectura del capítulo 4, esquema conceptual y debate grupal.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Debe ingresar las actividades' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _observacionesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Observaciones / Tarea para el hogar (Opcional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Guardar'),
              onPressed: _saving
                  ? null
                  : () async {
                      if (!(_formKey.currentState?.validate() ?? false)) return;
                      setDialog(() => _saving = true);
                      try {
                        final desc = 'Tema: ${_temaCtrl.text.trim()}\n'
                            'Actividades: ${_actividadesCtrl.text.trim()}\n'
                            'Observaciones: ${_observacionesCtrl.text.trim()}';

                        final eventoId = temarioExistente?['evento_id']?.toString();
                        if (eventoId != null) {
                          await _service.actualizarTemario(
                            eventoId: eventoId,
                            tema: desc,
                            fecha: _isoDate(fechaSeleccionada),
                          );
                        } else {
                          await _service.registrarTemario(
                            cursoId: _selectedCursoId!,
                            materiaId: _selectedMateriaId!,
                            materiaNombre: _nombreMateriaSeleccionada,
                            tema: desc,
                            fecha: _isoDate(fechaSeleccionada),
                          );
                        }
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Clase guardada en el Libro de Temas'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _mesesAbiertos.add(fechaSeleccionada.month);
                        await _cargarMateriasYTemarios(_selectedCursoId!);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setDialog(() => _saving = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final esMovil = MediaQuery.of(context).size.width < 650;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: AppDrawer.buildLeading(context),
        leadingWidth: AppDrawer.buildLeadingWidth(context),
        title: Text(
          widget.isReadOnly
              ? 'Libro de Temas'
              : (esMovil ? 'Libro de Temas' : 'Libro de Temas Oficial del Curso'),
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
      ),
      drawer: const AppDrawer(),
      floatingActionButton: widget.isReadOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _abrirModalRegistroTema(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Otra Clase'),
            ),
      body: _loadingCursos
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFiltros(colorScheme, esMovil),
                Expanded(
                  child: _loadingTemarios
                      ? const Center(child: CircularProgressIndicator())
                      : _buildLibro(colorScheme),
                ),
              ],
            ),
    );
  }

  Widget _buildFiltros(ColorScheme colorScheme, bool esMovil) {
    final selectorCurso = DropdownButtonFormField<String>(
      value: _selectedCursoId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Curso Asignado',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.class_rounded),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
      ),
      items: _cursos
          .map((c) => DropdownMenuItem(
                value: c['curso_id'] as String,
                child: Text((c['nombre'] ?? 'Curso').toString(), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (val) {
        if (val != null && val != _selectedCursoId) {
          setState(() {
            _selectedCursoId = val;
            _selectedMateriaId = null;
          });
          _cargarMateriasYTemarios(val);
        }
      },
    );

    final selectorMateria = DropdownButtonFormField<String>(
      value: _selectedMateriaId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Asignatura',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.book_rounded),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
      ),
      items: _materias
          .map((m) => DropdownMenuItem(
                value: m['materia_id'] as String,
                child: Text((m['nombre_asignatura'] ?? '').toString(),
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (val) => setState(() => _selectedMateriaId = val),
    );

    final sinGrilla = _selectedMateriaId != null &&
        HorariosData.diasDeDictado(_nombreCursoSeleccionado, _nombreMateriaSeleccionada).isEmpty;

    return Container(
      padding: EdgeInsets.all(esMovil ? 14 : 20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(50),
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withAlpha(100))),
      ),
      child: Column(
        children: [
          if (esMovil) ...[
            selectorCurso,
            const SizedBox(height: 10),
            selectorMateria,
          ] else
            Row(
              children: [
                Expanded(child: selectorCurso),
                const SizedBox(width: 14),
                Expanded(child: selectorMateria),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                sinGrilla ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                size: 16,
                color: sinGrilla ? Colors.amber.shade800 : colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sinGrilla
                      ? 'Esta asignatura no figura en la grilla horaria del curso: sólo se listan las clases que cargues manualmente con "Otra Clase".'
                      : 'Las fechas se generan según los días de dictado de la asignatura en la carga horaria.',
                  style: TextStyle(
                    fontSize: 12,
                    color: sinGrilla ? Colors.amber.shade900 : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLibro(ColorScheme colorScheme) {
    if (_materias.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No hay asignaturas asignadas para este curso.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final meses = _construirLibro();
    if (meses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_note_rounded, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'Todavía no hay clases para mostrar en este ciclo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      itemCount: meses.length,
      itemBuilder: (context, index) => _buildTarjetaMes(meses[index], colorScheme),
    );
  }

  Widget _buildTarjetaMes(_MesLibro mes, ColorScheme colorScheme) {
    final completo = mes.total > 0 && mes.registradas == mes.total;
    final abierto = _mesesAbiertos.contains(mes.mes);
    final colorAcento = completo ? Colors.green.shade600 : colorScheme.primary;

    return Card(
      elevation: abierto ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorAcento.withAlpha(abierto ? 120 : 60)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Quita las líneas divisorias propias del ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('mes_${mes.anio}_${mes.mes}'),
          initiallyExpanded: abierto,
          onExpansionChanged: (exp) {
            if (exp) {
              _mesesAbiertos.add(mes.mes);
            } else {
              _mesesAbiertos.remove(mes.mes);
            }
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorAcento.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              completo ? Icons.check_circle_rounded : Icons.calendar_month_rounded,
              color: colorAcento,
            ),
          ),
          title: Text(
            '${_mesesNombres[mes.mes - 1]} ${mes.anio}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mes.registradas} de ${mes.total} clases registradas',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: mes.progreso,
                    minHeight: 6,
                    backgroundColor: colorScheme.outlineVariant.withAlpha(80),
                    valueColor: AlwaysStoppedAnimation(colorAcento),
                  ),
                ),
              ],
            ),
          ),
          children: mes.clases.map((c) => _buildFilaClase(c, colorScheme)).toList(),
        ),
      ),
    );
  }

  Widget _buildFilaClase(_ClaseLibro clase, ColorScheme colorScheme) {
    final registrado = clase.registrado;
    final datos = registrado ? _parsearTemario(clase.temario!) : null;
    final esFutura = clase.fecha.isAfter(DateTime.now());

    final Color color = registrado
        ? Colors.green.shade700
        : (esFutura ? colorScheme.outline : Colors.amber.shade800);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: registrado ? Colors.green.withAlpha(12) : Colors.amber.withAlpha(esFutura ? 6 : 20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  registrado
                      ? Icons.menu_book_rounded
                      : (esFutura ? Icons.schedule_rounded : Icons.pending_actions_rounded),
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fechaVisible(clase.fecha),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_diaSemana(clase.fecha)} · '
                        '${registrado ? 'Temario registrado' : (esFutura ? 'Clase programada' : 'Pendiente de completar')}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                      ),
                    ],
                  ),
                ),
                if (!widget.isReadOnly)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(registrado ? Icons.edit_note_rounded : Icons.add_rounded, size: 18),
                    label: Text(registrado ? 'Editar' : 'Completar'),
                    onPressed: () => _abrirModalRegistroTema(
                      fecha: clase.fecha,
                      temarioExistente: clase.temario,
                    ),
                  ),
              ],
            ),
            if (registrado) ...[
              const SizedBox(height: 10),
              _lineaDetalle('📌 Tema', datos!['tema'] ?? ''),
              if ((datos['actividades'] ?? '').isNotEmpty)
                _lineaDetalle('📝 Actividades', datos['actividades']!),
              if ((datos['observaciones'] ?? '').isNotEmpty)
                _lineaDetalle('💬 Observaciones', datos['observaciones']!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lineaDetalle(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$etiqueta: ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            TextSpan(text: valor, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
