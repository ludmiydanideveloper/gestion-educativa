import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/alumno_asistencia.dart';
import 'panel_conducta_diaria.dart';
import '../widgets/app_drawer.dart';

class PanelConducta extends StatefulWidget {
  final String? cursoId;
  final String? alumnoId;
  const PanelConducta({super.key, this.cursoId, this.alumnoId});

  @override
  State<PanelConducta> createState() => _PanelConductaState();
}

class _PanelConductaState extends State<PanelConducta> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  
  // Listas de datos
  List<Map<String, dynamic>> _incidencias = [];
  List<Map<String, dynamic>> _incidenciasFiltradas = [];
  List<AlumnoAsistencia> _alumnos = [];
  List<Map<String, dynamic>> _cursos = [];

  // Filtros
  String _searchText = '';
  String _selectedSeverityFilter = 'TODOS'; // TODOS, Leve, Grave, Gravísima
  String? _filterCursoId;
  bool _mostrarConductaDiaria = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final listIncidencias = await _supabaseService.obtenerTodasIncidencias();
      final listAlumnos = await _supabaseService.fetchAlumnos(cursoId: widget.cursoId);
      final listCursos = await _supabaseService.fetchCursos();
      
      if (mounted) {
        setState(() {
          _incidencias = listIncidencias;
          _alumnos = listAlumnos;
          _cursos = listCursos;
          _isLoading = false;
        });
        _filtrarIncidencias();
      }
    } catch (e) {
      debugPrint('Error al cargar datos de conducta: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filtrarIncidencias() {
    setState(() {
      _incidenciasFiltradas = _incidencias.where((item) {
        final tipo = (item['tipo_incidencia'] ?? '').toString().toLowerCase();
        final desc = (item['descripcion'] ?? '').toString().toLowerCase();
        final isDailyConduct = tipo == 'bien' || tipo == 'más o menos' || tipo == 'mal' || desc.contains('conducta diaria:');
        
        if (_mostrarConductaDiaria != isDailyConduct) {
          return false;
        }

        final alumno = item['usr_legajo_alumno'] as Map<String, dynamic>?;
        final demo = alumno?['datos_demograficos'] as Map<String, dynamic>?;
        final nombreAlumno = '${demo?['apellido'] ?? ''} ${demo?['nombre'] ?? ''}'.toLowerCase();
        
        final inscs = alumno?['acad_inscripciones'] as List?;
        final cursoNombre = (inscs != null && inscs.isNotEmpty) 
            ? (inscs.first['acad_cursos']?['identificador_division']?.toString() ?? '').toLowerCase()
            : '';

        final incidentCursoId = (inscs != null && inscs.isNotEmpty)
            ? (inscs.first['acad_cursos']?['curso_id'])
            : null;
        final matchesCurso = _filterCursoId == null || incidentCursoId == _filterCursoId;

        final matchesSearch = nombreAlumno.contains(_searchText.toLowerCase()) ||
            cursoNombre.contains(_searchText.toLowerCase()) ||
            tipo.contains(_searchText.toLowerCase()) ||
            desc.contains(_searchText.toLowerCase());

        final matchesSeverity = _selectedSeverityFilter == 'TODOS' ||
            (item['severidad'] ?? '').toString().toUpperCase() == _selectedSeverityFilter.toUpperCase();

        return matchesSearch && matchesSeverity && matchesCurso;
      }).toList();
    });
  }

  // Abre el Modal de Creación de Incidencia
  void _abrirModalNuevaIncidencia() {
    final formKey = GlobalKey<FormState>();
    String? selectedAlumnoId = widget.alumnoId;
    String? selectedTipo;
    String? selectedSeveridad;
    final descripcionController = TextEditingController();
    bool isSaving = false;

    final List<String> tiposIncidencia = ['Indisciplina', 'Falta de Tarea', 'Incumplimiento de Uniforme', 'Otro'];
    final List<String> severidades = ['Leve', 'Grave', 'Gravísima'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Registrar Nueva Incidencia', style: TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: isSaving
                  ? const SizedBox(
                      height: 150,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Guardando incidencia...'),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Selector de Alumno
                            DropdownButtonFormField<String>(
                              value: selectedAlumnoId,
                              decoration: const InputDecoration(
                                labelText: 'Alumno',
                                prefixIcon: Icon(Icons.person_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              ),
                              items: _alumnos.map((a) {
                                return DropdownMenuItem(
                                  value: a.id,
                                  child: Text(a.nombre),
                                );
                              }).toList(),
                              onChanged: (value) => setModalState(() => selectedAlumnoId = value),
                              validator: (value) => value == null ? 'Selecciona un alumno' : null,
                            ),
                            const SizedBox(height: 16),
                            
                            // Selector de Tipo
                            DropdownButtonFormField<String>(
                              value: selectedTipo,
                              decoration: const InputDecoration(
                                labelText: 'Tipo de Incidencia',
                                prefixIcon: Icon(Icons.warning_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              ),
                              items: tiposIncidencia.map((t) {
                                return DropdownMenuItem(value: t, child: Text(t));
                              }).toList(),
                              onChanged: (value) => setModalState(() => selectedTipo = value),
                              validator: (value) => value == null ? 'Selecciona un tipo' : null,
                            ),
                            const SizedBox(height: 16),
                            
                            // Selector de Severidad
                            DropdownButtonFormField<String>(
                              value: selectedSeveridad,
                              decoration: const InputDecoration(
                                labelText: 'Severidad',
                                prefixIcon: Icon(Icons.local_fire_department_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              ),
                              items: severidades.map((s) {
                                return DropdownMenuItem(value: s, child: Text(s));
                              }).toList(),
                              onChanged: (value) => setModalState(() => selectedSeveridad = value),
                              validator: (value) => value == null ? 'Selecciona la severidad' : null,
                            ),
                            const SizedBox(height: 16),
                            
                            // Descripción
                            TextFormField(
                              controller: descripcionController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Descripción de la falta',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              ),
                              validator: (value) => value == null || value.isEmpty ? 'Escribe los detalles' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          setModalState(() => isSaving = true);
                          try {
                            await _supabaseService.registrarIncidencia(
                              alumnoId: selectedAlumnoId!,
                              tipoIncidencia: selectedTipo!,
                              severidad: selectedSeveridad!,
                              descripcion: descripcionController.text.trim(),
                            );
                            
                            Navigator.of(context).pop();
                            _cargarDatos();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Incidencia registrada con éxito'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al registrar incidencia: $e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirSeleccionConductaDiaria() {
    String? selectedCursoId;
    String? selectedMateriaNombre;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Registrar Conducta Diaria', style: TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCursoId,
                    decoration: const InputDecoration(labelText: 'Curso', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                    items: _cursos.map((c) {
                      return DropdownMenuItem(
                        value: c['curso_id'] as String,
                        child: Text(c['identificador_division'] as String),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        selectedCursoId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedMateriaNombre,
                    decoration: const InputDecoration(labelText: 'Materia / Asignatura', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                    disabledHint: const Text('Seleccione primero un curso'),
                    items: ['Historia Sagrada', 'Prácticas del Lenguaje', 'Ciencias Naturales', 'Educación Física', 'Construcción de la Ciudadanía', 'Matemática'].map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(m),
                      );
                    }).toList(),
                    onChanged: selectedCursoId == null
                        ? null
                        : (val) => setModalState(() => selectedMateriaNombre = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                TextButton(
                  onPressed: selectedCursoId == null
                      ? null
                      : () {
                          setState(() {
                            _filterCursoId = selectedCursoId;
                          });
                          _filtrarIncidencias();
                          Navigator.of(context).pop();
                        },
                  child: const Text('Ver Historial / Métricas'),
                ),
                ElevatedButton(
                  onPressed: (selectedCursoId == null || selectedMateriaNombre == null)
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PanelConductaDiaria(
                                cursoId: selectedCursoId!,
                                nombreAsignatura: selectedMateriaNombre!,
                              ),
                            ),
                          ).then((_) => _cargarDatos());
                        },
                  child: const Text('Registrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMetricsCard(ColorScheme colorScheme) {
    final total = _incidenciasFiltradas.length;
    final leves = _incidenciasFiltradas.where((item) => (item['severidad'] ?? '').toString().toUpperCase() == 'LEVE').length;
    final graves = _incidenciasFiltradas.where((item) => (item['severidad'] ?? '').toString().toUpperCase() == 'GRAVE').length;
    final gravisimas = _incidenciasFiltradas.where((item) => (item['severidad'] ?? '').toString().toUpperCase() == 'GRAVÍSIMA' || (item['severidad'] ?? '').toString().toUpperCase() == 'MODERADA').length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas de Conducta del Período',
              style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', total.toString(), Colors.blue, colorScheme),
                _buildStatItem('Leves', leves.toString(), Colors.green, colorScheme),
                _buildStatItem('Graves', graves.toString(), Colors.orange, colorScheme),
                _buildStatItem('Muy Graves', gravisimas.toString(), Colors.red, colorScheme),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (leves > 0)
                        Expanded(
                          flex: leves,
                          child: Container(color: Colors.green),
                        ),
                      if (graves > 0)
                        Expanded(
                          flex: graves,
                          child: Container(color: Colors.orange),
                        ),
                      if (gravisimas > 0)
                        Expanded(
                          flex: gravisimas,
                          child: Container(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: AppDrawer.buildLeading(context),
        leadingWidth: AppDrawer.buildLeadingWidth(context),
        title: const Text('Módulo de Conducta', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: _abrirSeleccionConductaDiaria,
              icon: const Icon(Icons.today_rounded, size: 16),
              label: const Text('Conducta Diaria (30% RITE)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirModalNuevaIncidencia,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Incidencia', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildMetricsCard(colorScheme),
          
          // Banner informativo sobre el Plan RITE Desempeño
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97706), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Integración RITE en Desempeño Diario (30%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E))),
                      const SizedBox(height: 2),
                      Text(
                        'Ingrese al botón superior "Conducta Diaria (30% RITE)" para registrar asistencias y comportamiento. Una vez por mes, pulse "Generar Nota Mes" para calcular el promedio (TEA/TEP/TED) e inyectar automáticamente la calificación a la Planilla del curso.',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Selector de Vista (Incidencias vs Conducta Diaria)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.gavel_rounded),
                        label: Text('Incidencias de Disciplina'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.today_rounded),
                        label: Text('Conducta Diaria'),
                      ),
                    ],
                    selected: {_mostrarConductaDiaria},
                    onSelectionChanged: (val) {
                      setState(() {
                        _mostrarConductaDiaria = val.first;
                      });
                      _filtrarIncidencias();
                    },
                  ),
                ),
              ],
            ),
          ),

          // Sección de Filtros y Búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Barra de Búsqueda y Dropdown de Curso
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: _mostrarConductaDiaria 
                                  ? 'Buscar por alumno o comentario...'
                                  : 'Buscar por alumno o tipo...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            ),
                            onChanged: (val) {
                              setState(() => _searchText = val);
                              _filtrarIncidencias();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _filterCursoId,
                            decoration: const InputDecoration(
                              labelText: 'Curso',
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Todos'),
                              ),
                              ..._cursos.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c['curso_id'] as String,
                                  child: Text(c['identificador_division'] as String),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _filterCursoId = val;
                              });
                              _filtrarIncidencias();
                            },
                          ),
                        ),
                      ],
                    ),
                    if (!_mostrarConductaDiaria) ...[
                      const SizedBox(height: 12),
                      // Chips de Severidad
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['TODOS', 'Leve', 'Grave', 'Gravísima'].map((sev) {
                            final selected = _selectedSeverityFilter == sev;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(sev),
                                selected: selected,
                                onSelected: (val) {
                                  setState(() => _selectedSeverityFilter = sev);
                                  _filtrarIncidencias();
                                },
                                selectedColor: const Color(0xFF334155),
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                  color: selected ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Historial de Incidencias
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _incidenciasFiltradas.isEmpty
                    ? const Center(
                        child: Text(
                          'No se encontraron incidencias de conducta.',
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: _incidenciasFiltradas.length,
                        itemBuilder: (context, index) {
                          final item = _incidenciasFiltradas[index];
                          
                          // Resolución de Alumno y Curso
                          final alumno = item['usr_legajo_alumno'] as Map<String, dynamic>?;
                          final demo = alumno?['datos_demograficos'] as Map<String, dynamic>?;
                          final nombreAlumno = '${demo?['apellido'] ?? ''} ${demo?['nombre'] ?? ''}'.trim();
                          
                          final inscs = alumno?['acad_inscripciones'] as List?;
                          final cursoNombre = (inscs != null && inscs.isNotEmpty) 
                              ? (inscs.first['acad_cursos']?['identificador_division']?.toString() ?? 'Sin curso') 
                              : 'Sin curso';

                          final tipo = item['tipo_incidencia'] as String? ?? 'Incidencia';
                          final sev = item['severidad'] as String? ?? 'Leve';
                          final desc = item['descripcion'] as String? ?? '';
                          final fecha = item['fecha'] as String? ?? '';

                          Color colorSev = Colors.blue;
                          if (sev == 'Grave') colorSev = Colors.orange.shade800;
                          if (sev == 'Gravísima') colorSev = Colors.red.shade800;

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          nombreAlumno.isNotEmpty ? nombreAlumno : 'Alumno',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: colorSev.withAlpha(25),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: colorSev.withAlpha(50)),
                                        ),
                                        child: Text(
                                          sev.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: colorSev,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Curso: $cursoNombre',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                                  ),
                                  const Divider(height: 20),
                                  Text(
                                    '$tipo: $desc',
                                    style: const TextStyle(fontSize: 13, height: 1.3),
                                  ),
                                  if (fecha.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Icon(Icons.calendar_today_rounded, size: 12, color: colorScheme.onSurfaceVariant.withAlpha(120)),
                                        const SizedBox(width: 4),
                                        Text(
                                          fecha,
                                          style: TextStyle(color: colorScheme.onSurfaceVariant.withAlpha(180), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ]
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
