import 'package:flutter/material.dart';
import '../services/print_helper.dart';

class PanelMateriasAdeudadas extends StatefulWidget {
  const PanelMateriasAdeudadas({super.key});

  @override
  State<PanelMateriasAdeudadas> createState() => _PanelMateriasAdeudadasState();
}

class _PanelMateriasAdeudadasState extends State<PanelMateriasAdeudadas> {
  final List<Map<String, dynamic>> _adeudadas = [
    {
      'alumno': 'Mora Romero',
      'curso': '3ro B',
      'materia': 'Matemática',
      'anio_cursada': '1ro (2024)',
      'condicion': 'Intensifica', // Intensifica, Recursa, Adeuda Previa
      'estado_rite': 'TED', // TED, EP/TEP, TEA
      'nota_coloquio': null,
    },
    {
      'alumno': 'Mora Romero',
      'curso': '3ro B',
      'materia': 'Prácticas del Lenguaje',
      'anio_cursada': '2do (2025)',
      'condicion': 'Recursa',
      'estado_rite': 'EP',
      'nota_coloquio': 6.0,
    },
    {
      'alumno': 'Clara Romero',
      'curso': '2do A',
      'materia': 'Ciencias Naturales',
      'anio_cursada': '1ro (2025)',
      'condicion': 'Intensifica',
      'estado_rite': 'EP',
      'nota_coloquio': 6.5,
    },
    {
      'alumno': 'Juan Perez',
      'curso': '4to A',
      'materia': 'Historia',
      'anio_cursada': '2do (2024)',
      'condicion': 'Adeuda Previa',
      'estado_rite': 'TED',
      'nota_coloquio': null,
    },
    {
      'alumno': 'Lucas Benitez',
      'curso': '3ro A',
      'materia': 'Matemática',
      'anio_cursada': '2do (2025)',
      'condicion': 'Recursa',
      'estado_rite': 'TED',
      'nota_coloquio': null,
    },
  ];

  String _searchQuery = '';
  String _selectedMateriaFilter = 'Todas';
  String _selectedCondicionFilter = 'Todas';

