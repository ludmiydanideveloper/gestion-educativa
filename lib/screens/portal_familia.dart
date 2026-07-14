import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/print_helper.dart';
import '../widgets/horario_semanal.dart';
import '../widgets/brand_widgets.dart';
import 'bandeja_mensajes.dart';
import 'estado_cuenta.dart';
import 'panel_hijo_familia.dart';

class PortalFamilia extends StatefulWidget {
  const PortalFamilia({super.key});

  @override
  State<PortalFamilia> createState() => _PortalFamiliaState();
}

class _PortalFamiliaState extends State<PortalFamilia> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  
  // Datos del tutor y sus hijos
  List<Map<String, dynamic>> _hijos = [];
  Map<String, dynamic> _perfilTutor = {};

  // Control de la sección activa
  String _activeSection = 'mi_espacio'; // 'mi_espacio', 'conversaciones', 'calendario', 'contenidos', or 'hijo_{id}_{sub}'
  String? _expandedHijoId; // ID del hijo expandido en el menú lateral

  // Firmas de Contenidos por el padre
  bool _criteriosFirmados = false;
  String _criteriosFirmaNombre = '';
  bool _contratoFirmado = false;
  String _contratoFirmaNombre = '';

  // Caché de datos por hijo para optimizar rendimiento
  final Map<String, List<Map<String, dynamic>>> _cacheAsistencias = {};
  final Map<String, List<Map<String, dynamic>>> _cacheCalificaciones = {};
  final Map<String, List<Map<String, dynamic>>> _cacheConducta = {};
  final Map<String, List<Map<String, dynamic>>> _cacheAdeudadas = {};
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _calendarioEventos = [];
  DateTime _selectedCalendarDate = DateTime.now();
  DateTime? _asistenciaFilterDate;

  @override
  void initState() {
    super.initState();
    _cargarPortal();
  }

  Future<void> _cargarPortal() async {
    setState(() => _isLoading = true);
    try {
      // 1. Cargar perfil del tutor y lista de hijos
      final user = _supabaseService.obtenerHijosTutor(); // Retorna los hijos
      final hijos = await user;

      // Si no tiene hijos en base de datos, agregamos mockup Clara y Mora para la demo
      if (hijos.isEmpty) {
        _hijos = [
          {
            'legajo_id': '9273567a-d719-4932-9021-fa64b4dcd179', // Sofía
            'nombre_completo': 'Clara',
            'dni': '45123856',
            'curso_id': '953fc2c3-0737-4ce8-983f-445e67b50f10',
            'curso_name': '1ro A',
            'color': Colors.green.shade700,
          },
          {
            'legajo_id': '65e22a20-4c06-4a8f-a99b-2f1fcfa436ea', // Mateo
            'nombre_completo': 'Mora',
            'dni': '46789123',
            'curso_id': '953fc2c3-0737-4ce8-983f-445e67b50f10',
            'curso_name': '3ro B',
            'color': Colors.orange.shade700,
          }
        ];
      } else {
        _hijos = hijos.map((h) {
          return {
            ...h,
            'color': h['nombre_completo'].toString().contains('Mora') ? Colors.orange.shade700 : Colors.green.shade700,
          };
        }).toList();
      }

      // Obtener categorías de calificaciones
      _categorias = await _supabaseService.obtenerCategoriasCalificaciones();

      // 2. Pre-cargar datos académicos y conductuales de cada hijo
      for (final hijo in _hijos) {
        final id = hijo['legajo_id'] as String;
        final results = await Future.wait([
          _supabaseService.obtenerAsistenciaAlumno(id),
          _supabaseService.obtenerCalificacionesAlumno(id),
          _supabaseService.obtenerConductaAlumno(id),
          _supabaseService.obtenerMateriasAdeudadasAlumno(id),
        ]);

        _cacheAsistencias[id] = results[0];
        _cacheCalificaciones[id] = results[1];
        _cacheConducta[id] = results[2];
        _cacheAdeudadas[id] = results[3];
      }

      // 3. Pre-cargar eventos de calendario
      final Map<String, Map<String, dynamic>> tempEventos = {};
      final eventosGenerales = await _supabaseService.obtenerCalendarioPorCurso(null);
      for (final ev in eventosGenerales) {
        tempEventos[ev['evento_id'] as String] = ev;
      }
      for (final hijo in _hijos) {
        final cursoId = hijo['curso_id'] as String?;
        if (cursoId != null && cursoId.isNotEmpty) {
          final eventosCurso = await _supabaseService.obtenerCalendarioPorCurso(cursoId);
          for (final ev in eventosCurso) {
            tempEventos[ev['evento_id'] as String] = ev;
          }
        }
      }
      _calendarioEventos = tempEventos.values.toList();
      _calendarioEventos.sort((a, b) => (a['fecha'] as String).compareTo(b['fecha'] as String));

      // Obtener perfil del tutor actual
      final curUser = _supabaseService.obtenerMiPerfilAlumno();
      _perfilTutor = await curUser.catchError((_) => <String, dynamic>{});
      
    } catch (e) {
      print('Error al cargar portal de familia: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _obtenerColorSemantico(double totalFaltas) {
    if (totalFaltas < 15.00) {
      return Colors.green.shade700;
    } else if (totalFaltas < 20.00) {
      return Colors.orange.shade700;
    } else {
      return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 1000;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // El menú lateral (Sidebar / Drawer)
    final Widget navigationMenu = _buildNavigationMenu(context, colorScheme);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandLogo(height: 36, showText: false),
            const SizedBox(width: 12.0),
            Text(
              'Portal Familiar - SGE',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                fontSize: 18.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _supabaseService.signOut(),
          ),
        ],
      ),
      drawer: isWide ? null : Drawer(child: navigationMenu),
      body: Row(
        children: [
          if (isWide)
            SizedBox(
              width: 280.0,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: colorScheme.outlineVariant.withAlpha(80),
                    ),
                  ),
                ),
                child: navigationMenu,
              ),
            ),
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: _buildMainContent(colorScheme),
            ),
          ),
        ],
      ),
    );
  }

  // --- CONSTRUCTOR DEL MENÚ DE NAVEGACIÓN ---
  Widget _buildNavigationMenu(BuildContext context, ColorScheme colorScheme) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Cabecera de Identidad del Tutor
        UserAccountsDrawerHeader(
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B), // Slate 800
          ),
          currentAccountPicture: const CircleAvatar(
            backgroundColor: Color(0xFF475569),
            child: Text(
              'MR',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24.0),
            ),
          ),
          accountName: Text(
            _perfilTutor['nombre_completo'] ?? 'Tutor Responsable',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          accountEmail: const Text('Responsable de Pago / Familia'),
        ),

        // 1. Mi Espacio
        _buildMenuTile(
          icon: Icons.speed_rounded,
          title: 'Mi espacio',
          selected: _activeSection == 'mi_espacio',
          onTap: () => setState(() => _activeSection = 'mi_espacio'),
        ),

        // 2. Conversaciones (Cuaderno Digital)
        _buildMenuTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Conversaciones',
          selected: _activeSection == 'conversaciones',
          onTap: () => setState(() => _activeSection = 'conversaciones'),
        ),

        // 3. Calendario
        _buildMenuTile(
          icon: Icons.calendar_month_rounded,
          title: 'Calendario',
          selected: _activeSection == 'calendario',
          onTap: () => setState(() => _activeSection = 'calendario'),
        ),

        // 4. Contenidos
        _buildMenuTile(
          icon: Icons.cloud_queue_rounded,
          title: 'Contenidos',
          selected: _activeSection == 'contenidos',
          onTap: () => setState(() => _activeSection = 'contenidos'),
        ),

        const Divider(height: 20.0, indent: 16.0, endIndent: 16.0),

        // Secciones dinámicas unificadas por hijo (Clara y Mora)
        for (final hijo in _hijos) ...[
          ExpansionTile(
            leading: Icon(Icons.person_pin_rounded, color: hijo['color'] as Color?),
            title: Text(
              hijo['nombre_completo'] ?? 'Alumno',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            initiallyExpanded: _expandedHijoId == hijo['legajo_id'],
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedHijoId = hijo['legajo_id'] as String;
                } else {
                  _expandedHijoId = null;
                }
              });
            },
            children: [
              _buildSubMenuTile(
                title: 'Asistencia',
                section: 'hijo_${hijo['legajo_id']}_asistencia',
                icon: Icons.analytics_rounded,
                color: hijo['color'] as Color,
              ),
              _buildSubMenuTile(
                title: 'Boletín RITE',
                section: 'hijo_${hijo['legajo_id']}_boletin',
                icon: Icons.assignment_rounded,
                color: Colors.indigo,
              ),
              _buildSubMenuTile(
                title: 'Evaluaciones',
                section: 'hijo_${hijo['legajo_id']}_evaluaciones',
                icon: Icons.fact_check_rounded,
                color: Colors.red,
              ),
              _buildSubMenuTile(
                title: 'Convivencia',
                section: 'hijo_${hijo['legajo_id']}_convivencia',
                icon: Icons.gavel_rounded,
                color: Colors.amber.shade900,
              ),
              _buildSubMenuTile(
                title: 'Adeudadas',
                section: 'hijo_${hijo['legajo_id']}_adeudadas',
                icon: Icons.bookmark_added_rounded,
                color: Colors.teal,
              ),
            ],
          ),
        ],

        const Divider(height: 20.0),
        
        _buildMenuTile(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Estado de Cuenta',
          selected: _activeSection == 'estado_cuenta',
          onTap: () {
            setState(() {
              _activeSection = 'estado_cuenta';
            });
          },
        ),
        _buildMenuTile(
          icon: Icons.mark_email_read_rounded,
          title: 'Trámites y Constancias',
          selected: _activeSection == 'tramites',
          onTap: () {
            setState(() {
              _activeSection = 'tramites';
            });
          },
        ),
        const Divider(),
        const BrandFrankiaFooter(scale: 0.75),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSubMenuTile({
    required String title,
    required String section,
    required IconData icon,
    required Color color,
  }) {
    final selected = _activeSection == section;
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: ListTile(
        leading: Icon(icon, color: selected ? color : color.withAlpha(140), size: 18),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? color : const Color(0xFF475569),
          ),
        ),
        selected: selected,
        selectedTileColor: color.withAlpha(20),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        onTap: () {
          setState(() {
            _activeSection = section;
          });
        },
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: selected ? Colors.indigo.shade700 : (iconColor ?? const Color(0xFF64748B))),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? Colors.indigo.shade700 : const Color(0xFF334155),
        ),
      ),
      selected: selected,
      selectedTileColor: Colors.indigo.shade50.withAlpha(127),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
      onTap: onTap,
    );
  }

  // --- CONSTRUCTOR DE CONTENIDO CENTRAL ---
  Widget _buildMainContent(ColorScheme colorScheme) {
    if (_activeSection == 'mi_espacio') {
      return _buildSectionMiEspacio(colorScheme);
    } else if (_activeSection == 'conversaciones') {
      return const BandejaMensajes(); // Renderizar bandeja de entrada de comunicados
    } else if (_activeSection == 'calendario') {
      return _buildSectionCalendario(colorScheme);
    } else if (_activeSection == 'contenidos') {
      return _buildSectionContenidos(colorScheme);
    } else if (_activeSection == 'estado_cuenta') {
      return const EstadoCuenta();
    } else if (_activeSection == 'tramites') {
      return _buildSectionTramites(colorScheme);
    } else if (_activeSection.startsWith('hijo_')) {
      final parts = _activeSection.split('_');
      final hijoId = parts[1];
      final subSection = parts[2];
      
      final hijo = _hijos.firstWhere((h) => h['legajo_id'] == hijoId, orElse: () => {});
      if (hijo.isEmpty) return const Center(child: Text('Alumno no encontrado.'));

      switch (subSection) {
        case 'asistencia':
          return _buildHijoAsistencia(hijo, colorScheme);
        case 'boletin':
          return _buildHijoBoletin(hijo, colorScheme);
        case 'evaluaciones':
          return _buildHijoEvaluaciones(hijo, colorScheme);
        case 'convivencia':
          return _buildHijoConvivencia(hijo, colorScheme);
        case 'adeudadas':
          return _buildHijoAdeudadas(hijo, colorScheme);
        default:
          return const Center(child: Text('Sección de alumno no encontrada.'));
      }
    }

    return const Center(child: Text('Sección no encontrada.'));
  }

  Widget _buildSectionTramites(ColorScheme colorScheme) {
    Map<String, dynamic>? hijoSeleccionado = _hijos.isNotEmpty ? _hijos.first : null;
    return StatefulBuilder(
      builder: (context, setTramitesState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.mark_email_read_rounded, size: 36, color: Colors.deepPurple),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Trámites y Constancias Oficiales', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                        Text('Solicite constancias de alumno regular y otros documentos. El administrador recibirá la notificación para aprobarlos.', style: TextStyle(fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Solicitar Nueva Constancia de Alumno Regular', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Map<String, dynamic>>(
                              value: hijoSeleccionado,
                              decoration: InputDecoration(
                                labelText: 'Seleccione Hijo/a para el Trámite',
                                prefixIcon: const Icon(Icons.person_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _hijos.map((h) => DropdownMenuItem(value: h, child: Text(h['nombre_completo'] ?? 'Alumno/a'))).toList(),
                              onChanged: (v) => setTramitesState(() => hijoSeleccionado = v),
                            ),
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('SOLICITAR A ADMINISTRACIÓN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            onPressed: () async {
                              if (hijoSeleccionado == null) return;
                              try {
                                await Supabase.instance.client.from('tramites_solicitudes').insert({
                                  'alumno_id': hijoSeleccionado!['legajo_id'] ?? '',
                                  'alumno_nombre': hijoSeleccionado!['nombre_completo'] ?? 'Alumno',
                                  'dni': hijoSeleccionado!['dni']?.toString() ?? 'DNI',
                                  'curso_nombre': hijoSeleccionado!['curso_nombre'] ?? '1ro A',
                                  'tipo_tramite': 'Constancia de Alumno Regular',
                                  'estado': 'PENDIENTE',
                                  'tutor_email': Supabase.instance.client.auth.currentUser?.email ?? 'padre@colegio.com',
                                });
                                // Notificación a administración en adm_notificaciones
                                await Supabase.instance.client.from('adm_notificaciones').insert({
                                  'titulo': '📄 Nueva Solicitud de Constancia de Alumno Regular',
                                  'mensaje': 'El tutor del alumno/a ${hijoSeleccionado!["nombre_completo"]} ha solicitado una constancia regular.',
                                  'tipo': 'TRAMITE',
                                  'leido': false,
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('✅ Solicitud enviada exitosamente al Administrador.'), backgroundColor: Colors.green),
                                  );
                                }
                                setTramitesState(() {});
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error al solicitar: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text('Historial y Estado de Trámites Solicitados:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: Supabase.instance.client
                    .from('tramites_solicitudes')
                    .select('*')
                    .order('fecha_solicitud', ascending: false)
                    .then((data) => List<Map<String, dynamic>>.from(data)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                  }
                  final solicitudes = snapshot.data ?? [];
                  if (solicitudes.isEmpty) {
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('Aún no ha solicitado ninguna constancia en este ciclo lectivo.', style: TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: solicitudes.length,
                    itemBuilder: (ctx, idx) {
                      final s = solicitudes[idx];
                      final estado = s['estado'] ?? 'PENDIENTE';
                      final esEmitido = estado == 'EMITIDO';
                      final alumnoNom = s['alumno_nombre'] ?? '-';
                      final cursoNom = s['curso_nombre'] ?? '-';
                      final estadoText = esEmitido ? 'EMITIDO Y APROBADO POR DIRECCIÓN' : 'EN TRÁMITE POR ADMINISTRACIÓN';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: esEmitido ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                            child: Icon(esEmitido ? Icons.check_circle_rounded : Icons.pending_actions_rounded, color: esEmitido ? Colors.green : Colors.orange),
                          ),
                          title: Text(s['tipo_tramite'] ?? 'Constancia de Alumno Regular', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Alumno/a: $alumnoNom • Curso: $cursoNom\nEstado actual: $estadoText',
                              style: TextStyle(color: esEmitido ? Colors.green.shade800 : Colors.orange.shade900, fontWeight: esEmitido ? FontWeight.bold : FontWeight.normal),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: esEmitido ? Colors.green.shade700 : Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                                label: Text(esEmitido ? 'DESCARGAR CONSTANCIA PDF' : 'VISTA PREVIA / IMPRIMIR', style: const TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  PrintHelper.imprimirConstanciaAlumnoRegular(
                                    studentName: s['alumno_nombre'] ?? 'Alumno/a',
                                    dni: s['dni'] ?? 'Sin DNI',
                                    cursoName: s['curso_nombre'] ?? '1ro A',
                                    codigoVerificacion: s['id']?.toString().substring(0, 8).toUpperCase(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 1. Sección: Mi Espacio (Resumen Ejecutivo de Clara y Mora)
  Widget _buildSectionMiEspacio(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen Familiar',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 8.0),
          const Text(
            'Visualiza de un vistazo la situación general de tus hijas Clara y Mora.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 32.0),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final hijo in _hijos) ...[
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.only(right: 16.0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.0),
                      side: BorderSide(color: Colors.grey.withAlpha(51)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: (hijo['color'] as Color).withAlpha(30),
                                child: Icon(Icons.face_3_rounded, color: hijo['color'] as Color),
                              ),
                              const SizedBox(width: 12.0),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hijo['nombre_completo'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
                                  ),
                                  Text(
                                    hijo['curso_name'] as String,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.0),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 32.0),

                          // Progreso Académico
                          const Text(
                            'Progreso del Proceso Académico:',
                            style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 6.0),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: 0.82,
                                  backgroundColor: Colors.grey.shade200,
                                  color: Colors.indigo,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              const Text('82%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0, color: Colors.indigo)),
                            ],
                          ),
                          const SizedBox(height: 16.0),

                          // Resumen de asistencia
                          _buildSummaryRow(
                            Icons.calendar_today_rounded,
                            'Inasistencias Acumuladas:',
                            _calcularTotalInasistencias(hijo['legajo_id'] as String).toStringAsFixed(2),
                            hijo['color'] as Color,
                          ),
                          const SizedBox(height: 12.0),

                          // Resumen de calificaciones
                          _buildSummaryRow(
                            Icons.analytics_rounded,
                            'Calificación Promedio RITE:',
                            _calcularPromedioGeneral(hijo['legajo_id'] as String),
                            Colors.indigo,
                          ),
                          const SizedBox(height: 12.0),

                          // Resumen de incidencias conductuales
                          _buildSummaryRow(
                            Icons.forum_rounded,
                            'Sanciones / Observaciones:',
                            '${_cacheConducta[hijo['legajo_id']]?.length ?? 0} registros',
                            Colors.red,
                          ),
                          const SizedBox(height: 24.0),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _expandedHijoId = hijo['legajo_id'] as String;
                                  _activeSection = 'hijo_${hijo['legajo_id']}_asistencia';
                                });
                              },
                              child: const Text('Ver Expediente Académico'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16.0, color: color),
            const SizedBox(width: 8.0),
            Text(label, style: const TextStyle(fontSize: 13.0, color: Color(0xFF475569))),
          ],
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0, color: color),
        ),
      ],
    );
  }

  double _calcularTotalInasistencias(String hijoId) {
    final asistencias = _cacheAsistencias[hijoId] ?? [];
    double sum = 0.0;
    for (final a in asistencias) {
      sum += double.tryParse(a['valor_inasistencia'].toString()) ?? 0.0;
    }
    return sum;
  }

  String _calcularPromedioGeneral(String hijoId) {
    final calificaciones = _cacheCalificaciones[hijoId] ?? [];
    if (calificaciones.isEmpty) return 'Sin notas';
    
    double sum = 0.0;
    int count = 0;
    for (final c in calificaciones) {
      if (c['nota_numerica'] != null) {
        sum += (c['nota_numerica'] as num).toDouble();
        count++;
      }
    }
    return count > 0 ? (sum / count).toStringAsFixed(1) : 'Sin notas';
  }

  // 2. Sección: Calendario (Actividades y Feriados)
  Widget _buildSectionCalendario(ColorScheme colorScheme) {
    final dateStr = "${_selectedCalendarDate.year}-${_selectedCalendarDate.month.toString().padLeft(2, '0')}-${_selectedCalendarDate.day.toString().padLeft(2, '0')}";
    final eventosDelDia = _calendarioEventos.where((ev) => ev['fecha'].toString() == dateStr).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Calendario Escolar',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24.0, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8.0),
          const Text(
            'Visualiza las actividades institucionales, evaluaciones y reuniones agendadas.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24.0),
          
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: BorderSide(color: Colors.grey.withAlpha(51)),
            ),
            child: CalendarDatePicker(
              initialDate: _selectedCalendarDate,
              firstDate: DateTime(2026, 1, 1),
              lastDate: DateTime(2026, 12, 31),
              onDateChanged: (date) {
                setState(() {
                  _selectedCalendarDate = date;
                });
              },
            ),
          ),
          const SizedBox(height: 24.0),
          
          Text(
            'Actividades del ${_selectedCalendarDate.day}/${_selectedCalendarDate.month}/${_selectedCalendarDate.year}:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12.0),

          eventosDelDia.isEmpty
              ? Card(
                  elevation: 0,
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: BorderSide(color: Colors.grey.withAlpha(30)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No hay actividades registradas para este día.',
                        style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                )
              : Column(
                  children: eventosDelDia.map((ev) => _buildEventRow(ev)).toList(),
                ),

          const SizedBox(height: 32.0),
          const Text(
            'Todos los Eventos Programados:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12.0),

          _calendarioEventos.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('No hay eventos programados en la agenda.')),
                  ),
                )
              : Column(
                  children: _calendarioEventos.map((ev) => _buildEventRow(ev)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildEventRow(Map<String, dynamic> ev) {
    final tipo = ev['tipo_evento']?.toString() ?? 'ACTIVIDAD';
    final titulo = ev['titulo']?.toString() ?? '';
    final desc = ev['descripcion']?.toString() ?? '';
    final fecha = ev['fecha']?.toString() ?? '';
    
    String fechaLegible = fecha;
    try {
      final pts = fecha.split('-');
      fechaLegible = "${pts[2]}/${pts[1]}/${pts[0]}";
    } catch (_) {}

    Color color;
    IconData icon;
    switch (tipo) {
      case 'EVALUACION':
        color = Colors.blue.shade700;
        icon = Icons.assignment_rounded;
        break;
      case 'REUNION':
        color = Colors.orange.shade700;
        icon = Icons.groups_rounded;
        break;
      default:
        color = Colors.green.shade700;
        icon = Icons.event_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.withAlpha(30)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(25),
          child: Icon(icon, color: color, size: 20.0),
        ),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$desc\nFecha: $fechaLegible'),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Text(
            tipo,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10.0),
          ),
        ),
      ),
    );
  }

  // 3. Sección: Contenidos Académicos (Materiales de Clase, Profesores y Horarios)
  Widget _buildSectionContenidos(ColorScheme colorScheme) {
    String curso = '1° SEC';
    if (_hijos.isNotEmpty) {
      final primerHijo = _hijos.first;
      final cursoNombre = (primerHijo['curso_nombre'] ?? primerHijo['division'] ?? '') as String;
      if (cursoNombre.contains('1')) curso = '1° SEC';
      else if (cursoNombre.contains('2')) curso = '2° SEC';
      else if (cursoNombre.contains('3')) curso = '3° SEC';
      else if (cursoNombre.contains('4')) curso = '4° SEC';
      else if (cursoNombre.contains('5')) curso = '5° SEC';
      else if (cursoNombre.contains('6')) curso = '6° SEC';
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.calendar_view_week_rounded), text: 'Horario de Clases'),
              Tab(icon: Icon(Icons.drive_folder_upload_rounded), text: 'Criterios y Contratos'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Horario Semanal
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Horario de Clases', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Expanded(child: HorarioSemanal(nombreCurso: curso)),
                    ],
                  ),
                ),
                // Tab 2: Criterios y Contratos con Firma de Leído
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Repositorio de Acuerdos Institucionales',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Por favor, revise y firme los acuerdos pedagógicos del ciclo lectivo.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 24),

                      // Documento 1: Criterios de Evaluacion
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.assignment_rounded, color: colorScheme.primary),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Criterios de Evaluación RITE 2026',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'La valoración pedagógica de cada asignatura se regirá bajo los siguientes porcentajes:\n'
                                '• Evidencias de Proceso (Trabajos prácticos, carpetas, talleres): 60%\n'
                                '• Desempeño Escrito y Oral (Exámenes integradores, defensas): 30%\n'
                                '• Autoevaluación del Estudiante: 10%\n\n'
                                'La nota mínima de aprobación cuatrimestral es de 7.0 (TEA). Calificaciones inferiores a 7.0 implican trayectorias TEP (En proceso) o TED (Discontinua).',
                                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                              ),
                              const Divider(height: 24),
                              if (_criteriosFirmados)
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Firmado de Leído por: $_criteriosFirmaNombre (Tutor/a)',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: () => _mostrarFirmaDialog('criterios'),
                                  icon: const Icon(Icons.draw_rounded),
                                  label: const Text('Firmar de Leído por Padres'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Documento 2: Contrato Pedagogico
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.handshake_rounded, color: colorScheme.primary),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Contrato Pedagógico de Convivencia',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Compromisos de las partes involucradas:\n'
                                '1. Del Estudiante: Mantener una actitud respetuosa frente a pares y docentes, asistir con puntualidad, cuidar los materiales de clase y no utilizar dispositivos móviles sin autorización explícita.\n'
                                '2. Del Tutor: Realizar un seguimiento diario a través del Cuaderno Digital y responder o justificar las inasistencias del alumno en un período menor a 48 horas con el certificado médico correspondiente.',
                                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                              ),
                              const Divider(height: 24),
                              if (_contratoFirmado)
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Firmado de Leído por: $_contratoFirmaNombre (Tutor/a)',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: () => _mostrarFirmaDialog('contrato'),
                                  icon: const Icon(Icons.draw_rounded),
                                  label: const Text('Firmar de Leído por Padres'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarFirmaDialog(String tipoDoc) {
    final nombreCtrl = TextEditingController(text: _perfilTutor['nombre_completo'] ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirmar Firma Digital', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Al hacer clic en Confirmar, usted firma digitalmente de enterado y conforme con el documento descripto.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Firma / Nombre del Tutor',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nombreCtrl.text.trim().isEmpty) return;
                Navigator.of(context).pop();
                setState(() {
                  if (tipoDoc == 'criterios') {
                    _criteriosFirmados = true;
                    _criteriosFirmaNombre = nombreCtrl.text.trim();
                  } else {
                    _contratoFirmado = true;
                    _contratoFirmaNombre = nombreCtrl.text.trim();
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Documento firmado con éxito!'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Confirmar Firma'),
            ),
          ],
        );
      },
    );
  }

  // 4. Sub-Sección Hijo: Asistencias (Real + Print)
  Widget _buildHijoAsistencia(Map<String, dynamic> hijo, ColorScheme colorScheme) {
    final id = hijo['legajo_id'] as String;
    final data = _cacheAsistencias[id] ?? [];
    final totalFaltas = _calcularTotalInasistencias(id);
    final progressColor = _obtenerColorSemantico(totalFaltas);
    final progressPercent = (totalFaltas / 20.00).clamp(0.0, 1.0);

    // Filtrar inasistencias por fecha si hay filtro activo
    List<Map<String, dynamic>> filteredData = data;
    if (_asistenciaFilterDate != null) {
      final filterStr = "${_asistenciaFilterDate!.year}-${_asistenciaFilterDate!.month.toString().padLeft(2, '0')}-${_asistenciaFilterDate!.day.toString().padLeft(2, '0')}";
      filteredData = data.where((item) {
        final cab = item['asistencia_cabecera'] as Map<String, dynamic>?;
        final fecha = cab?['fecha']?.toString() ?? '';
        return fecha == filterStr;
      }).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Asistencias - ${hijo['nombre_completo']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0, color: Color(0xFF0F172A)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  PrintHelper.imprimirAsistencia(
                    studentName: hijo['nombre_completo'],
                    dni: hijo['dni'],
                    cursoName: hijo['curso_name'],
                    asistencias: data,
                  );
                },
                icon: const Icon(Icons.print_rounded),
                label: const Text('Exportar Asistencia'),
                style: ElevatedButton.styleFrom(backgroundColor: progressColor, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24.0),

          // Anillo KPI
          Center(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: progressColor.withAlpha(15),
                borderRadius: BorderRadius.circular(32.0),
                border: Border.all(color: progressColor.withAlpha(51)),
              ),
              child: Column(
                children: [
                  const Text('Límite de Inasistencias de la Alumna', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20.0),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140.0,
                        height: 140.0,
                        child: CircularProgressIndicator(
                          value: progressPercent,
                          strokeWidth: 12.0,
                          backgroundColor: progressColor.withAlpha(38),
                          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        ),
                      ),
                      Text(
                        '${totalFaltas.toStringAsFixed(2)} / 20.00',
                        style: TextStyle(fontWeight: FontWeight.w900, color: progressColor, fontSize: 18.0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32.0),

          // Buscador / Filtro por Fecha
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: BorderSide(color: Colors.grey.withAlpha(51)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                      const SizedBox(width: 12.0),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Buscador por Fecha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0)),
                          Text(
                            _asistenciaFilterDate == null
                                ? 'Mostrando registro histórico completo'
                                : 'Mostrando: ${_asistenciaFilterDate!.day}/${_asistenciaFilterDate!.month}/${_asistenciaFilterDate!.year}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.0),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _asistenciaFilterDate ?? DateTime.now(),
                            firstDate: DateTime(2026, 1, 1),
                            lastDate: DateTime(2026, 12, 31),
                          );
                          if (picked != null) {
                            setState(() {
                              _asistenciaFilterDate = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: const Text('Filtrar Fecha'),
                      ),
                      if (_asistenciaFilterDate != null) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _asistenciaFilterDate = null;
                            });
                          },
                          icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.red),
                          label: const Text('Limpiar', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24.0),

          const Text('Registro Histórico:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
          const SizedBox(height: 12.0),

          filteredData.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text('Sin inasistencias registradas para el período seleccionado.'),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredData.length,
                  itemBuilder: (context, index) {
                    final item = filteredData[index];
                    final valor = double.tryParse(item['valor_inasistencia'].toString()) ?? 0.0;
                    final tipo = item['tipo'].toString();
                    final just = item['estado_justificacion'].toString();
                    final cab = item['asistencia_cabecera'] as Map<String, dynamic>?;
                    final fecha = cab?['fecha']?.toString() ?? '-';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        side: BorderSide(color: Colors.grey.withAlpha(30)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: progressColor.withAlpha(25),
                          child: Icon(Icons.assignment_ind_rounded, color: progressColor, size: 20.0),
                        ),
                        title: Text(tipo, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$fecha • Justificado: $just'),
                        trailing: Text('+$valor', style: TextStyle(fontWeight: FontWeight.bold, color: progressColor)),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // 5. Sub-Sección Hijo: Calificaciones (Seguimiento Materia por Materia)
  Widget _buildHijoCalificaciones(Map<String, dynamic> hijo, ColorScheme colorScheme) {
    final id = hijo['legajo_id'] as String;
    final calificaciones = _cacheCalificaciones[id] ?? [];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 32.0, top: 16.0, right: 32.0),
                child: Text(
                  'Calificaciones y Seguimiento - ${hijo['nombre_completo']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0, color: Color(0xFF0F172A)),
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Notas de Desempeño y TPs'),
                  Tab(text: 'Rúbricas de Criterios'),
                ],
                indicatorColor: Colors.indigo,
                labelColor: Colors.indigo,
                unselectedLabelColor: Colors.grey,
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Panel 1: Notas detalladas
            SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: calificaciones.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text('Sin calificaciones cargadas para esta alumna.')),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Promedios por Categoría
                        _buildCategoryAveragesGrid(calificaciones),
                        const SizedBox(height: 24.0),
                        const Text(
                          'Detalle de Evaluaciones:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 12.0),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: calificaciones.length,
                          itemBuilder: (context, index) {
                            final c = calificaciones[index];
                            final act = c['aca_actividades'] as Map<String, dynamic>?;
                            final nota = c['nota_numerica'] != null ? (c['nota_numerica'] as num).toDouble() : 0.0;
                            final cat = act?['aca_categorias_nota'] as Map<String, dynamic>?;
                            final catName = cat?['nombre'] ?? 'Actividad';
                            final peso = cat?['peso_porcentaje'] ?? 30;

                            Color catColor = Colors.blue;
                            if (catName.contains('Autoevaluación')) {
                              catColor = Colors.orange;
                            } else if (catName.contains('Desempeño')) {
                              catColor = Colors.green;
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                side: BorderSide(color: Colors.grey.withAlpha(30)),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: catColor.withAlpha(25),
                                  child: Icon(Icons.assignment_rounded, color: catColor, size: 20.0),
                                ),
                                title: Text(act?['titulo'] ?? 'Evaluación Académica', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Tipo: $catName ($peso%) • Fecha: ${act?['fecha'] ?? '-'}'),
                                trailing: CircleAvatar(
                                  backgroundColor: nota >= 7.0 ? Colors.green.shade50 : Colors.red.shade50,
                                  child: Text(
                                    nota.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: nota >= 7.0 ? Colors.green.shade700 : Colors.red.shade700,
                                      fontSize: 14.0,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
            ),
            
            // Panel 2: Rúbricas e Información Pedagógica
            SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Criterios de Evaluación y Rúbrica Escolar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8.0),
                  const Text(
                    'El promedio final de cada asignatura se calcula aplicando los siguientes pesos porcentuales a las diferentes dimensiones pedagógicas del alumno.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24.0),

                  _buildRubricCard(
                    'Trabajos Prácticos y Evidencias (TP)',
                    '60%',
                    'Comprende las guías, entregas de trabajos prácticos obligatorios, evaluaciones conceptuales y producciones escritas u orales individuales y grupales.',
                    Colors.blue,
                  ),
                  const SizedBox(height: 12.0),
                  _buildRubricCard(
                    'Desempeño en Clase',
                    '30%',
                    'Evalúa la participación constructiva en el aula, el trabajo colaborativo, la asistencia puntual, el respeto a las normas de convivencia y la dedicación diaria.',
                    Colors.green,
                  ),
                  const SizedBox(height: 12.0),
                  _buildRubricCard(
                    'Autoevaluación del Alumno',
                    '10%',
                    'Un proceso de reflexión donde la alumna analiza honestamente su propio progreso, esfuerzo y compromiso durante el ciclo lectivo.',
                    Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryAveragesGrid(List<Map<String, dynamic>> calificaciones) {
    double sumTp = 0.0, sumDes = 0.0, sumAuto = 0.0;
    int countTp = 0, countDes = 0, countAuto = 0;

    for (final c in calificaciones) {
      final act = c['aca_actividades'] as Map<String, dynamic>?;
      final nota = c['nota_numerica'] != null ? (c['nota_numerica'] as num).toDouble() : 0.0;
      final cat = act?['aca_categorias_nota'] as Map<String, dynamic>?;
      final catName = cat?['nombre'] ?? '';

      if (catName.contains('Autoevaluación')) {
        sumAuto += nota;
        countAuto++;
      } else if (catName.contains('Desempeño')) {
        sumDes += nota;
        countDes++;
      } else {
        sumTp += nota;
        countTp++;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildAverageCard(
            'Trabajos Prácticos (TP)',
            '60%',
            countTp > 0 ? (sumTp / countTp).toStringAsFixed(1) : '-',
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAverageCard(
            'Desempeño',
            '30%',
            countDes > 0 ? (sumDes / countDes).toStringAsFixed(1) : '-',
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAverageCard(
            'Autoevaluación',
            '10%',
            countAuto > 0 ? (sumAuto / countAuto).toStringAsFixed(1) : '-',
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildAverageCard(String label, String weight, String value, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0)),
            const SizedBox(height: 4.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Peso: $weight', style: TextStyle(color: Colors.grey.shade600, fontSize: 11.0)),
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 20.0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRubricCard(String title, String weight, String description, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: Colors.grey.withAlpha(51)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(25),
              child: Icon(Icons.fact_check_rounded, color: color),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0)),
                      Text(
                        'Peso: $weight',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15.0),
                      ),
                    ],
                  ),
                  const Divider(height: 16.0),
                  Text(
                    description,
                    style: const TextStyle(color: Color(0xFF475569), height: 1.4, fontSize: 13.0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 6. Sub-Sección Hijo: Evaluaciones (Exámenes Programados)
  Widget _buildHijoEvaluaciones(Map<String, dynamic> hijo, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cronograma de Evaluaciones - ${hijo['nombre_completo']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 24.0),
          _buildEvaluationRow('Biología', 'Evaluación escrita sobre Sistemas de Órganos', 'Fecha: 03/07/2026', 'Confirmada'),
          _buildEvaluationRow('Matemáticas', 'Examen integrador trimestral', 'Fecha: 08/07/2026', 'Confirmada'),
          _buildEvaluationRow('Inglés', 'Presentación oral sobre proyectos', 'Fecha: 14/07/2026', 'Pendiente de confirmación'),
        ],
      ),
    );
  }

  Widget _buildEvaluationRow(String subject, String title, String date, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.withAlpha(30)),
      ),
      child: ListTile(
        title: Text('$subject - $title', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(date),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: status == 'Confirmada' ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Text(
            status,
            style: TextStyle(color: status == 'Confirmada' ? Colors.green.shade800 : Colors.orange.shade800, fontSize: 10.0, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // 7. Sub-Sección Hijo: Informes evaluativos (Feedback del docente)
  Widget _buildHijoInformes(Map<String, dynamic> hijo, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informes Evaluativos - ${hijo['nombre_completo']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 24.0),
          _buildReportCommentCard(
            'Matemáticas (Prof. Gómez)',
            'Excelente participación en clase. Resuelve las guías analíticas con destreza y asiste puntualmente a las explicaciones grupales.',
            '12 de Junio de 2026',
          ),
          _buildReportCommentCard(
            'Lengua (Prof. Pérez)',
            'Buen desempeño general, aunque debe enfocarse más en las entregas escritas formales de fin de ciclo para consolidar su promedio.',
            '08 de Junio de 2026',
          ),
        ],
      ),
    );
  }

  Widget _buildReportCommentCard(String sender, String comment, String date) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: Colors.grey.withAlpha(51)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(sender, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0)),
                Text(date, style: const TextStyle(color: Colors.grey, fontSize: 11.0)),
              ],
            ),
            const Divider(height: 20.0),
            Text(comment, style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
    );
  }

  void _mostrarDetalleCalificacionesMateria(Map<String, dynamic> hijo, String matName, String matId, List<dynamic> calificaciones) {
    final colorScheme = Theme.of(context).colorScheme;

    final List<Map<String, dynamic>> notasMateria = [];
    for (int i = 0; i < calificaciones.length; i++) {
      final c = calificaciones[i];
      final matIndex = i % 5;
      final mappedMatId = 'm${matIndex + 1}';
      if (mappedMatId == matId) {
        notasMateria.add(Map<String, dynamic>.from(c));
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(matName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text('Historial de Calificaciones de ${hijo['nombre_completo']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: notasMateria.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: Text('Sin calificaciones registradas para esta materia.', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: notasMateria.length,
                    itemBuilder: (context, index) {
                      final item = notasMateria[index];
                      final act = item['aca_actividades'] as Map<String, dynamic>?;
                      final titulo = act?['titulo'] ?? 'Evaluación';
                      final desc = act?['descripcion'] ?? 'Actividad académica';
                      final fecha = act?['fecha_limite'] ?? 'Reciente';
                      final nota = item['nota_numerica'] != null ? (item['nota_numerica'] as num).toDouble() : 7.0;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        color: colorScheme.surfaceVariant.withAlpha(30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(50)),
                        ),
                        child: ListTile(
                          title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('Fecha: $fecha • $desc', style: const TextStyle(fontSize: 11)),
                          trailing: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: (nota >= 7.0 ? Colors.green : Colors.red).withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                nota.toStringAsFixed(1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: nota >= 7.0 ? Colors.green.shade800 : Colors.red.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  // 8. Sub-Sección Hijo: Boletín (Cálculo RITE con Banner de "No Completo")
  Widget _buildHijoBoletin(Map<String, dynamic> hijo, ColorScheme colorScheme) {
    final id = hijo['legajo_id'] as String;
    final calificaciones = _cacheCalificaciones[id] ?? [];
    
    // Mapeo estructurado para RITE
    final Map<String, Map<String, List<double>>> notasPorMateriaYCat = {};
    
    // Generar materias simuladas basadas en la demo
    final List<Map<String, dynamic>> materias = [
      {'materia_id': 'm1', 'nombre_asignatura': 'Matemáticas'},
      {'materia_id': 'm2', 'nombre_asignatura': 'Lengua y Literatura'},
      {'materia_id': 'm3', 'nombre_asignatura': 'Física y Química'},
      {'materia_id': 'm4', 'nombre_asignatura': 'Biología'},
      {'materia_id': 'm5', 'nombre_asignatura': 'Historia'},
    ];

    for (final mat in materias) {
      final matId = mat['materia_id'] as String;
      notasPorMateriaYCat[matId] = {};
      for (final cat in _categorias) {
        final catId = cat['id'] as String;
        notasPorMateriaYCat[matId]![catId] = [];
      }
    }

    // Inyectar algunas calificaciones reales/simuladas
    for (final calif in calificaciones) {
      final act = calif['aca_actividades'] as Map<String, dynamic>?;
      if (act != null) {
        final matIndex = (calificaciones.indexOf(calif) % materias.length);
        final matId = materias[matIndex]['materia_id'] as String;
        final catId = act['categoria_id'] as String?;
        final nota = calif['nota_numerica'] != null ? (calif['nota_numerica'] as num).toDouble() : null;
        if (catId != null && nota != null && notasPorMateriaYCat[matId]!.containsKey(catId)) {
          notasPorMateriaYCat[matId]![catId]!.add(nota);
        }
      }
    }

    final obsTexto = hijo['nombre_completo'].toString().contains('Mora')
        ? 'Mora ha mostrado una actitud muy positiva durante el cuatrimestre, participando activamente de los debates y cumpliendo con todas las actividades especiales. ¡Felicitaciones!'
        : 'Clara ha tenido un desempeño sobresaliente en el área de ciencias y matemática, demostrando gran autonomía en el laboratorio. Se recomienda seguir reforzando la redacción en las entregas de lengua.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Boletín Oficial - ${hijo['nombre_completo']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0, color: Color(0xFF0F172A)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  PrintHelper.imprimirBoletin(
                    studentName: hijo['nombre_completo'],
                    dni: hijo['dni'],
                    cursoName: hijo['curso_name'],
                    materias: materias,
                    calificaciones: calificaciones,
                    categorias: _categorias,
                    observaciones: obsTexto,
                  );
                },
                icon: const Icon(Icons.print_rounded),
                label: const Text('Exportar Boletín'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24.0),

          // Encabezado Institucional de 1° Etapa / Cuatrimestre
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withAlpha(40),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'INFORME DE AVANCE - 1° ETAPA / CUATRIMESTRE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'CICLO LECTIVO 2026',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ALUMNO/A: ${hijo['nombre_completo']} | CURSO: ${hijo['curso_name'] ?? '1° ES'}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_busy_rounded, color: colorScheme.primary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Inasistencias: 0',
                            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24.0),

          // Leyenda Informativa
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(100),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: colorScheme.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Este informe se elabora y actualiza directamente con las calificaciones de evidencias y evaluaciones ponderadas por los docentes del curso en la planilla escolar.',
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20.0),

          // Tabla Oficial del Boletín / Informe de Avance
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: BorderSide(color: Colors.grey.withAlpha(51)),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest),
                dataRowMinHeight: 64,
                dataRowMaxHeight: 80,
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('MATERIA Y DOCENTE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('CRITERIOS CUALITATIVOS', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('TRAYECTORIA (RITE)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('CALIFICACIÓN NUMÉRICA', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('FALTAS*', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ACCIONES', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: materias.map((mat) {
                  final matId = mat['materia_id'] as String;
                  final matName = mat['nombre_asignatura'] as String;

                  double totalPonderado = 0.0;
                  double totalPeso = 0.0;

                  for (final cat in _categorias) {
                    final catId = cat['id'] as String;
                    final peso = (cat['peso_porcentaje'] as num).toDouble();
                    final notas = notasPorMateriaYCat[matId]?[catId] ?? [];
                    
                    if (notas.isNotEmpty) {
                      final promedioCat = notas.reduce((a, b) => a + b) / notas.length;
                      totalPonderado += promedioCat * peso;
                      totalPeso += peso;
                    }
                  }

                  double? notaCierre;
                  if (totalPeso > 0.0) {
                    notaCierre = totalPonderado / totalPeso;
                  }

                  final notaCierreText = notaCierre != null ? notaCierre.toStringAsFixed(1) : '-';

                  String valorRite = 'S/C';
                  Color colorRite = Colors.grey;
                  String cualitativo = 'En Proceso';

                  if (notaCierre != null) {
                    if (notaCierre >= 7.0) {
                      valorRite = 'TEA';
                      colorRite = Colors.green.shade700;
                      cualitativo = 'Apropiación Plena (MB/TEA)';
                    } else if (notaCierre >= 4.0) {
                      valorRite = 'TEP';
                      colorRite = Colors.orange.shade800;
                      cualitativo = 'Desarrollo Satisfactorio (B/TEP)';
                    } else {
                      valorRite = 'TED';
                      colorRite = Colors.red.shade700;
                      cualitativo = 'En Proceso de Apoyo (R/TED)';
                    }
                  }

                  String obtenerProfesor(String materia, String curso) {
                    final matLower = materia.toLowerCase();
                    if (curso.contains('1')) {
                      if (matLower.contains('historia sagrada') || matLower.contains('h. sagrada')) return 'Daniel Gomez';
                      if (matLower.contains('lenguaje') || matLower.contains('prácticas del lenguaje') || matLower.contains('p. del lenguaje')) return 'Jenica Romero';
                      if (matLower.contains('naturales') || matLower.contains('cs. naturales')) return 'Danilo Gomez';
                      if (matLower.contains('física') || matLower.contains('ed. física')) return 'Julio Lesson';
                      if (matLower.contains('ciudadanía') || matLower.contains('construcción')) return 'Maria Funes';
                      if (matLower.contains('matemática')) return 'Florencia Viero';
                    }
                    return 'Docente a cargo';
                  }

                  final profName = obtenerProfesor(matName, hijo['curso_name'] ?? '');

                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(matName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('Prof. $profName', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 16, color: colorRite),
                            const SizedBox(width: 6),
                            Text(cualitativo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorRite)),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorRite.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorRite.withAlpha(60)),
                          ),
                          child: Text(
                            valorRite,
                            style: TextStyle(fontWeight: FontWeight.bold, color: colorRite, fontSize: 13),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          notaCierreText,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: notaCierre != null && notaCierre >= 7.0 
                                ? Colors.green.shade800 
                                : (notaCierre != null ? Colors.red.shade700 : colorScheme.onSurface),
                          ),
                        ),
                      ),
                      DataCell(
                        Text('0', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ),
                      DataCell(
                        TextButton.icon(
                          icon: const Icon(Icons.visibility_rounded, size: 16),
                          label: const Text('Ver Detalle', style: TextStyle(fontSize: 12)),
                          onPressed: () => _mostrarDetalleCalificacionesMateria(hijo, matName, matId, calificaciones),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24.0),

          // Criterios de Evaluación Continuos (Pie del Boletín)
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withAlpha(60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CRITERIOS CUALITATIVOS EVALUADOS POR EL DOCENTE EN ESTA ETAPA:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildChipCriterio('✔ Apropiación de contenidos trabajados', colorScheme),
                      _buildChipCriterio('✔ Resolución en tiempo y forma', colorScheme),
                      _buildChipCriterio('✔ Participación activa en clases', colorScheme),
                      _buildChipCriterio('✔ Planteo de dudas y sugerencias', colorScheme),
                      _buildChipCriterio('✔ Prolijidad y carpeta completa', colorScheme),
                      _buildChipCriterio('✔ Cumplimiento de los AIC*', colorScheme),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24.0),

          // Observaciones en el Boletín
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: BorderSide(color: Colors.indigo.shade100),
            ),
            color: Colors.indigo.shade50.withAlpha(80),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.comment_rounded, color: Colors.indigo),
                      SizedBox(width: 12),
                      Text(
                        'Observaciones Generales del Boletín',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: Colors.indigo),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    obsTexto,
                    style: const TextStyle(fontSize: 13.0, height: 1.5, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipCriterio(String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurface)),
    );
  }

  // 9. Sub-Sección Hijo: Convivencia (Reporte de Incidencias / Notas de Comportamiento)
  Widget _buildHijoConvivencia(Map<String, dynamic> hijo, ColorScheme colorScheme) {
    final id = hijo['legajo_id'] as String;
    final conducta = _cacheConducta[id] ?? [];

    final incidencias = conducta.where((c) {
      final tipo = c['tipo_incidencia'].toString();
      final desc = c['descripcion'].toString();
      return tipo != 'Bien' && tipo != 'Regular' && tipo != 'Más o menos' && tipo != 'Mal' && !desc.contains('Conducta diaria:');
    }).toList();

    final conductaDiaria = conducta.where((c) {
      final tipo = c['tipo_incidencia'].toString();
      final desc = c['descripcion'].toString();
      return tipo == 'Bien' || tipo == 'Regular' || tipo == 'Más o menos' || tipo == 'Mal' || desc.contains('Conducta diaria:');
    }).toList();

    final observaciones = conducta.where((c) {
      final desc = c['descripcion'].toString();
      return desc.contains('—') || (c['tipo_incidencia'].toString() != 'Bien' && c['tipo_incidencia'].toString() != 'Regular' && c['tipo_incidencia'].toString() != 'Mal' && c['tipo_incidencia'].toString() != 'Más o menos');
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32.0, 32.0, 32.0, 0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Convivencia y Conducta - ${hijo['nombre_completo']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16.0),
                TabBar(
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  indicatorColor: colorScheme.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(icon: Icon(Icons.gavel_rounded), text: 'Incidencias'),
                    Tab(icon: Icon(Icons.sentiment_satisfied_alt_rounded), text: 'Conducta Diaria'),
                    Tab(icon: Icon(Icons.visibility_rounded), text: 'Observaciones'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Incidencias
                SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      if (incidencias.isEmpty)
                        _buildEmptyConvivencia('¡Sin incidencias!', 'No se registran sanciones disciplinarias en este ciclo lectivo.', Colors.green)
                      else
                        ...incidencias.map((c) => _buildIncidenciaCard(c, colorScheme)),
                    ],
                  ),
                ),
                // Tab 2: Conducta Diaria
                SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      if (conductaDiaria.isEmpty)
                        _buildEmptyConvivencia('Comportamiento Excelente', 'El alumno registra buena conducta diaria en todas sus clases.', Colors.blue)
                      else
                        ...conductaDiaria.map((c) => _buildConductaDiariaCard(c, colorScheme)),
                    ],
                  ),
                ),
                // Tab 3: Observaciones
                SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      if (observaciones.isEmpty)
                        _buildEmptyConvivencia('Sin observaciones', 'No hay observaciones pedagógicas o conductuales para mostrar.', Colors.grey)
                      else
                        ...observaciones.map((c) => _buildObservacionCard(c, colorScheme)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConvivencia(String title, String subtitle, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0), side: BorderSide(color: Colors.grey.withAlpha(50))),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: color, size: 48.0),
              const SizedBox(height: 12.0),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4.0),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13.0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncidenciaCard(Map<String, dynamic> c, ColorScheme colorScheme) {
    final severidad = c['severidad'].toString();
    final tipo = c['tipo_incidencia'].toString();
    final desc = c['descripcion'].toString();
    final fecha = c['fecha'].toString();
    final estado = c['estado'].toString();
    final accion = c['accion_tomada']?.toString() ?? 'Sin resolución';

    Color color;
    switch (severidad) {
      case 'GRAVISIMA':
        color = Colors.red.shade800;
        break;
      case 'GRAVE':
        color = Colors.orange.shade800;
        break;
      default:
        color = Colors.amber.shade800;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: Colors.grey.withAlpha(51)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    '$severidad - $tipo',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11.0),
                  ),
                ),
                Text(fecha, style: const TextStyle(color: Colors.grey, fontSize: 12.0)),
              ],
            ),
            const SizedBox(height: 12.0),
            Text(desc, style: const TextStyle(fontWeight: FontWeight.w500)),
            const Divider(height: 24.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Estado: $estado', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0)),
                Text('Medida: $accion', style: TextStyle(color: Colors.grey.shade700, fontSize: 13.0)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConductaDiariaCard(Map<String, dynamic> c, ColorScheme colorScheme) {
    final tipo = c['tipo_incidencia'].toString();
    final desc = c['descripcion'].toString();
    final fecha = c['fecha'].toString();

    Color color = Colors.green;
    if (tipo == 'Regular' || tipo == 'Más o menos') {
      color = Colors.orange;
    } else if (tipo == 'Mal') {
      color = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: Colors.grey.withAlpha(51)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
              child: Icon(
                tipo == 'Mal'
                    ? Icons.sentiment_very_dissatisfied_rounded
                    : (tipo == 'Regular' || tipo == 'Más o menos'
                        ? Icons.sentiment_neutral_rounded
                        : Icons.sentiment_very_satisfied_rounded),
                color: color,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tipo == 'Más o menos' ? 'Calificación: Regular' : 'Calificación: $tipo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                  ),
                  const SizedBox(height: 4.0),
                  Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12.0)),
                ],
              ),
            ),
            Text(fecha, style: const TextStyle(color: Colors.grey, fontSize: 11.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildObservacionCard(Map<String, dynamic> c, ColorScheme colorScheme) {
    final desc = c['descripcion'].toString();
    final fecha = c['fecha'].toString();

    String observacion = desc;
    if (desc.contains('—')) {
      observacion = desc.split('—').last.trim();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      color: Colors.indigo.shade50.withAlpha(50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: Colors.indigo.shade100.withAlpha(100)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.comment_rounded, color: Colors.indigo, size: 18),
                    SizedBox(width: 8),
                    Text('Nota de Observación', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ],
                ),
                Text(fecha, style: const TextStyle(color: Colors.grey, fontSize: 11.0)),
              ],
            ),
            const SizedBox(height: 12.0),
            Text(
              observacion,
              style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  // 10. Sub-Sección Hijo: Materias Adeudadas (Real)
  Widget _buildHijoAdeudadas(Map<String, dynamic> hijo, ColorScheme colorScheme) {
    final id = hijo['legajo_id'] as String;
    final adeudadas = _cacheAdeudadas[id] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Materias Adeudadas - ${hijo['nombre_completo']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 24.0),

          adeudadas.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.stars_rounded, color: Colors.indigo, size: 48.0),
                          SizedBox(height: 12.0),
                          Text('¡Historial Académico Limpio!', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4.0),
                          Text('La alumna no tiene materias pendientes de acreditación.'),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: adeudadas.length,
                  itemBuilder: (context, index) {
                    final m = adeudadas[index];
                    final nombre = m['nombre_materia'].toString();
                    final anio = m['anio_cursada'].toString();
                    final estado = m['estado'].toString();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        side: BorderSide(color: Colors.grey.withAlpha(30)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.withAlpha(25),
                          child: const Icon(Icons.assignment_late_rounded, color: Colors.indigo),
                        ),
                        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Año de cursada: $anio'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: estado == 'PENDIENTE' ? Colors.red.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            estado,
                            style: TextStyle(color: estado == 'PENDIENTE' ? Colors.red.shade800 : Colors.green.shade800, fontSize: 11.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
