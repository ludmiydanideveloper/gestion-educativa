import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mensaje.dart';
import '../services/supabase_service.dart';
import 'detalle_mensaje.dart';
import 'portal_familia.dart';
import 'dashboard_preceptor.dart';
import 'panel_alertas.dart';
import 'panel_cobros.dart';
import 'panel_conducta.dart';
import '../widgets/app_drawer.dart';

class BandejaMensajes extends StatefulWidget {
  const BandejaMensajes({super.key});

  @override
  State<BandejaMensajes> createState() => _BandejaMensajesState();
}

class _BandejaMensajesState extends State<BandejaMensajes> {
  final _supabaseService = SupabaseService();
  late Future<List<Mensaje>> _mensajesFuture;

  @override
  void initState() {
    super.initState();
    _cargarMensajes();
  }

  void _cargarMensajes() {
    setState(() {
      _mensajesFuture = _supabaseService.obtenerBandejaEntrada();
    });
  }

  void _abrirModalNuevaConversacion() {
    final formKey = GlobalKey<FormState>();
    final asuntoController = TextEditingController();
    final cuerpoController = TextEditingController();
    String? selectedDestinatarioAuthId;
    List<Map<String, dynamic>> destinatarios = [];
    bool isModalLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (destinatarios.isEmpty) {
              _supabaseService.obtenerDestinatariosTutor().then((val) {
                setModalState(() {
                  destinatarios = val;
                });
              }).catchError((err) {
                print('Error fetching recipients: $err');
              });
            }

            return AlertDialog(
              title: const Text('Iniciar Nueva Conversación'),
              content: isModalLoading
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: selectedDestinatarioAuthId,
                              decoration: const InputDecoration(
                                labelText: 'Destinatario (Profesor/a, Directivo o Preceptor)',
                                helperText: 'Selecciona el docente de la materia de tu hijo/a o directivo',
                              ),
                              items: destinatarios.map((d) {
                                return DropdownMenuItem<String>(
                                  value: d['auth_id'] as String,
                                  child: Text(
                                    '${d['nombre']} (${d['rol']})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              validator: (val) => val == null ? 'Requerido' : null,
                              onChanged: (val) {
                                setModalState(() {
                                  selectedDestinatarioAuthId = val;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: asuntoController,
                              decoration: const InputDecoration(labelText: 'Asunto'),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: cuerpoController,
                              decoration: const InputDecoration(labelText: 'Mensaje'),
                              maxLines: 4,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: isModalLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isModalLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate() || selectedDestinatarioAuthId == null) return;
                          
                          setModalState(() {
                            isModalLoading = true;
                          });

                          try {
                            await _supabaseService.enviarMensajePersonal(
                              destinatarioAuthId: selectedDestinatarioAuthId!,
                              asunto: asuntoController.text.trim(),
                              texto: cuerpoController.text.trim(),
                            );

                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Conversación iniciada con éxito.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _cargarMensajes();
                          } catch (e) {
                            setModalState(() {
                              isModalLoading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al enviar mensaje: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirModalMensajeMasivo() {
    final formKey = GlobalKey<FormState>();
    final asuntoController = TextEditingController();
    final cuerpoController = TextEditingController();
    bool requiereFirma = false;
    bool isModalLoading = false;

    // Estados de filtros masivos
    String selectedDestType = 'ALUMNO'; // ALUMNO o DOCENTE
    String? selectedCursoId; // Para alumnos o docentes por curso
    String selectedDocenteScope = 'TODOS'; // TODOS, CURSO, INDIVIDUAL
    String? selectedDocenteAuthId; // Para docente individual

    List<Map<String, dynamic>> cursos = [];
    List<Map<String, dynamic>> docentes = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Cargar cursos si están vacíos
            if (cursos.isEmpty) {
              _supabaseService.fetchCursos().then((val) {
                setModalState(() {
                  cursos = val;
                });
              }).catchError((err) => print('Error fetching courses: $err'));
            }
            // Cargar docentes si están vacíos
            if (docentes.isEmpty) {
              _supabaseService.fetchPersonalList().then((val) {
                setModalState(() {
                  docentes = val;
                });
              }).catchError((err) => print('Error fetching staff: $err'));
            }

            return AlertDialog(
              title: const Text('Enviar Comunicado Masivo', style: TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: isModalLoading
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Selector de Tipo Principal (Alumnos vs Docentes)
                            DropdownButtonFormField<String>(
                              value: selectedDestType,
                              decoration: const InputDecoration(
                                labelText: 'Grupo Destinatario',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'ALUMNO', child: Text('Alumnos y Familias')),
                                DropdownMenuItem(value: 'DOCENTE', child: Text('Docentes y Personal')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    selectedDestType = val;
                                    selectedCursoId = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // 2. Condicionales según tipo
                            if (selectedDestType == 'ALUMNO') ...[
                              // Dropdown de cursos para alumnos
                              DropdownButtonFormField<String>(
                                value: selectedCursoId,
                                decoration: const InputDecoration(
                                  labelText: 'Curso Destinatario',
                                  helperText: 'Selecciona un curso o envía a toda la escuela',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('Toda la Escuela (Todos)'),
                                  ),
                                  ...cursos.map((c) {
                                    return DropdownMenuItem<String>(
                                      value: c['curso_id'] as String,
                                      child: Text(c['identificador_division'] as String),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setModalState(() {
                                    selectedCursoId = val;
                                  });
                                },
                              ),
                            ] else ...[
                              // Dropdown de alcance para docentes
                              DropdownButtonFormField<String>(
                                value: selectedDocenteScope,
                                decoration: const InputDecoration(
                                  labelText: 'Alcance del Personal',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'TODOS', child: Text('Todos los Docentes')),
                                  DropdownMenuItem(value: 'CURSO', child: Text('Docentes de un Curso')),
                                  DropdownMenuItem(value: 'INDIVIDUAL', child: Text('Docente en particular')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() {
                                      selectedDocenteScope = val;
                                      selectedCursoId = null;
                                      selectedDocenteAuthId = null;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 16),

                              if (selectedDocenteScope == 'CURSO')
                                DropdownButtonFormField<String>(
                                  value: selectedCursoId,
                                  decoration: const InputDecoration(
                                    labelText: 'Seleccionar Curso',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: cursos.map((c) {
                                    return DropdownMenuItem<String>(
                                      value: c['curso_id'] as String,
                                      child: Text(c['identificador_division'] as String),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setModalState(() {
                                      selectedCursoId = val;
                                    });
                                  },
                                  validator: (val) => val == null ? 'Requerido' : null,
                                ),

                              if (selectedDocenteScope == 'INDIVIDUAL')
                                DropdownButtonFormField<String>(
                                  value: selectedDocenteAuthId,
                                  decoration: const InputDecoration(
                                    labelText: 'Seleccionar Docente',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: docentes.map((d) {
                                    return DropdownMenuItem<String>(
                                      value: d['auth_id'] as String?,
                                      child: Text(d['nombre_completo'] as String),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setModalState(() {
                                      selectedDocenteAuthId = val;
                                    });
                                  },
                                  validator: (val) => val == null ? 'Requerido' : null,
                                ),
                            ],
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: asuntoController,
                              decoration: const InputDecoration(labelText: 'Asunto', border: OutlineInputBorder()),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: cuerpoController,
                              decoration: const InputDecoration(labelText: 'Mensaje', border: OutlineInputBorder()),
                              maxLines: 4,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              title: const Text('Requiere acuse/firma del tutor'),
                              value: requiereFirma,
                              onChanged: (val) {
                                setModalState(() {
                                  requiereFirma = val ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: isModalLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isModalLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          setModalState(() {
                            isModalLoading = true;
                          });

                          try {
                            if (selectedDestType == 'DOCENTE' && selectedDocenteScope == 'INDIVIDUAL') {
                              // Enviar a docente particular
                              await _supabaseService.enviarMensajePersonal(
                                destinatarioAuthId: selectedDocenteAuthId!,
                                asunto: asuntoController.text.trim(),
                                texto: cuerpoController.text.trim(),
                              );
                            } else {
                              // Enviar masivo general, por curso, o todos los docentes
                              await _supabaseService.enviarMensajeMasivo(
                                asunto: asuntoController.text.trim(),
                                texto: cuerpoController.text.trim(),
                                requiereFirma: requiereFirma,
                                cursoId: selectedCursoId,
                              );
                            }

                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Comunicado enviado con éxito.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _cargarMensajes();
                          } catch (e) {
                            setModalState(() {
                              isModalLoading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al enviar comunicado: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = Supabase.instance.client.auth.currentUser;
    final rol = user?.userMetadata?['rol'] as String?;

    return Scaffold(
      appBar: AppBar(
        leading: AppDrawer.buildLeading(context),
        leadingWidth: AppDrawer.buildLeadingWidth(context),
        title: const Text(
          'Cuaderno Digital',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar bandeja',
            onPressed: _cargarMensajes,
          ),
        ],
      ),
      drawer: AppDrawer(rolOverride: rol),
      body: FutureBuilder<List<Mensaje>>(
        future: _mensajesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 64.0),
                    const SizedBox(height: 16.0),
                    Text(
                      'Error al cargar el cuaderno digital.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      snapshot.error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24.0),
                    ElevatedButton.icon(
                      onPressed: _cargarMensajes,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final mensajes = snapshot.data ?? [];
          if (mensajes.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _cargarMensajes(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          size: 72.0,
                          color: colorScheme.onSurfaceVariant.withAlpha(102),
                        ),
                        const SizedBox(height: 20.0),
                        Text(
                          'Bandeja de entrada vacía',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          'No tienes comunicados institucionales pendientes.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant.withAlpha(178),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _cargarMensajes(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              itemCount: mensajes.length,
              itemBuilder: (context, index) {
                final mensaje = mensajes[index];
                final esLeido = mensaje.esLeido;

                // Formateo de fecha y hora
                final fecha = mensaje.fechaCreacion.toLocal();
                final fechaStr = "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}";
                final horaStr = "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}";

                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  color: esLeido 
                      ? colorScheme.surface
                      : const Color(0xFFF8FAFC), // Fila destacada para no leídos
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: BorderSide(
                      color: esLeido 
                          ? const Color(0xFFE2E8F0)
                          : colorScheme.primary.withAlpha(80),
                      width: 1.0,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.0),
                    onTap: () async {
                      // Navegar a detalles y esperar retorno para recargar bandeja
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DetalleMensaje(mensaje: mensaje),
                        ),
                      );
                      _cargarMensajes();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Indicador de Leído/No Leído
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0, right: 16.0),
                            child: Icon(
                              esLeido ? Icons.mail_outline_rounded : Icons.mail_rounded,
                              color: esLeido ? const Color(0xFF94A3B8) : colorScheme.primary,
                              size: 22.0,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "$fechaStr a las $horaStr hs",
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: const Color(0xFF64748B),
                                            fontWeight: esLeido ? FontWeight.normal : FontWeight.w600,
                                          ),
                                    ),
                                    if (mensaje.requiereFirma)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(6.0),
                                          border: Border.all(color: const Color(0xFFFCA5A5)),
                                        ),
                                        child: const Text(
                                          'Firma Req.',
                                          style: TextStyle(
                                            color: Color(0xFF991B1B),
                                            fontSize: 9.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  mensaje.asunto,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: esLeido ? FontWeight.w600 : FontWeight.w800,
                                        color: esLeido ? const Color(0xFF0F172A) : colorScheme.primary,
                                        fontSize: 15.0,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  mensaje.cuerpo['texto']?.toString() ?? 'Sin contenido de texto',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: const Color(0xFF475569),
                                        fontWeight: esLeido ? FontWeight.normal : FontWeight.w500,
                                        fontSize: 13.5,
                                        height: 1.4,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: (rol == 'PRECEPTOR' || rol == 'ADMIN')
          ? FloatingActionButton.extended(
              onPressed: _abrirModalMensajeMasivo,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Comunicado Masivo'),
            )
          : (rol == 'PADRE' || rol == 'ALUMNO' || rol == 'DOCENTE')
              ? FloatingActionButton.extended(
                  onPressed: _abrirModalNuevaConversacion,
                  icon: const Icon(Icons.add_comment_rounded),
                  label: const Text('Nueva conversación'),
                )
              : null,
    );
  }
}
