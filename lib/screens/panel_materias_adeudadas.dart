import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/print_helper.dart';
import '../widgets/dialogo_periodos_adeudada.dart';

class PanelMateriasAdeudadas extends StatefulWidget {
  const PanelMateriasAdeudadas({super.key});

  @override
  State<PanelMateriasAdeudadas> createState() => _PanelMateriasAdeudadasState();
}

class _PanelMateriasAdeudadasState extends State<PanelMateriasAdeudadas> {
  final _service = SupabaseService();
  bool _loading = true;

  List<Map<String, dynamic>> _adeudadas = [];
  List<Map<String, dynamic>> _alumnos = [];
  List<Map<String, dynamic>> _materias = [];
  Map<String, String> _cursoNombrePorId = {};

  String _searchQuery = '';
  String _selectedMateriaFilter = 'Todas';
  String _selectedCondicionFilter = 'Todas';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.obtenerAdeudadasConDetalle(),
        _service.fetchAlumnosList(),
        _service.fetchMaterias(),
        _service.fetchCursos(),
      ]);
      _adeudadas = results[0];
      _alumnos = results[1];
      _materias = results[2];
      _cursoNombrePorId = {
        for (final c in results[3])
          (c['curso_id'] ?? '').toString(): (c['identificador_division'] ?? '').toString(),
      };
    } catch (e) {
      debugPrint('Error al cargar RITE adeudadas: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _nombreAlumno(Map<String, dynamic> item) {
    final alumno = item['usr_legajo_alumno'] as Map<String, dynamic>?;
    final demo = alumno?['datos_demograficos'] as Map<String, dynamic>?;
    final nombre = '${demo?['apellido'] ?? ''} ${demo?['nombre'] ?? ''}'.trim();
    return nombre.isEmpty ? 'Alumno' : nombre;
  }

  String _cursoActual(Map<String, dynamic> item) {
    final alumno = item['usr_legajo_alumno'] as Map<String, dynamic>?;
    final inscs = alumno?['acad_inscripciones'] as List?;
    final activa = inscs?.firstWhere((i) => i['estado'] == 'ACTIVO', orElse: () => inscs.isNotEmpty ? inscs.first : null);
    final curso = (activa is Map) ? activa['acad_cursos'] as Map? : null;
    return curso?['identificador_division']?.toString() ?? 'Sin curso';
  }

  String _cursoOrigen(Map<String, dynamic> item) {
    final materia = item['acad_materias'] as Map<String, dynamic>?;
    final curso = materia?['acad_cursos'] as Map?;
    return curso?['identificador_division']?.toString() ?? '';
  }

  void _abrirModalSubirAlumnoRite() {
    String? alumnoId;
    String? materiaId;
    final anioCtrl = TextEditingController(text: (DateTime.now().year - 1).toString());
    String condicion = SupabaseService.kCondicionIntensifica;
    bool guardando = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF6A4C9C)),
              SizedBox(width: 10),
              Expanded(child: Text('Subir Alumno a RITE')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: alumnoId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Alumno', border: OutlineInputBorder()),
                  items: _alumnos.map((a) {
                    return DropdownMenuItem<String>(
                      value: a['legajo_id'] as String,
                      child: Text('${a['nombre_completo']} (${a['curso_nombre'] ?? 'Sin curso'})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => alumnoId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: materiaId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Materia adeudada (real, del plan de estudios)', border: OutlineInputBorder()),
                  items: _materias.map((m) {
                    return DropdownMenuItem<String>(
                      value: m['materia_id'] as String,
                      child: Text('${m['nombre_asignatura']} — ${_cursoNombrePorId[m['curso_id']?.toString()] ?? ''}', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => materiaId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: anioCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Año en que se cursó (ej. 2025)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: condicion,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Condición Pedagógica RITE', border: OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(
                        value: SupabaseService.kCondicionIntensifica,
                        child: const Text('⚡ INTENSIFICA (rinde mesas/coloquios)')),
                    DropdownMenuItem(
                        value: SupabaseService.kCondicionRecursa,
                        child: const Text('🔄 RECURSA (la cursa de nuevo este año)')),
                    DropdownMenuItem(
                        value: SupabaseService.kCondicionPreviaLibre,
                        child: const Text('📌 ADEUDA PREVIA (año no adyacente)')),
                  ],
                  onChanged: (v) => setModalState(() => condicion = v ?? condicion),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A4C9C), foregroundColor: Colors.white),
              icon: guardando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: const Text('Subir Alumno a RITE'),
              onPressed: guardando
                  ? null
                  : () async {
                      if (alumnoId == null || materiaId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Elegí el alumno y la materia.')),
                        );
                        return;
                      }
                      setModalState(() => guardando = true);
                      try {
                        final materia = _materias.firstWhere((m) => m['materia_id'] == materiaId);
                        await _service.crearMateriaAdeudada(
                          alumnoId: alumnoId!,
                          materiaOriginalId: materiaId,
                          nombreMateria: materia['nombre_asignatura'].toString(),
                          anioOrigen: int.tryParse(anioCtrl.text) ?? DateTime.now().year,
                          condicion: condicion,
                        );
                        if (context.mounted) Navigator.pop(context);
                        await _cargar();
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Alumno subido a RITE como "${SupabaseService.labelCondicionAdeudada(condicion)}".'),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() => guardando = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminar(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar registro RITE'),
        content: Text('¿Eliminar "${item['nombre_materia']}" de ${_nombreAlumno(item)}? '
            'Se borra también su historial de períodos.'),
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
    if (ok != true) return;
    try {
      await _service.eliminarMateriaAdeudadaReal(item['adeudada_id'].toString());
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  void _imprimirAdeudadas(List<Map<String, dynamic>> filtered) {
    final rowsHtml = filtered.map((item) {
      final aprobada = (item['estado'] ?? '') == 'APROBADA';
      return '''
        <tr>
          <td>${_nombreAlumno(item)}</td>
          <td>${_cursoActual(item)}</td>
          <td>${item['nombre_materia'] ?? ''}</td>
          <td>${item['anio_origen'] ?? ''}</td>
          <td><b>${SupabaseService.labelCondicionAdeudada(item['condicion']?.toString())}</b></td>
          <td><span class="badge ${aprobada ? 'badge-green' : 'badge-red'}">${item['estado'] ?? 'PENDIENTE'}</span></td>
          <td>${item['calificacion_final'] ?? '-'}</td>
        </tr>
      ''';
    }).join('');

    final String tableHtml = '''
      <h2>Planilla RITE de Alumnos que Intensifican, Recursan y Adeudan</h2>
      <table>
        <thead>
          <tr>
            <th>Alumno</th>
            <th>Curso Actual</th>
            <th>Materia RITE</th>
            <th>Año Origen</th>
            <th>Condición</th>
            <th>Estado</th>
            <th>Nota Final</th>
          </tr>
        </thead>
        <tbody>
          $rowsHtml
        </tbody>
      </table>
    ''';

    PrintHelper.imprimirHTML(
      titulo: 'Planilla RITE - Intensifican y Recursan',
      htmlContentBody: tableHtml,
    );
  }

  @override
  Widget build(BuildContext context) {
    final materiasDisponibles = ['Todas', ..._materias.map((m) => m['nombre_asignatura'].toString()).toSet()];
    const condicionesDisponibles = [
      'Todas',
      SupabaseService.kCondicionIntensifica,
      SupabaseService.kCondicionRecursa,
      SupabaseService.kCondicionPreviaLibre,
    ];

    final filtered = _adeudadas.where((item) {
      final q = _searchQuery.toLowerCase();
      final coincideBusqueda = _nombreAlumno(item).toLowerCase().contains(q) ||
          (item['nombre_materia'] ?? '').toString().toLowerCase().contains(q);
      final coincideMateria = _selectedMateriaFilter == 'Todas' || item['nombre_materia'] == _selectedMateriaFilter;
      final coincideCondicion = _selectedCondicionFilter == 'Todas' || item['condicion'] == _selectedCondicionFilter;
      return coincideBusqueda && coincideMateria && coincideCondicion;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('RITE - Intensificación, Recursado y Adeudadas', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A4C9C), foregroundColor: Colors.white),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('+ Subir Alumno RITE'),
            onPressed: _abrirModalSubirAlumnoRite,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Imprimir listado RITE adeudadas',
            onPressed: () => _imprimirAdeudadas(filtered),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre del alumno o materia...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _selectedMateriaFilter,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Filtro por Materia',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: materiasDisponibles.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _selectedMateriaFilter = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCondicionFilter,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Condición',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: condicionesDisponibles
                              .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c == 'Todas' ? c : SupabaseService.labelCondicionAdeudada(c), overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCondicionFilter = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.assignment_turned_in_rounded, size: 54, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _adeudadas.isEmpty
                                      ? 'No hay alumnos registrados en RITE todavía.'
                                      : 'No hay alumnos registrados con ese criterio de búsqueda o filtro.',
                                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final aprobada = (item['estado'] ?? '') == 'APROBADA';
                              final condicion = (item['condicion'] ?? '').toString();

                              final Color condColor = condicion == SupabaseService.kCondicionIntensifica
                                  ? Colors.deepPurple
                                  : condicion == SupabaseService.kCondicionRecursa
                                      ? Colors.orange.shade800
                                      : Colors.teal.shade700;

                              final IconData condIconData = condicion == SupabaseService.kCondicionIntensifica
                                  ? Icons.bolt_rounded
                                  : condicion == SupabaseService.kCondicionRecursa
                                      ? Icons.refresh_rounded
                                      : Icons.bookmarks_rounded;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: condColor.withAlpha(80), width: 1.5),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: condColor.withAlpha(25),
                                    child: Icon(condIconData, color: condColor, size: 28),
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text('${_nombreAlumno(item)} (${_cursoActual(item)})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(color: condColor.withAlpha(25), borderRadius: BorderRadius.circular(8), border: Border.all(color: condColor)),
                                        child: Text(SupabaseService.labelCondicionAdeudada(condicion).toUpperCase(),
                                            style: TextStyle(color: condColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Materia: ${item['nombre_materia']} (${_cursoOrigen(item)}) | Año Cursada: ${item['anio_origen']}\n'
                                      'Nota Final: ${item['calificacion_final'] ?? "Pendiente de evaluación"}',
                                      style: const TextStyle(height: 1.3),
                                    ),
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: aprobada ? Colors.green : Colors.red,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          aprobada ? 'APROBADA' : 'PENDIENTE',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                        tooltip: 'Eliminar',
                                        onPressed: () => _eliminar(item),
                                      ),
                                    ],
                                  ),
                                  onTap: () => mostrarGestionAdeudada(
                                    context,
                                    adeudada: item,
                                    nombreAlumno: _nombreAlumno(item),
                                    onCambio: _cargar,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
