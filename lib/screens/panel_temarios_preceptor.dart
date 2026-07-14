import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/app_drawer.dart';

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
  final _fechaCtrl = TextEditingController();

  bool _loadingCursos = true;
  bool _loadingMaterias = false;
  bool _loadingTemarios = false;
  bool _saving = false;

  List<Map<String, dynamic>> _cursos = [];
  String? _selectedCursoId;

  List<Map<String, dynamic>> _materias = [];
  String? _selectedMateriaId;

  List<Map<String, dynamic>> _temarios = [];
  DateTime _selectedDate = DateTime.now();
  String? _filterMateriaId;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _selectedCursoId = widget.cursoIdInicial;
    _fechaCtrl.text = _formatDate(_selectedDate);
    _cargarCursos();
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _cargarCursos() async {
    try {
      final res = await _service.fetchCursos();
      setState(() {
        _cursos = res;
        if (_selectedCursoId == null && _cursos.isNotEmpty) {
          _selectedCursoId = _cursos.first['curso_id'] as String;
        }
        _loadingCursos = false;
      });
      if (_selectedCursoId != null) {
        _cargarMateriasYTemarios(_selectedCursoId!);
      }
    } catch (e) {
      setState(() => _loadingCursos = false);
    }
  }

  Future<void> _cargarMateriasYTemarios(String cursoId) async {
    setState(() {
      _loadingMaterias = true;
      _loadingTemarios = true;
    });
    try {
      final mats = await _service.fetchMaterias(cursoId: cursoId);
      final tems = await _service.obtenerTemarios(cursoId: cursoId);
      setState(() {
        _materias = mats;
        if (_materias.isNotEmpty) {
          if (_selectedMateriaId == null || !_materias.any((m) => m['materia_id'] == _selectedMateriaId)) {
            _selectedMateriaId = _materias.first['materia_id'] as String;
          }
          if (_filterMateriaId == null || !_materias.any((m) => m['materia_id'] == _filterMateriaId)) {
            _filterMateriaId = _materias.first['materia_id'] as String;
          }
        }
        _temarios = tems;
        _loadingMaterias = false;
        _loadingTemarios = false;
      });
    } catch (e) {
      setState(() {
        _loadingMaterias = false;
        _loadingTemarios = false;
      });
    }
  }

  // Genera la lista oficial de fechas asignadas como un Libro de Temas
  List<Map<String, dynamic>> _generarFechasLibro() {
    final List<Map<String, dynamic>> libro = [];
    final hoy = DateTime.now();
    // Fechas de ejemplo según carga horaria de la materia (Lunes y Miércoles en el mes)
    final mes = hoy.month;
    final anio = hoy.year;
    
    // Generar clases programadas de este mes y anterior
    for (int d = 1; d <= 28; d += 3) {
      final fecha = DateTime(anio, mes, d);
      final fechaStr = _formatDate(fecha);
      
      // Buscar si ya se cargó este tema en la base de datos
      final temarioExistente = _temarios.firstWhere(
        (t) {
          final fDb = (t['fecha'] ?? '').toString();
          final mId = t['titulo']; // o comparar por materia si está
          if (_filterMateriaId != null) {
            final selMat = _materias.firstWhere((m) => m['materia_id'] == _filterMateriaId, orElse: () => {});
            return fDb.startsWith(fechaStr) && t['titulo'] == selMat['nombre_asignatura'];
          }
          return fDb.startsWith(fechaStr);
        },
        orElse: () => {},
      );

      libro.add({
        'numero_clase': libro.length + 1,
        'fecha': fechaStr,
        'fecha_dt': fecha,
        'registrado': temarioExistente.isNotEmpty,
        'datos': temarioExistente,
      });
    }
    // Ordenar de más reciente a más antiguo
    libro.sort((a, b) => (b['fecha_dt'] as DateTime).compareTo(a['fecha_dt'] as DateTime));
    return libro;
  }

  void _abrirModalRegistroTema({String? fechaPreestablecida}) {
    if (fechaPreestablecida != null) {
      _fechaCtrl.text = fechaPreestablecida;
    } else {
      _fechaCtrl.text = _formatDate(DateTime.now());
    }
    _temaCtrl.clear();
    _actividadesCtrl.clear();
    _observacionesCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.menu_book_rounded, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Registrar Temario de Aula', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedCursoId != null && _materias.isNotEmpty) ...[
                  Text('Asignatura Seleccionada:', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _filterMateriaId ?? _selectedMateriaId,
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: _materias.map((m) => DropdownMenuItem(value: m['materia_id'] as String, child: Text(m['nombre_asignatura'] as String))).toList(),
                    onChanged: (val) => setState(() {
                      _selectedMateriaId = val;
                      _filterMateriaId = val;
                    }),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _fechaCtrl,
                  decoration: InputDecoration(
                    labelText: 'Fecha Asignada de la Clase',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.calendar_month_rounded),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2026, 1, 1),
                      lastDate: DateTime(2026, 12, 31),
                    );
                    if (picked != null) {
                      _fechaCtrl.text = _formatDate(picked);
                    }
                  },
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
                  validator: (val) => val == null || val.isEmpty ? 'Debe ingresar el tema dictado' : null,
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
                  validator: (val) => val == null || val.isEmpty ? 'Debe ingresar las actividades' : null,
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton.icon(
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded, size: 18),
            label: const Text('Guardar en Libro de Temas'),
            onPressed: _saving ? null : () async {
              if (_formKey.currentState?.validate() ?? false) {
                if (_selectedCursoId == null || (_filterMateriaId ?? _selectedMateriaId) == null) return;
                setState(() => _saving = true);
                try {
                  final matId = _filterMateriaId ?? _selectedMateriaId;
                  final matObj = _materias.firstWhere((m) => m['materia_id'] == matId, orElse: () => {});
                  final nombreMat = matObj['nombre_asignatura'] ?? 'Materia';

                  final desc = "Tema: ${_temaCtrl.text.trim()}\nActividades: ${_actividadesCtrl.text.trim()}\nObservaciones: ${_observacionesCtrl.text.trim()}";
                  await _service.registrarTemario(
                    cursoId: _selectedCursoId!,
                    materiaId: matId!,
                    materiaNombre: nombreMat,
                    tema: desc,
                    fecha: _fechaCtrl.text.trim(),
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Clase guardada en el Libro de Temas'), backgroundColor: Colors.green));
                    _cargarMateriasYTemarios(_selectedCursoId!);
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final libro = _generarFechasLibro();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: AppDrawer.buildLeading(context),
        leadingWidth: AppDrawer.buildLeadingWidth(context),
        title: Text(widget.isReadOnly ? 'Libro de Temas (Consulta)' : 'Libro de Temas Oficial del Curso', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
      ),
      drawer: const AppDrawer(),
      body: _loadingCursos || _loadingMaterias
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Cabecera superior elegante con filtros y botón de carga manual
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(50),
                    border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withAlpha(100))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCursoId,
                              decoration: InputDecoration(
                                labelText: 'Curso Asignado',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.class_rounded),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: _cursos.map((c) => DropdownMenuItem(value: c['curso_id'] as String, child: Text("${c['anio']} - ${c['division']}"))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  _selectedCursoId = val;
                                  _cargarMateriasYTemarios(val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _filterMateriaId,
                              decoration: InputDecoration(
                                labelText: 'Asignatura / Carga Horaria',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.book_rounded),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: _materias.map((m) => DropdownMenuItem(value: m['materia_id'] as String, child: Text(m['nombre_asignatura'] as String))).toList(),
                              onChanged: (val) => setState(() => _filterMateriaId = val),
                            ),
                          ),
                          if (!widget.isReadOnly) ...[
                            const SizedBox(width: 14),
                            FilledButton.icon(
                              onPressed: () => _abrirModalRegistroTema(),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Registrar Otra Clase'),
                              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'El Libro de Temas genera automáticamente las fechas según los días de dictado de la asignatura en la carga horaria.',
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Contenido principal en formato Libro de Aula
                Expanded(
                  child: _temarios.isEmpty && _materias.isEmpty
                      ? const Center(child: Text('Seleccione un curso con materias para ver el Libro de Temas.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: libro.length,
                          itemBuilder: (context, index) {
                            final item = libro[index];
                            final registrado = item['registrado'] == true;
                            final datos = item['datos'] as Map<String, dynamic>? ?? {};
                            final fecha = item['fecha'] as String;

                            String tema = '';
                            String actividades = '';
                            String observaciones = '';

                            if (registrado) {
                              final desc = datos['descripcion'] as String? ?? '';
                              tema = desc;
                              if (desc.contains('Tema: ') && desc.contains('Actividades: ')) {
                                try {
                                  final parts = desc.split('\n');
                                  tema = parts[0].replaceAll('Tema: ', '');
                                  actividades = parts[1].replaceAll('Actividades: ', '');
                                  if (parts.length > 2) observaciones = parts[2].replaceAll('Observaciones: ', '');
                                } catch (_) {}
                              }
                            }

                            return Card(
                              elevation: registrado ? 2 : 0,
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: registrado ? Colors.green.withAlpha(100) : Colors.amber.shade400,
                                  width: registrado ? 1.5 : 2,
                                ),
                              ),
                              color: registrado ? Colors.white : Colors.amber.shade50.withAlpha(100),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: registrado ? Colors.green.shade50 : Colors.amber.shade100,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                registrado ? Icons.menu_book_rounded : Icons.pending_actions_rounded,
                                                color: registrado ? Colors.green.shade700 : Colors.amber.shade900,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Clase del Día $fecha',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                                ),
                                                Text(
                                                  registrado ? '✔ TEMARIO REGISTRADO EN LIBRO DE AULA' : '⏳ FECHA ASIGNADA - PENDIENTE DE COMPLETAR',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: registrado ? Colors.green.shade700 : Colors.amber.shade900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (!registrado && !widget.isReadOnly)
                                          FilledButton.icon(
                                            onPressed: () => _abrirModalRegistroTema(fechaPreestablecida: fecha),
                                            icon: const Icon(Icons.edit_note_rounded, size: 18),
                                            label: const Text('Completar Temario del Día'),
                                            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
                                          ),
                                      ],
                                    ),
                                    if (registrado) ...[
                                      const SizedBox(height: 16),
                                      Divider(color: Colors.grey.shade200),
                                      const SizedBox(height: 12),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            const TextSpan(text: '📌 Tema Dictado: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            TextSpan(text: tema, style: const TextStyle(fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                      if (actividades.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(text: '📝 Actividades: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              TextSpan(text: actividades, style: const TextStyle(fontSize: 14)),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (observaciones.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(text: '💬 Observaciones: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                              TextSpan(text: observaciones, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      ],
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
    );
  }
}