  void _abrirModalSubirAlumnoRite() {
    final nombreCtrl = TextEditingController();
    final cursoCtrl = TextEditingController(text: '3ro B');
    final anioCtrl = TextEditingController(text: '1ro (2025)');
    String selectedMateria = 'Matemática';
    String selectedCondicion = 'Intensifica';
    String selectedRite = 'TED';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF6A4C9C)),
              SizedBox(width: 10),
              Text('Subir Alumno a RITE (Intensifica / Recursa)'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ingresá los datos del niño/a cuya trayectoria escolar se intensifica o recursa en esta materia.', style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 16),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre Completo del Alumno', hintText: 'Ej. Mateo Gonzalez', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cursoCtrl,
                        decoration: const InputDecoration(labelText: 'Curso Actual', hintText: 'Ej. 3ro B', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: anioCtrl,
                        decoration: const InputDecoration(labelText: 'Año Origen', hintText: 'Ej. 1ro (2025)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedMateria,
                  decoration: const InputDecoration(labelText: 'Materia RITE', border: OutlineInputBorder()),
                  items: ['Matemática', 'Prácticas del Lenguaje', 'Ciencias Naturales', 'Ciencias Sociales', 'Historia', 'Geografía', 'Inglés', 'Biología', 'Física', 'Química']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedMateria = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCondicion,
                  decoration: const InputDecoration(labelText: 'Condición Pedagógica RITE', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: 'Intensifica', child: Text('⚡ INTENSIFICA (Intensificación RITE)')),
                    const DropdownMenuItem(value: 'Recursa', child: Text('🔄 RECURSA (Recursado de Materia)')),
                    const DropdownMenuItem(value: 'Adeuda Previa', child: Text('📌 ADEUDA PREVIA (Años Anteriores)')),
                  ],
                  onChanged: (v) => setModalState(() => selectedCondicion = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRite,
                  decoration: const InputDecoration(labelText: 'Estado RITE Inicial', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'TED', child: Text('🔴 TED - Trayectoria Educativa Discontinua')),
                    DropdownMenuItem(value: 'EP', child: Text('🟡 TEP/EP - En Proceso / Periodo Complementario')),
                    DropdownMenuItem(value: 'TEA', child: Text('🟢 TEA - Trayectoria Educativa Avanzada')),
                  ],
                  onChanged: (v) => setModalState(() => selectedRite = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A4C9C), foregroundColor: Colors.white),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Subir Alumno a RITE'),
              onPressed: () {
                if (nombreCtrl.text.trim().isEmpty) return;
                setState(() {
                  _adeudadas.insert(0, {
                    'alumno': nombreCtrl.text.trim(),
                    'curso': cursoCtrl.text.trim().isEmpty ? '3ro A' : cursoCtrl.text.trim(),
                    'materia': selectedMateria,
                    'anio_cursada': anioCtrl.text.trim().isEmpty ? '2025' : anioCtrl.text.trim(),
                    'condicion': selectedCondicion,
                    'estado_rite': selectedRite,
                    'nota_coloquio': null,
                  });
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Alumno subido como "$selectedCondicion" en $selectedMateria exitosamente.'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalEditarRite(Map<String, dynamic> item) {
    String selectedRite = item['estado_rite'];
    String selectedCondicion = item['condicion'] ?? 'Adeuda Previa';
    final notaController = TextEditingController(
      text: item['nota_coloquio'] != null ? item['nota_coloquio'].toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Evaluar Materia Adeudada - ${item['alumno']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Materia: ${item['materia']} (${item['anio_cursada']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Condición RITE del Alumno:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  DropdownButtonFormField<String>(
                    value: selectedCondicion,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'Intensifica', child: Text('⚡ INTENSIFICA')),
                      DropdownMenuItem(value: 'Recursa', child: Text('🔄 RECURSA')),
                      DropdownMenuItem(value: 'Adeuda Previa', child: Text('📌 ADEUDA PREVIA')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCondicion = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Estado de RITE Actual:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: selectedRite,
                    isExpanded: true,
                    items: ['TED', 'EP', 'TEA'].map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(val == 'TED'
                            ? 'TED (Trayectoria Discontinua)'
                            : val == 'EP'
                                ? 'EP (En Proceso / TEP)'
                                : 'TEA (Aprobada / Avanzada)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedRite = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notaController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Nota de Coloquio / Examen (Opcional)',
                      hintText: 'Ej. 7.5',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A4C9C)),
                  onPressed: () {
                    setState(() {
                      item['condicion'] = selectedCondicion;
                      item['estado_rite'] = selectedRite;
                      item['nota_coloquio'] = double.tryParse(notaController.text);
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('RITE de materia actualizado exitosamente')),
                    );
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _imprimirAdeudadas() {
    final rowsHtml = _adeudadas.map((item) {
      final riteClass = item['estado_rite'] == 'TEA'
          ? 'badge-green'
          : item['estado_rite'] == 'EP'
              ? 'badge-blue'
              : 'badge-red';
      return '''
        <tr>
          <td>${item['alumno']}</td>
          <td>${item['curso']}</td>
          <td>${item['materia']}</td>
          <td>${item['anio_cursada']}</td>
          <td><b>${item['condicion'] ?? 'Adeuda Previa'}</b></td>
          <td><span class="badge $riteClass">${item['estado_rite']}</span></td>
          <td>${item['nota_coloquio'] ?? '-'}</td>
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
            <th>Estado RITE</th>
            <th>Nota Coloquio</th>
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
    final materiasDisponibles = ['Todas', 'Matemática', 'Prácticas del Lenguaje', 'Ciencias Naturales', 'Ciencias Sociales', 'Historia', 'Geografía', 'Inglés', 'Biología', 'Física', 'Química'];
    final condicionesDisponibles = ['Todas', 'Intensifica', 'Recursa', 'Adeuda Previa'];

    final filtered = _adeudadas.where((item) {
      final q = _searchQuery.toLowerCase();
      final coincideBusqueda = item['alumno'].toString().toLowerCase().contains(q) ||
          item['materia'].toString().toLowerCase().contains(q);
      final coincideMateria = _selectedMateriaFilter == 'Todas' || item['materia'] == _selectedMateriaFilter;
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
            onPressed: _imprimirAdeudadas,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
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
                    decoration: InputDecoration(
                      labelText: 'Condición (Intensifica/Recursa)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: condicionesDisponibles.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
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
                          const Text('No hay alumnos registrados con ese criterio de búsqueda o filtro.', style: TextStyle(fontSize: 16, color: Colors.black54)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final String state = item['estado_rite'] ?? 'TED';
                        final String condicion = item['condicion'] ?? 'Adeuda Previa';

                        final Color chipColor = state == 'TEA'
                            ? Colors.green
                            : state == 'EP'
                                ? Colors.blue
                                : Colors.red;

                        final Color condColor = condicion == 'Intensifica'
                            ? Colors.deepPurple
                            : condicion == 'Recursa'
                                ? Colors.orange.shade800
                                : Colors.teal.shade700;

                        final String condIcon = condicion == 'Intensifica'
                            ? '⚡ INTENSIFICA'
                            : condicion == 'Recursa'
                                ? '🔄 RECURSA'
                                : '📌 ADEUDA PREVIA';

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
                              child: Icon(
                                condicion == 'Intensifica'
                                    ? Icons.bolt_rounded
                                    : condicion == 'Recursa'
                                        ? Icons.refresh_rounded
                                        : Icons.bookmarks_rounded,
                                color: condColor,
                                size: 28,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text('${item['alumno']} (${item['curso']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(color: condColor.withAlpha(25), borderRadius: BorderRadius.circular(8), border: Border.all(color: condColor)),
                                  child: Text(condIcon, style: TextStyle(color: condColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('Materia: ${item['materia']} | Año Cursada: ${item['anio_cursada']} \nNota Coloquio: ${item['nota_coloquio'] ?? "Pendiente de evaluación"}', style: const TextStyle(height: 1.3)),
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: chipColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    state,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.edit_rounded, color: Colors.grey),
                              ],
                            ),
                            onTap: () => _abrirModalEditarRite(item),
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
