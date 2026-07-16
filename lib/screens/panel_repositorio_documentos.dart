import 'package:flutter/material.dart';
import '../services/print_helper.dart';

class PanelRepositorioDocumentos extends StatefulWidget {
  const PanelRepositorioDocumentos({super.key});

  @override
  State<PanelRepositorioDocumentos> createState() => _PanelRepositorioDocumentosState();
}

class _PanelRepositorioDocumentosState extends State<PanelRepositorioDocumentos> {
  final List<Map<String, dynamic>> _documentos = [
    {
      'titulo': 'Planificación Anual de Matemática - 3ro A',
      'categoria': 'Planificación Anual',
      'subido_por': 'Florencia Viero (Docente)',
      'fecha': '2026-03-10',
      'version': 'v1.2',
      'estado': 'Aprobado',
    },
    {
      'titulo': 'Contrato Pedagógico de Ciencias Naturales - 2do B',
      'categoria': 'Contrato Pedagógico',
      'subido_por': 'Danilo Gomez (Docente)',
      'fecha': '2026-03-15',
      'version': 'v1.0',
      'estado': 'Aprobado',
    },
    {
      'titulo': 'Planificación de Taller de Robótica - Ciclo Básico',
      'categoria': 'Planificación Especial',
      'subido_por': 'Mar Marcos (Preceptor)',
      'fecha': '2026-07-02',
      'version': 'v1.0',
      'estado': 'Pendiente',
    },
  ];

  String _searchQuery = '';

  void _abrirModalSubirDocumento() {
    final tituloController = TextEditingController();
    String selectedCategoria = 'Planificación Anual';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.upload_file_rounded, color: Color(0xFF6A4C9C)),
                  SizedBox(width: 8),
                  Text('Subir Documento'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tituloController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Documento',
                      hintText: 'Ej. Planificación Anual Lengua 1ro',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategoria,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: ['Planificación Anual', 'Contrato Pedagógico', 'Planificación Especial', 'Programa de Examen']
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedCategoria = val);
                      }
                    },
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
                    if (tituloController.text.isNotEmpty) {
                      setState(() {
                        _documentos.insert(0, {
                          'titulo': tituloController.text,
                          'categoria': selectedCategoria,
                          'subido_por': 'Personal IA Baradero',
                          'fecha': DateTime.now().toIso8601String().substring(0, 10),
                          'version': 'v1.0',
                          'estado': 'Pendiente',
                        });
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Documento cargado al repositorio con éxito')),
                      );
                    }
                  },
                  child: const Text('Subir Archivo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _imprimirListaDocumentos() {
    final rowsHtml = _documentos.map((doc) {
      final stateClass = doc['estado'] == 'Aprobado' ? 'badge-green' : 'badge-red';
      return '''
        <tr>
          <td>${doc['titulo']}</td>
          <td>${doc['categoria']}</td>
          <td>${doc['subido_por']}</td>
          <td>${doc['fecha']}</td>
          <td>${doc['version']}</td>
          <td><span class="badge $stateClass">${doc['estado']}</span></td>
        </tr>
      ''';
    }).join('');

    final tableHtml = '''
      <h2>Listado de Documentación Institucional Presentada</h2>
      <table>
        <thead>
          <tr>
            <th>Documento</th>
            <th>Categoría</th>
            <th>Presentado Por</th>
            <th>Fecha Presentación</th>
            <th>Versión</th>
            <th>Estado</th>
          </tr>
        </thead>
        <tbody>
          $rowsHtml
        </tbody>
      </table>
    ''';

    PrintHelper.imprimirHTML(
      titulo: 'Repositorio de Documentos - IA Baradero',
      htmlContentBody: tableHtml,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _documentos.where((doc) {
      final q = _searchQuery.toLowerCase();
      return doc['titulo'].toString().toLowerCase().contains(q) ||
          doc['categoria'].toString().toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repositorio de Documentos', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Imprimir listado de documentos',
            onPressed: _imprimirListaDocumentos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirModalSubirDocumento,
        icon: const Icon(Icons.upload_rounded),
        label: const Text('Subir Documento', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar planificaciones o contratos...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No hay documentos cargados.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final String state = doc['estado'];
                        final Color stateColor = state == 'Aprobado' ? Colors.green : Colors.orange;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueGrey.shade50,
                              child: const Icon(Icons.description_rounded, color: Colors.blueGrey),
                            ),
                            title: Text(doc['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Categoría: ${doc['categoria']} | Por: ${doc['subido_por']}\nFecha: ${doc['fecha']} | Versión: ${doc['version']}'),
                            isThreeLine: true,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: stateColor.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: stateColor),
                              ),
                              child: Text(
                                state,
                                style: TextStyle(color: stateColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
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
