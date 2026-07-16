import 'package:flutter/material.dart';
import '../services/print_helper.dart';
import '../services/supabase_service.dart';
import '../widgets/app_drawer.dart';

class PanelLibroActas extends StatefulWidget {
  final String? rolUsuario;
  final String? nombreUsuario;
  const PanelLibroActas({super.key, this.rolUsuario, this.nombreUsuario});

  @override
  State<PanelLibroActas> createState() => _PanelLibroActasState();
}

class _PanelLibroActasState extends State<PanelLibroActas> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _actas = [];
  List<Map<String, dynamic>> _cursos = [];
  bool _loading = true;

  String _searchQuery = '';
  String _selectedCategoria = 'TODAS';
  String _selectedCursoId = 'TODOS';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _loading = true);
    try {
      final cursosList = await _supabaseService.fetchCursos();
      _cursos = cursosList;
      await _cargarActas();
    } catch (e) {
      print('Error cargando datos de actas: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cargarActas() async {
    setState(() => _loading = true);
    try {
      final list = await _supabaseService.obtenerActas(
        categoria: _selectedCategoria,
        cursoId: _selectedCursoId,
        rol: widget.rolUsuario ?? 'PRECEPTOR',
        nombreUsuario: widget.nombreUsuario,
      );
      if (mounted) {
        setState(() {
          _actas = list;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error cargando actas: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _abrirModalNuevaActa() {
    final tituloController = TextEditingController();
    final contenidoController = TextEditingController();
    final participantesController = TextEditingController(text: widget.nombreUsuario ?? '');
    String modalCategoria = 'ACADEMICAS';
    String? modalCursoId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.edit_document, color: Color(0xFF6A4C9C)),
                  SizedBox(width: 10),
                  Text('Redactar Nueva Acta Digital'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: tituloController,
                        decoration: InputDecoration(
                          labelText: 'Título del Acta',
                          hintText: 'Ej. Acta de Acuerdo Académico / Disciplinario',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: modalCategoria,
                              decoration: InputDecoration(
                                labelText: 'Categoría',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'ACADEMICAS', child: Text('Académicas')),
                                DropdownMenuItem(value: 'ACCIDENTES', child: Text('Accidentes / Disciplina')),
                                DropdownMenuItem(value: 'REUNIONES', child: Text('Reuniones')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => modalCategoria = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: modalCursoId,
                              decoration: InputDecoration(
                                labelText: 'Curso Asociado',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('General / Institucional')),
                                ..._cursos.map((c) => DropdownMenuItem<String?>(
                                      value: c['curso_id'] as String,
                                      child: Text(c['identificador_division']?.toString() ?? 'Curso'),
                                    )),
                              ],
                              onChanged: (val) => setModalState(() => modalCursoId = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: participantesController,
                        decoration: InputDecoration(
                          labelText: 'Participantes / Presentes',
                          hintText: 'Ej. Directora Laura, Preceptor Marcos, Docente Gómez',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: contenidoController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Contenido / Resoluciones y Compromisos',
                          hintText: 'Escriba aquí los detalles acordados en la reunión o los hechos registrados...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
                    backgroundColor: const Color(0xFF6A4C9C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () async {
                    if (tituloController.text.isNotEmpty && contenidoController.text.isNotEmpty) {
                      try {
                        await _supabaseService.crearActa(
                          titulo: tituloController.text.trim(),
                          categoria: modalCategoria,
                          cursoId: modalCursoId,
                          contenido: contenidoController.text.trim(),
                          participantes: participantesController.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Acta digital guardada exitosamente en la base de datos'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _cargarActas();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al guardar acta: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Guardar Acta'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _firmarActa(Map<String, dynamic> acta) {
    final nombreController = TextEditingController(text: widget.nombreUsuario ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Firmar Acta Digitalmente'),
          content: TextField(
            controller: nombreController,
            decoration: const InputDecoration(
              labelText: 'Nombre Completo del Firmante',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A4C9C), foregroundColor: Colors.white),
              onPressed: () async {
                if (nombreController.text.isNotEmpty) {
                  try {
                    final firmas = List<String>.from(acta['firmas'] ?? []);
                    await _supabaseService.firmarActa(
                      actaId: acta['acta_id'].toString(),
                      nombreFirmante: nombreController.text.trim(),
                      firmasActuales: firmas,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Acta firmada exitosamente'), backgroundColor: Colors.green),
                      );
                      _cargarActas();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al firmar: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              child: const Text('Confirmar Firma'),
            ),
          ],
        );
      },
    );
  }

  void _imprimirActa(Map<String, dynamic> acta) {
    final String htmlBody = '''
      <h2>${acta['titulo']}</h2>
      <p><strong>Categoría:</strong> ${acta['categoria']} | <strong>Fecha:</strong> ${acta['created_at']?.toString().substring(0, 10) ?? 'N/A'}</p>
      <p><strong>Participantes:</strong> ${acta['participantes']}</p>
      <hr/>
      <h3>Contenido y Resoluciones</h3>
      <p style="line-height: 1.6; text-align: justify;">${acta['contenido']}</p>
      <hr style="margin-top: 40px;"/>
      <h3>Firmantes Presentes</h3>
      <ul>
        ${(acta['firmas'] as List? ?? []).isEmpty ? '<li><em>Sin firmas registradas</em></li>' : (acta['firmas'] as List).map((f) => '<li>$f (Firmado Digitalmente)</li>').join('')}
      </ul>
    ''';
    PrintHelper.imprimirHTML(
      titulo: 'Acta Institucional - IA Baradero',
      htmlContentBody: htmlBody,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rol = widget.rolUsuario ?? 'PRECEPTOR';
    final esPersonalAutorizado = rol == 'ADMIN' || rol == 'PRECEPTOR';

    final filteredActas = _actas.where((acta) {
      final query = _searchQuery.toLowerCase();
      final titulo = acta['titulo']?.toString().toLowerCase() ?? '';
      final contenido = acta['contenido']?.toString().toLowerCase() ?? '';
      final participantes = acta['participantes']?.toString().toLowerCase() ?? '';
      return titulo.contains(query) || contenido.contains(query) || participantes.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: AppDrawer.buildLeading(context),
        leadingWidth: AppDrawer.buildLeadingWidth(context),
        title: const Text('Libro de Actas Digital', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Imprimir Libro Completo',
            onPressed: () {
              final String fullHtml = filteredActas.map((acta) {
                return '''
                  <div style="page-break-after: always; border-bottom: 1px double #ccc; padding-bottom: 20px; margin-bottom: 20px;">
                    <h2>${acta['titulo']} [${acta['categoria']}]</h2>
                    <p><strong>Fecha:</strong> ${acta['created_at']?.toString().substring(0, 10) ?? 'N/A'}</p>
                    <p><strong>Participantes:</strong> ${acta['participantes']}</p>
                    <p>${acta['contenido']}</p>
                    <p><strong>Firmas:</strong> ${(acta['firmas'] as List? ?? []).join(', ')}</p>
                  </div>
                ''';
              }).join('');
              PrintHelper.imprimirHTML(
                titulo: 'Libro de Actas Completo - IA Baradero',
                htmlContentBody: fullHtml,
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: esPersonalAutorizado
          ? FloatingActionButton.extended(
              onPressed: _abrirModalNuevaActa,
              backgroundColor: const Color(0xFF6A4C9C),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Redactar Acta', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!esPersonalAutorizado)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded, color: Colors.amber.shade900),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Acceso clasificado: Por su rol ($rol), solo puede ver actas académicas o de reuniones donde participe o pertenezcan a sus cursos. Las actas de accidentes son confidenciales para Administradores y Preceptores.',
                        style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            // Barra de Búsqueda y Filtro de Curso
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar actas por título, contenido o firmantes...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedCursoId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Filtrar por Curso',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'TODOS', child: Text('Todos los Cursos')),
                          ..._cursos.map((c) => DropdownMenuItem(
                                value: c['curso_id'] as String,
                                child: Text(c['identificador_division']?.toString() ?? 'Curso'),
                              )),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCursoId = val);
                            _cargarActas();
                          }
                        },
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar actas por título, contenido o firmantes...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCursoId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Filtrar por Curso',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'TODOS', child: Text('Todos los Cursos')),
                          ..._cursos.map((c) => DropdownMenuItem(
                                value: c['curso_id'] as String,
                                child: Text(c['identificador_division']?.toString() ?? 'Curso'),
                              )),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCursoId = val);
                            _cargarActas();
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            // Chips de Categorías (Académicas, Accidentes, Reuniones)
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                _categoriaChip('TODAS', 'Todas las Actas', Icons.folder_copy_rounded),
                _categoriaChip('ACADEMICAS', 'Académicas', Icons.school_rounded),
                _categoriaChip('ACCIDENTES', 'De Accidentes / Disciplina', Icons.local_hospital_rounded),
                _categoriaChip('REUNIONES', 'De Reuniones', Icons.groups_rounded),
              ],
            ),
            const SizedBox(height: 16),
            // Lista de Actas
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredActas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.document_scanner_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'No se encontraron actas para esta categoría o curso.',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredActas.length,
                          itemBuilder: (context, index) {
                            final acta = filteredActas[index];
                            final firmas = List<String>.from(acta['firmas'] ?? []);
                            final cat = acta['categoria']?.toString() ?? 'GENERAL';
                            Color badgeColor = Colors.blue;
                            if (cat == 'ACCIDENTES') badgeColor = Colors.red.shade700;
                            if (cat == 'REUNIONES') badgeColor = Colors.orange.shade800;
                            if (cat == 'ACADEMICAS') badgeColor = Colors.purple.shade700;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withAlpha(30),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: badgeColor),
                                          ),
                                          child: Text(
                                            cat,
                                            style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            acta['titulo'] ?? 'Sin título',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6A4C9C)),
                                          ),
                                        ),
                                        Text(
                                          acta['created_at']?.toString().substring(0, 10) ?? 'Reciente',
                                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Presentes: ${acta['participantes'] ?? "No especificado"}',
                                      style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      acta['contenido'] ?? '',
                                      style: const TextStyle(fontSize: 14, height: 1.4),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Icon(Icons.verified_outlined, size: 18, color: firmas.isEmpty ? Colors.red : Colors.green.shade700),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            firmas.isEmpty ? 'Sin firmas registradas' : 'Firmado por: ${firmas.join(", ")}',
                                            style: TextStyle(fontSize: 12, color: firmas.isEmpty ? Colors.red : Colors.green.shade800, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _firmarActa(acta),
                                          icon: const Icon(Icons.draw_rounded, size: 16),
                                          label: const Text('Firmar'),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () => _imprimirActa(acta),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF6A4C9C),
                                            foregroundColor: Colors.white,
                                          ),
                                          icon: const Icon(Icons.print_rounded, size: 16),
                                          label: const Text('PDF / Imprimir'),
                                        ),
                                      ],
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
    );
  }

  Widget _categoriaChip(String key, String label, IconData icon) {
    final selected = _selectedCategoria == key;
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(icon, size: 18, color: selected ? Colors.white : const Color(0xFF6A4C9C)),
      label: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : const Color(0xFF6A4C9C))),
      selectedColor: const Color(0xFF6A4C9C),
      backgroundColor: const Color(0xFF6A4C9C).withAlpha(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: selected ? Colors.transparent : const Color(0xFF6A4C9C).withAlpha(60))),
      onSelected: (bool val) {
        setState(() => _selectedCategoria = key);
        _cargarActas();
      },
    );
  }
}
