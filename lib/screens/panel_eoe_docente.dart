import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class PanelEoeDocente extends StatefulWidget {
  final String cursoId;
  final String identificadorDivision;

  const PanelEoeDocente({
    super.key,
    required this.cursoId,
    required this.identificadorDivision,
  });

  @override
  State<PanelEoeDocente> createState() => _PanelEoeDocenteState();
}

class _PanelEoeDocenteState extends State<PanelEoeDocente> {
  final _service = SupabaseService();
  bool _loading = true;
  List<Map<String, dynamic>> _alumnos = [];
  Map<String, dynamic>? _selectedAlumno;
  final _notaCtrl = TextEditingController();
  bool _savingNota = false;

  // Mock de bitácora por legajo en caso de que no haya registros previos
  final Map<String, List<Map<String, String>>> _bitacorasMock = {};

  @override
  void initState() {
    super.initState();
    _cargarAlumnos();
  }

  Future<void> _cargarAlumnos() async {
    try {
      final list = await _service.fetchAlumnos(cursoId: widget.cursoId);
      final response = await _service.fetchAlumnosList();
      
      final List<Map<String, dynamic>> listCompleta = [];
      for (final a in list) {
        final ext = response.firstWhere(
          (element) => element['legajo_id'] == a.id,
          orElse: () => {},
        );
        final Map<String, dynamic> demo = Map<String, dynamic>.from(ext['datos_demograficos'] as Map? ?? {});
        
        final alMap = {
          'id': a.id,
          'legajo_id': a.id,
          'nombre_completo': a.nombre,
          'nombre': a.nombre,
          'dni': ext['dni'] ?? 'DNI No cargado',
          'adecuacion_curricular': demo['adecuacion_curricular'] == true,
          'tipo_adecuacion': demo['tipo_adecuacion'] ?? 'Metodológica',
          'detalles_adecuacion': demo['detalles_adecuacion'] ?? 'Requiere mayor tiempo en evaluaciones y consignas claras.',
        };
        listCompleta.add(alMap);

        _bitacorasMock.putIfAbsent(a.id, () => [
          {'id': '1', 'autor': 'Preceptor Martin', 'nota': 'Se observa buena predisposición. En exámenes escritos requiere más tiempo pero logra concentrarse.', 'fecha': '2026-06-15'},
          {'id': '2', 'autor': 'Docente Lengua', 'nota': 'Se aplicó evaluación oral complementaria. Responde muy bien a las consignas.', 'fecha': '2026-06-30'}
        ]);
      }

      setState(() {
        _alumnos = listCompleta;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error cargando alumnos EOE: $e');
      setState(() => _loading = false);
    }
  }

  void _agregarNotaBitacora() {
    if (_selectedAlumno == null || _notaCtrl.text.trim().isEmpty) return;
    
    setState(() => _savingNota = true);
    
    Future.delayed(const Duration(milliseconds: 500), () {
      final legajoId = _selectedAlumno!['legajo_id'] as String;
      final hoy = DateTime.now();
      final fechaStr = "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";
      
      setState(() {
        _bitacorasMock[legajoId]!.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'autor': 'Docente (Materia)',
          'nota': _notaCtrl.text.trim(),
          'fecha': fechaStr,
        });
        _notaCtrl.clear();
        _savingNota = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Nota agregada a la bitácora de acompañamiento.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final alumnosConAdecuacion = _alumnos.where((a) => a['adecuacion_curricular'] == true).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Gabinete EOE - ${widget.identificadorDivision}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Columna izquierda: Lista de alumnos con adecuación
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: colorScheme.outlineVariant.withAlpha(80))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Alumnos con Adecuación Curricular (${alumnosConAdecuacion.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        Expanded(
                          child: alumnosConAdecuacion.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'No hay alumnos con adecuación curricular en este curso.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: alumnosConAdecuacion.length,
                                  itemBuilder: (context, index) {
                                    final al = alumnosConAdecuacion[index];
                                    final isSelected = _selectedAlumno?['legajo_id'] == al['legajo_id'];
                                    return ListTile(
                                      selected: isSelected,
                                      selectedTileColor: colorScheme.primaryContainer.withAlpha(30),
                                      leading: CircleAvatar(
                                        backgroundColor: colorScheme.secondary.withAlpha(20),
                                        child: Icon(Icons.person_rounded, color: colorScheme.secondary),
                                      ),
                                      title: Text(
                                        al['nombre_completo'] ?? 'Alumno',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        'Adecuación: ${al['tipo_adecuacion'] ?? "General"}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                                      onTap: () {
                                        setState(() {
                                          _selectedAlumno = al;
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Columna derecha: Detalles de adecuación y Bitácora
                Expanded(
                  flex: 3,
                  child: _selectedAlumno == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_ind_rounded, size: 64, color: colorScheme.secondary.withAlpha(60)),
                              const SizedBox(height: 12),
                              const Text(
                                'Seleccione un alumno para ver su ficha EOE',
                                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cabecera Alumno
                              Text(
                                _selectedAlumno!['nombre_completo'] ?? 'Alumno',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.primary),
                              ),
                              const SizedBox(height: 16),

                              // Ficha de Adecuación
                              Card(
                                elevation: 0,
                                color: colorScheme.primaryContainer.withAlpha(25),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: colorScheme.primary.withAlpha(40)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.shield_outlined, color: Colors.indigo),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Pautas de Adecuación Curricular (${_selectedAlumno!['tipo_adecuacion']})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _selectedAlumno!['detalles_adecuacion'] ?? 'Sin especificaciones.',
                                        style: const TextStyle(fontSize: 12, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Sección de Bitácora
                              const Text(
                                'Bitácora de Acompañamiento EOE',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),

                              // Formulario para nueva nota
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _notaCtrl,
                                      decoration: const InputDecoration(
                                        hintText: 'Registrar evolución, pauta o incidencia...',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _savingNota ? null : _agregarNotaBitacora,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: _savingNota
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Agregar'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Historial de Bitácora
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _bitacorasMock[_selectedAlumno!['legajo_id']]?.length ?? 0,
                                  itemBuilder: (context, idx) {
                                    final item = _bitacorasMock[_selectedAlumno!['legajo_id']]![idx];
                                    return Card(
                                      elevation: 0,
                                      color: Colors.grey.shade50,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: Colors.grey.shade200),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  item['autor']!,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                                                ),
                                                Text(
                                                  item['fecha']!,
                                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              item['nota']!,
                                              style: const TextStyle(fontSize: 12, height: 1.3),
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
                        ),
                ),
              ],
            ),
    );
  }
}
