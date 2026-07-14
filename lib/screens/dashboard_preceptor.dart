import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/asistencia_provider.dart';
import '../models/alumno_asistencia.dart';
import '../services/supabase_service.dart';
import '../widgets/alumno_tile_mobile.dart';
import '../widgets/calendario_docente.dart';
import 'panel_alertas.dart';
import 'bandeja_mensajes.dart';
import 'panel_cobros.dart';
import 'panel_conducta.dart';
import 'panel_calificaciones.dart';
import 'panel_gestion_materia.dart';
import 'panel_administracion.dart';
import 'panel_asistencia.dart';
import 'panel_alumnos_preceptor.dart';
import 'panel_boletines_preceptor.dart';
import 'panel_temarios_preceptor.dart';
import 'panel_conducta_diaria.dart';
import 'panel_libro_actas.dart';
import 'panel_materias_adeudadas.dart';
import 'panel_repositorio_documentos.dart';
import 'mi_perfil_screen.dart';
import '../widgets/app_drawer.dart';



// ─────────────────────────────────────────────
// Enum para manejar las secciones del docente
// ─────────────────────────────────────────────
enum _DocenteSection {
  dashboard,
  asistencia,
  comunicacion,
  conducta,
  calendario,
}

class DashboardPreceptor extends StatefulWidget {
  const DashboardPreceptor({super.key});

  @override
  State<DashboardPreceptor> createState() => _DashboardPreceptorState();
}

class _DashboardPreceptorState extends State<DashboardPreceptor> {
  _DocenteSection _seccionActual = _DocenteSection.asistencia;
  String? _nombreDocente;
  bool _loadingNombre = true;
  int _selectedDay = 15;
  final List<String> _calendarFilters = ['Evaluaciones', 'Proyectos', 'Actos', 'Reuniones', 'Capacitaciones'];
  final _supabaseService = SupabaseService();
  late final Map<int, Map<String, dynamic>> _customCalendarEvents;

  @override
  void initState() {
    super.initState();
    _customCalendarEvents = {
      12: {'title': 'Reunión de Gabinete Psicopedagógico (EOE) - 10:00 hs', 'category': 'Reuniones'},
      15: {'title': 'Examen Trimestral de Matemática (1ro A) - 08:30 hs', 'category': 'Evaluaciones'},
      22: {'title': 'Entrega de TP de Ciencias Naturales (2do B) - 13:00 hs', 'category': 'Evaluaciones'},
      18: {'title': 'Acto del Día de la Independencia - 09:30 hs', 'category': 'Actos'},
      25: {'title': 'Capacitación Docente (RITE) - 14:00 hs', 'category': 'Capacitaciones'},
      28: {'title': 'Presentación de Proyectos de Ciencias - 11:00 hs', 'category': 'Proyectos'},
    };
    final user = Supabase.instance.client.auth.currentUser;
    final rol = user?.userMetadata?['rol'] as String?;

    // Para docentes, preceptores, admins y directivos, el dashboard es por defecto
    if (rol == 'DOCENTE' || rol == 'PRECEPTOR' || rol == 'ADMIN' || rol == 'DIRECTIVO') {
      _seccionActual = _DocenteSection.dashboard;
    } else {
      _seccionActual = _DocenteSection.asistencia;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AsistenciaProvider>().cargarAlumnos();
      _cargarNombreDocente();
      _cargarEventosDesdeSupabase();
    });
  }

  Future<void> _cargarNombreDocente() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final data = await Supabase.instance.client
          .from('usr_docentes')
          .select('nombre')
          .eq('auth_id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _nombreDocente = data?['nombre'] as String?;
          _loadingNombre = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingNombre = false);
    }
  }

  Future<void> _cargarEventosDesdeSupabase() async {
    try {
      final eventos = await _supabaseService.obtenerTodosLosEventosCalendario();
      if (mounted && eventos.isNotEmpty) {
        setState(() {
          for (final ev in eventos) {
            final fechaStr = ev['fecha']?.toString() ?? '';
            if (fechaStr.contains('-')) {
              final partes = fechaStr.split('T')[0].split('-');
              if (partes.length >= 3) {
                final dia = int.tryParse(partes[2]) ?? 1;
                final tit = ev['titulo']?.toString() ?? 'Evento';
                String cat = ev['tipo_evento']?.toString() ?? 'Evaluaciones';
                final desc = ev['descripcion']?.toString() ?? '';
                
                if (desc.contains('[Cat: ')) {
                  final m = RegExp(r'\[Cat:\s*(.*?)\]').firstMatch(desc);
                  if (m != null && m.group(1) != null) {
                    cat = m.group(1)!.trim();
                  }
                } else if (cat == 'EVALUACION') {
                  cat = 'Evaluaciones';
                } else if (cat == 'REUNION') {
                  cat = 'Reuniones';
                } else if (cat == 'ACTIVIDAD') {
                  if (tit.toLowerCase().contains('proyecto') || desc.toLowerCase().contains('proyecto')) {
                    cat = 'Proyectos';
                  } else if (tit.toLowerCase().contains('capacita') || tit.toLowerCase().contains('rite') || desc.toLowerCase().contains('capacita')) {
                    cat = 'Capacitaciones';
                  } else {
                    cat = 'Actos';
                  }
                }

                _customCalendarEvents[dia] = {
                  'title': desc.isNotEmpty && !desc.startsWith('Destinatarios:') && !desc.contains('[Cat:') ? '$tit ($desc)' : tit,
                  'category': cat,
                };
              }
            }
          }
        });
      }
    } catch (e) {
      print('Error cargando calendario desde DB: $e');
    }
  }


  void _confirmarAsistencia(BuildContext context) {
    final provider = context.read<AsistenciaProvider>();
    provider.guardarAsistencia().then((exito) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(exito ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: Colors.white),
              const SizedBox(width: 12),
              Text(exito
                  ? 'Asistencia guardada correctamente'
                  : 'Error al guardar asistencia'),
            ]),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                exito ? Colors.green.shade800 : Colors.red.shade800,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AsistenciaProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final user = Supabase.instance.client.auth.currentUser;
    final rol = user?.userMetadata?['rol'] as String?;
    final isDocente = rol == 'DOCENTE';
    final isAdminOrDirectivo = rol == 'ADMIN' || rol == 'DIRECTIVO';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(colorScheme, rol),
      drawer: AppDrawer(rolOverride: rol),
      body: isAdminOrDirectivo && _seccionActual == _DocenteSection.dashboard
          ? _construirDashboardAdmin(context, colorScheme)
          : isDocente
              ? _buildDocenteBody(context, colorScheme, provider)
              : (rol == 'PRECEPTOR' || isAdminOrDirectivo)
                  ? _buildPreceptorBody(context, colorScheme, provider)
                  : _buildAsistenciaBody(context, colorScheme, provider),
      bottomNavigationBar: null,
      floatingActionButton:
          isDocente && _seccionActual == _DocenteSection.asistencia
              ? FloatingActionButton.extended(
                  onPressed: provider.isLoading || provider.alumnos.isEmpty
                      ? null
                      : () => _confirmarAsistencia(context),
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Confirmar planilla',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                )
              : null,
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme colorScheme, String? rol) {
    String titulo;
    if (rol == 'ADMIN') {
      titulo = 'Panel del Administrador';
    } else if (rol == 'PRECEPTOR') {
      titulo = 'Dashboard del Preceptor';
    } else if (_nombreDocente != null) {
      titulo = '¡Hola profe ${_nombreDocente!.split(' ').first}!';
    } else {
      titulo = 'Portal Docente';
    }

    return AppBar(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_seccionActual != _DocenteSection.dashboard)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Volver al Inicio',
              onPressed: () {
                setState(() {
                  _seccionActual = _DocenteSection.dashboard;
                });
              },
            )
          else if (Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Volver atrás',
              onPressed: () => Navigator.of(context).pop(),
            ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Menú lateral',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),
      leadingWidth: (_seccionActual != _DocenteSection.dashboard || Navigator.of(context).canPop()) ? 96.0 : 48.0,
      title: Text(titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      actions: [
        if (_seccionActual == _DocenteSection.asistencia)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar lista',
            onPressed: () =>
                context.read<AsistenciaProvider>().cargarAlumnos(),
          ),
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Cerrar sesión',
          onPressed: () => SupabaseService().signOut(),
        ),
      ],
    );
  }

  // ─── BOTTOM NAV (solo docentes, mobile-first) ────────────────────────────
  Widget _buildBottomNav(ColorScheme colorScheme) {
    final items = [
      const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded), label: 'Inicio'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.assignment_turned_in_rounded), label: 'Asistencia'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_rounded), label: 'Comunicación'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.gavel_rounded), label: 'Conducta'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month_rounded), label: 'Calendario'),
    ];

    final currentIndex = _DocenteSection.values.indexOf(_seccionActual);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) => setState(() => _seccionActual = _DocenteSection.values[i]),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      backgroundColor: colorScheme.surface,
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      elevation: 8,
      items: items,
    );
  }

  // ─── DRAWER (preceptor/admin) ─────────────────────────────────────────────
  Widget _buildDrawer(ColorScheme colorScheme, String? rol) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.school_rounded, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                const Text('EdTech SGE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(
                  rol == 'ADMIN'
                      ? 'Gestión del Administrador'
                      : rol == 'PRECEPTOR'
                          ? 'Gestión del Preceptor'
                          : _nombreDocente != null
                              ? '¡Hola profe ${_nombreDocente!.split(' ').first}!'
                              : 'Portal del Docente',
                  style: TextStyle(
                      color: Colors.white.withAlpha(204), fontSize: 12),
                ),
              ],
            ),
          ),
          // Items según rol
          if (rol == 'PRECEPTOR' || rol == 'ADMIN') ...[
            _drawerItem(
              icon: Icons.assignment_turned_in_rounded,
              title: 'Toma de Asistencia',
              selected: _seccionActual == _DocenteSection.asistencia,
              onTap: () => _setSeccion(_DocenteSection.asistencia),
            ),
            _drawerItem(
              icon: Icons.calendar_month_rounded,
              title: 'Calendario Escolar',
              selected: _seccionActual == _DocenteSection.calendario,
              onTap: () => _setSeccion(_DocenteSection.calendario),
            ),
            _drawerItem(
              icon: Icons.badge_rounded,
              title: 'Ficha de Alumnos',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const PanelAlumnosPreceptor()));
              },
            ),
            _drawerItem(
              icon: Icons.assignment_rounded,
              title: 'Boletines Oficiales',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const PanelBoletinesPreceptor()));
              },
            ),
            _drawerItem(
              icon: Icons.menu_book_rounded,
              title: 'Temario Diario',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const PanelTemariosPreceptor(isReadOnly: true)));
              },
            ),
          ],
          if (rol == 'PRECEPTOR' || rol == 'ADMIN' || rol == 'DIRECTIVO')
            _drawerItem(
              icon: Icons.dashboard_rounded,
              title: 'Inicio (Dashboard)',
              selected: _seccionActual == _DocenteSection.dashboard,
              onTap: () => _setSeccion(_DocenteSection.dashboard),
            ),
          if (rol == 'ADMIN')
            _drawerItem(
              icon: Icons.notifications_active_rounded,
              title: 'Panel de Dirección (Alertas)',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const PanelAlertas()));
              },
            ),
          _drawerItem(
            icon: Icons.mail_rounded,
            title: 'Cuaderno Digital',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const BandejaMensajes()));
            },
          ),
          if (rol == 'ADMIN')
            _drawerItem(
              icon: Icons.point_of_sale_rounded,
              title: 'Panel de Cobros',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const PanelCobros()));
              },
            ),
          if (rol == 'ADMIN' || rol == 'DIRECTIVO')
            _drawerItem(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Panel de Administración',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const PanelAdministracion()));
              },
            ),
          _drawerItem(
            icon: Icons.gavel_rounded,
            title: 'Módulo de Conducta',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const PanelConducta()));
            },
          ),
          _drawerItem(
            icon: Icons.person_pin_circle_rounded,
            title: '👤 Mi Perfil / DDJJ / CV',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => MiPerfilScreen(rol: rol ?? 'DOCENTE')));
            },
          ),
          const Divider(),
          _drawerItem(
            icon: Icons.logout_rounded,
            title: 'Cerrar Sesión',
            onTap: () {
              Navigator.of(context).pop();
              SupabaseService().signOut();
            },
          ),
        ],
      ),
    );
  }

  ListTile _drawerItem({
    required IconData icon,
    required String title,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: selected,
      onTap: onTap,
    );
  }

  void _setSeccion(_DocenteSection s) {
    Navigator.of(context).pop();
    setState(() => _seccionActual = s);
  }

  // ─── CUERPO PRINCIPAL DOCENTE (router por sección) ────────────────────────
  Widget _buildDocenteBody(
      BuildContext context, ColorScheme colorScheme, AsistenciaProvider provider) {
    switch (_seccionActual) {
      case _DocenteSection.dashboard:
        return _construirDashboardDocente(context, colorScheme);
      case _DocenteSection.asistencia:
        return _buildAsistenciaBody(context, colorScheme, provider);
      case _DocenteSection.comunicacion:
        return _buildComunicacionDocente(context, colorScheme);
      case _DocenteSection.conducta:
        return _buildConductaDiaria(context, colorScheme);
      case _DocenteSection.calendario:
        return _buildCalendarioDocente(context, colorScheme);
    }
  }

  // ─── ASISTENCIA (rediseñada, práctica para móvil) ─────────────────────────
  Widget _buildAsistenciaBody(
      BuildContext context, ColorScheme colorScheme, AsistenciaProvider provider) {
    if (provider.isLoading && provider.alumnos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.alumnos.isEmpty) {
      return const Center(child: Text('No hay alumnos asignados a este curso.'));
    }

    final hoy = DateTime.now();
    final fechaStr =
        '${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}';
    final presentes =
        provider.alumnos.where((a) => a.estado == EstadoAsistencia.presente).length;
    final ausentes =
        provider.alumnos.where((a) => a.estado == EstadoAsistencia.ausente).length;
    final tarde =
        provider.alumnos.where((a) => a.estado == EstadoAsistencia.tarde).length;

    return Column(
      children: [
        // Encabezado resumen
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: colorScheme.primaryContainer.withAlpha(60),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(fechaStr,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: colorScheme.primary)),
              const Spacer(),
              _statChip(Icons.check_circle_rounded, '$presentes', Colors.green),
              const SizedBox(width: 6),
              _statChip(Icons.cancel_rounded, '$ausentes', Colors.red),
              const SizedBox(width: 6),
              _statChip(Icons.access_time_rounded, '$tarde', Colors.orange),
            ],
          ),
        ),
        // Lista de alumnos con tile mobile
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
                top: 8, left: 8, right: 8, bottom: 100),
            itemCount: provider.alumnos.length,
            itemBuilder: (context, index) {
              return AlumnoTileMobile(
                  alumnoId: provider.alumnos[index].id);
            },
          ),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ─── COMUNICACIÓN DOCENTE ─────────────────────────────────────────────────
  Widget _buildComunicacionDocente(BuildContext context, ColorScheme colorScheme) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.groups_rounded), text: 'Por Curso'),
              Tab(icon: Icon(Icons.person_rounded), text: 'Por Familia'),
            ],
            labelColor: colorScheme.primary,
            indicatorColor: colorScheme.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ComunicacionPorCurso(),
                _ComunicacionPorFamilia(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CONDUCTA DIARIA ──────────────────────────────────────────────────────
  Widget _buildConductaDiaria(BuildContext context, ColorScheme colorScheme) {
    return _RegistroConductaDiario();
  }

  // ─── CALENDARIO DOCENTE ───────────────────────────────────────────────────
  Widget _buildCalendarioDocente(BuildContext context, ColorScheme colorScheme) {
    return const CalendarioDocente();
  }

  // ─── DASHBOARD DOCENTE (materias asignadas) ───────────────────────────────
  Widget _construirDashboardDocente(BuildContext context, ColorScheme colorScheme) {
    final saludo = _loadingNombre
        ? '¡Bienvenido, Profesor!'
        : _nombreDocente != null
            ? '¡Hola profe ${_nombreDocente!.split(' ').first}!'
            : '¡Bienvenido, Profesor!';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(saludo,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  )),
          const SizedBox(height: 16),

          // 1. Calendario arriba
          const Text(
            'Calendario Escolar Mensual / Agenda',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildInteractiveCalendar(colorScheme),
          const SizedBox(height: 24),

          // 2. Banner Sala TICS (Turnera) - Finito/ListTile style
          Card(
            elevation: 0,
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.computer_rounded, color: Colors.blue, size: 24),
              title: const Text('Sala TICs - Reserva de Turnera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Reservá equipamiento y el aula de informática', style: TextStyle(fontSize: 11)),
              trailing: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Row(
                          children: [
                            Icon(Icons.computer_rounded, color: Colors.blue),
                            SizedBox(width: 12),
                            Text('Sala TICs - Reserva'),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estás por ingresar a la turnera oficial de reserva de la Sala TICs.'),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.link_rounded, color: Colors.blue),
                                  SizedBox(width: 12),
                                  Text('turnera-tics.colegio.edu.ar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cerrar'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                            onPressed: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Redireccionando a Turnera Sala TICs...')),
                              );
                            },
                            child: const Text('Ir a la Turnera'),
                          ),
                        ],
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Text('Entrar', style: TextStyle(fontSize: 11)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Tus materias y cursos asignados:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadMateriasDocente(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error al cargar materias: ${snapshot.error}'));
              }
              final materias = snapshot.data ?? [];
              if (materias.isEmpty) {
                return const Center(
                    child: Text(
                        'No tenés materias o cursos asignados actualmente.'));
              }

              return Column(
                children: List.generate(materias.length, (index) {
                  final item = materias[index];
                  final materiaId = item['materia_id'] as String;
                  final cursoId = item['curso_id'] as String;
                  final materiaName = item['nombre_asignatura'] as String;
                  final cursoName = item['identificador_division'] as String;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    color: colorScheme.primaryContainer.withAlpha(20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colorScheme.primary.withAlpha(40)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary.withAlpha(20),
                        child: Icon(Icons.class_rounded, color: colorScheme.primary),
                      ),
                      title: Text(materiaName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          cursoName,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PanelGestionMateria(
                            materiaId: materiaId,
                            cursoId: cursoId,
                            nombreAsignatura: materiaName,
                            identificadorDivision: cursoName,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadMateriasDocente() async {
    try {
      final docenteId = await SupabaseService().obtenerDocenteIdActual();
      return await SupabaseService().fetchMateriasPorDocente(docenteId);
    } catch (e) {
      debugPrint('Error al obtener materias: $e');
      return [];
    }
  }

  Widget _construirDashboardAdmin(BuildContext context, ColorScheme colorScheme) {
    final rol = Supabase.instance.client.auth.currentUser?.userMetadata?['rol'] as String? ?? 'ADMIN';
    final cards = [
      {
        'title': 'Administración General (ABM)',
        'description': 'Personal, alumnos, tutores, cursos y materias.',
        'icon': Icons.admin_panel_settings_rounded,
        'color': Colors.blue,
        'onTap': () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PanelAdministracion())),
      },
      {
        'title': 'Panel de Alertas',
        'description': 'Inasistencias acumuladas y avisos de dirección.',
        'icon': Icons.notifications_active_rounded,
        'color': Colors.red,
        'onTap': () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PanelAlertas())),
      },
      {
        'title': 'Gestión de Cobros',
        'description': 'Cuentas corrientes y transacciones contables.',
        'icon': Icons.point_of_sale_rounded,
        'color': Colors.green,
        'onTap': () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PanelCobros())),
      },
      {
        'title': 'Módulo de Conducta',
        'description': 'Incidencias disciplinarias de la escuela.',
        'icon': Icons.gavel_rounded,
        'color': Colors.amber.shade900,
        'onTap': () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PanelConducta())),
      },
      {
        'title': 'Toma de Asistencia',
        'description': 'Carga manual de presentismo diario.',
        'icon': Icons.assignment_turned_in_rounded,
        'color': Colors.teal,
        'onTap': () => setState(() => _seccionActual = _DocenteSection.asistencia),
      },
      {
        'title': 'Ficha de Alumnos',
        'description': 'Historial académico, DNI y trayectoria.',
        'icon': Icons.badge_rounded,
        'color': Colors.indigo,
        'onTap': () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PanelAlumnosPreceptor())),
      },
      {
        'title': 'Boletines Oficiales (RITE)',
        'description': 'Planilla RITE y notas oficiales.',
        'icon': Icons.assignment_rounded,
        'color': Colors.blue.shade700,
        'onTap': () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PanelBoletinesPreceptor())),
      },
      {
        'title': 'Temario Diario',
        'description': 'Temas dictados por clase y materia.',
        'icon': Icons.menu_book_rounded,
        'color': Colors.green.shade700,
        'onTap': () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PanelTemariosPreceptor(isReadOnly: true))),
      },
      {
        'title': 'Cuaderno Digital',
        'description': 'Envío de comunicados y mensajería.',
        'icon': Icons.mail_rounded,
        'color': Colors.purple,
        'onTap': () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BandejaMensajes())),
      },
      {
        'title': 'Libro de Actas',
        'description': 'Reuniones de personal y actas disciplinarias.',
        'icon': Icons.menu_book_rounded,
        'color': Colors.teal.shade800,
        'onTap': () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PanelLibroActas(rolUsuario: rol, nombreUsuario: _nombreDocente))),
      },
      {
        'title': 'RITE Materias Adeudadas',
        'description': 'Calificaciones de materias previas.',
        'icon': Icons.bookmarks_rounded,
        'color': Colors.purple.shade700,
        'onTap': () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PanelMateriasAdeudadas())),
      },
      {
        'title': 'Repositorio de Documentos',
        'description': 'Planificación anual y contratos pedagógicos.',
        'icon': Icons.folder_shared_rounded,
        'color': Colors.blueGrey,
        'onTap': () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PanelRepositorioDocumentos())),
      },
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¡Bienvenido, Administrador!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  )),
          const SizedBox(height: 16),

          // 1. Calendario arriba
          const Text(
            'Calendario Escolar Mensual / Agenda',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildInteractiveCalendar(colorScheme),
          const SizedBox(height: 24),

          Text('Seleccioná un módulo para gestionar la institución:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.primary)),
          const SizedBox(height: 12),

          Column(
            children: List.generate(cards.length, (index) {
              final card = cards[index];
              final color = card['color'] as Color;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                color: color.withAlpha(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: color.withAlpha(51)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withAlpha(30),
                    child: Icon(card['icon'] as IconData, color: color),
                  ),
                  title: Text(card['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(card['description'] as String, style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  onTap: card['onTap'] as VoidCallback,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── PORTAL PRECEPTOR WIDGETS ──────────────────────────────────────────────

  Widget _buildPreceptorBody(BuildContext context, ColorScheme colorScheme, AsistenciaProvider provider) {
    switch (_seccionActual) {
      case _DocenteSection.dashboard:
        return _construirDashboardPreceptor(context, colorScheme);
      case _DocenteSection.asistencia:
        return _buildPreceptorAsistencia(context, colorScheme, provider);
      case _DocenteSection.comunicacion:
        return const BandejaMensajes();
      case _DocenteSection.conducta:
        return const PanelConducta();
      case _DocenteSection.calendario:
        return _buildCalendarioDocente(context, colorScheme);
    }
  }

  Widget _construirDashboardPreceptor(BuildContext context, ColorScheme colorScheme) {
    final rol = Supabase.instance.client.auth.currentUser?.userMetadata?['rol'] as String? ?? 'PRECEPTOR';
    final actions = [
      {
        'title': 'Toma de Asistencia',
        'desc': 'Pasar asistencia por curso',
        'icon': Icons.fact_check_rounded,
        'color': Colors.teal,
        'onTap': () => setState(() => _seccionActual = _DocenteSection.asistencia),
      },
      {
        'title': 'Ficha de Alumnos',
        'desc': 'Historial, DNI y legajos',
        'icon': Icons.badge_rounded,
        'color': Colors.indigo,
        'onTap': () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const PanelAlumnosPreceptor()),
        ),
      },
      {
        'title': 'Boletines Oficiales',
        'desc': 'Planilla RITE y notas',
        'icon': Icons.assignment_rounded,
        'color': Colors.blue.shade700,
        'onTap': () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const PanelBoletinesPreceptor()),
        ),
      },
      {
        'title': 'Temario Diario',
        'desc': 'Temas dictados por clase',
        'icon': Icons.menu_book_rounded,
        'color': Colors.green.shade700,
        'onTap': () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const PanelTemariosPreceptor(isReadOnly: true)),
        ),
      },
      {
        'title': 'Calendario Escolar',
        'desc': 'Agenda de eventos y exámenes',
        'icon': Icons.calendar_month_rounded,
        'color': Colors.deepOrange.shade800,
        'onTap': () => setState(() => _seccionActual = _DocenteSection.calendario),
      },
      {
        'title': 'Cuaderno Digital',
        'desc': 'Comunicados y mensajería',
        'icon': Icons.mail_rounded,
        'color': Colors.purple,
        'onTap': () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const BandejaMensajes()),
        ),
      },
      {
        'title': 'Libro de Actas',
        'desc': 'Reuniones de personal y actas disciplinarias.',
        'icon': Icons.menu_book_rounded,
        'color': Colors.teal.shade800,
        'onTap': () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => PanelLibroActas(rolUsuario: rol, nombreUsuario: _nombreDocente)),
        ),
      },
      {
        'title': 'RITE Materias Adeudadas',
        'desc': 'Calificaciones de materias previas.',
        'icon': Icons.bookmarks_rounded,
        'color': Colors.purple.shade700,
        'onTap': () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const PanelMateriasAdeudadas()),
        ),
      },
      {
        'title': 'Repositorio de Documentos',
        'desc': 'Planificación anual y contratos pedagógicos.',
        'icon': Icons.folder_shared_rounded,
        'color': Colors.blueGrey,
        'onTap': () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const PanelRepositorioDocumentos()),
        ),
      },
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de bienvenida
          Text(
            '¡Hola Preceptor!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(height: 4),
          const Text('Acceso rápido a las tareas diarias y alertas.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),

          // 1. Calendario arriba
          const Text(
            'Calendario Escolar Mensual / Agenda',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildInteractiveCalendar(colorScheme),
          const SizedBox(height: 24),

          // Tarjetas de Acceso Principal (Listado Vertical Delgado)
          Text('Accesos rápidos de preceptores:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.primary)),
          const SizedBox(height: 12),

          Column(
            children: List.generate(actions.length, (index) {
              final action = actions[index];
              final color = action['color'] as Color;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                color: color.withAlpha(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: color.withAlpha(51)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withAlpha(30),
                    child: Icon(action['icon'] as IconData, color: color),
                  ),
                  title: Text(action['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(action['desc'] as String, style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  onTap: action['onTap'] as VoidCallback,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Sección de Incidencias de Conducta Recientes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Alertas de Conducta Recientes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 8),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: SupabaseService().obtenerRecientesIncidencias(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ));
              }
              final incidencias = snapshot.data ?? [];
              if (incidencias.isEmpty) {
                return Card(
                  elevation: 0,
                  color: colorScheme.surfaceVariant.withAlpha(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text('Sin reportes de conducta en las últimas horas.',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: incidencias.length > 5 ? 5 : incidencias.length,
                itemBuilder: (context, index) {
                  final item = incidencias[index];
                  final alumno = item['usr_legajo_alumno'] as Map<String, dynamic>?;
                  final demo = alumno?['datos_demograficos'] as Map<String, dynamic>?;
                  final nombreAlumno = '${demo?['apellido'] ?? ''} ${demo?['nombre'] ?? ''}'.trim();
                  
                  final tipo = item['tipo_incidencia'] as String? ?? 'Incidente';
                  final sev = item['severidad'] as String? ?? 'Leve';
                  final desc = item['descripcion'] as String? ?? '';
                  
                  Color colorSev = Colors.blue;
                  if (sev == 'Grave') colorSev = Colors.orange;
                  if (sev == 'Gravísima') colorSev = Colors.red;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(nombreAlumno.isNotEmpty ? nombreAlumno : 'Alumno',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colorSev.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  sev,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: colorSev),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('$tipo: $desc', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Alertas de Próximas Evaluaciones',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
            ),
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFFDE8E8), child: Icon(Icons.warning_amber_rounded, color: Colors.red)),
                  title: const Text('Examen Trimestral de Matemática (1ro A)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Fecha: 15/07/2026 | Docente: Florencia Viero'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Urgente', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFFFF4E5), child: Icon(Icons.event_note_rounded, color: Colors.orange)),
                  title: const Text('Entrega de Trabajo Práctico de Ciencias Naturales (2do B)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Fecha: 22/07/2026 | Docente: Danilo Gomez'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Próximo', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCalendar(ColorScheme colorScheme) {
    final daysInMonth = 31;
    final startOffset = 2; // Julio 2026 starts on Wednesday (offset 2)
    final totalCells = daysInMonth + startOffset;
    final rowCount = (totalCells / 7).ceil();

    // Filter events by selected category
    final Map<int, Map<String, dynamic>> calendarEvents = {};
    _customCalendarEvents.forEach((day, info) {
      if (_calendarFilters.contains(info['category'])) {
        calendarEvents[day] = info;
      }
    });

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Card(
          elevation: 0,
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
                    Text(
                      'Julio 2026',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorScheme.primary),
                    ),
                    Builder(
                      builder: (context) {
                        final user = Supabase.instance.client.auth.currentUser;
                        final rol = user?.userMetadata?['rol'] as String? ?? 'DOCENTE';
                        final puedeAgregar = rol == 'ADMIN' || rol == 'PRECEPTOR';
                        return Row(
                          children: [
                            if (puedeAgregar)
                              FilledButton.icon(
                                onPressed: () => _mostrarDialogoNuevoEvento(context, colorScheme),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('+ Agregar evento', style: TextStyle(fontSize: 12)),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            if (puedeAgregar) const SizedBox(width: 8),
                            const Icon(Icons.arrow_back_ios_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 16),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Filtros de categorías
                const Text('Filtrar agenda:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: ['Evaluaciones', 'Proyectos', 'Actos', 'Reuniones', 'Capacitaciones'].map((cat) {
                    final isSelected = _calendarFilters.contains(cat);
                    Color activeColor = colorScheme.primary;
                    if (isSelected) {
                      if (cat == 'Evaluaciones') activeColor = Colors.red;
                      else if (cat == 'Proyectos') activeColor = Colors.blue;
                      else if (cat == 'Actos') activeColor = Colors.green;
                      else if (cat == 'Reuniones') activeColor = Colors.amber.shade800;
                      else if (cat == 'Capacitaciones') activeColor = Colors.purple;
                    }
                    return ChoiceChip(
                      label: Text(cat, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.black87)),
                      selected: isSelected,
                      selectedColor: activeColor,
                      checkmarkColor: Colors.white,
                      backgroundColor: Colors.grey.shade100,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _calendarFilters.add(cat);
                          } else {
                            _calendarFilters.remove(cat);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((day) {
                    return SizedBox(
                      width: 32,
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: rowCount * 7,
                  itemBuilder: (context, index) {
                    final dayNumber = index - startOffset + 1;
                    if (dayNumber <= 0 || dayNumber > daysInMonth) {
                      return const SizedBox();
                    }

                    final hasEvent = calendarEvents.containsKey(dayNumber);
                    final isSelected = _selectedDay == dayNumber;

                    Color cellColor = Colors.transparent;
                    Color textColor = Colors.black87;
                    BoxBorder? cellBorder;

                    if (isSelected) {
                      cellColor = colorScheme.primary;
                      textColor = Colors.white;
                    } else if (hasEvent) {
                      final cat = calendarEvents[dayNumber]!['category'];
                      Color catColor = colorScheme.primary;
                      if (cat == 'Evaluaciones') catColor = Colors.red;
                      else if (cat == 'Proyectos') catColor = Colors.blue;
                      else if (cat == 'Actos') catColor = Colors.green;
                      else if (cat == 'Reuniones') catColor = Colors.amber.shade800;
                      else if (cat == 'Capacitaciones') catColor = Colors.purple;

                      cellColor = catColor.withAlpha(25);
                      textColor = catColor;
                      cellBorder = Border.all(color: catColor, width: 1.5);
                    }

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDay = dayNumber;
                        });
                      },
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cellColor,
                            shape: BoxShape.circle,
                            border: cellBorder,
                          ),
                          child: Center(
                            child: Text(
                              dayNumber.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: (hasEvent || isSelected) ? FontWeight.bold : FontWeight.normal,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 24),
                if (calendarEvents.containsKey(_selectedDay))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.primary.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_available_rounded, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Día $_selectedDay:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colorScheme.primary),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      calendarEvents[_selectedDay]!['category'] as String,
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colorScheme.primary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                calendarEvents[_selectedDay]!['title'] as String,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_note_rounded, color: Colors.grey),
                        const SizedBox(width: 12),
                        Text(
                          'No hay eventos para el día $_selectedDay.',
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoNuevoEvento(BuildContext context, ColorScheme colorScheme) {
    final titleCtrl = TextEditingController();
    final mensajeCtrl = TextEditingController();
    final horaCtrl = TextEditingController();
    String category = 'Evaluaciones';
    int day = _selectedDay;
    String hora = '08:00';
    
    final List<String> destinatariosList = [
      'Todos los Docentes',
      'Preceptores / Administrativos',
      'Alumnos de 1° SEC',
      'Alumnos de 2° SEC',
      'Familias / Tutores'
    ];
    final List<String> selectedDestinatarios = ['Todos los Docentes'];
    bool enviarNotificacion = true;
    bool esInterno = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.add_task_rounded, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  const Text('Crear Nuevo Evento'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: const Text('Exclusivo Personal (Interno)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                        subtitle: const Text('No aparecerá en el portal de familias ni alumnos', style: TextStyle(fontSize: 11)),
                        value: esInterno,
                        activeColor: Colors.indigo,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDialogState(() => esInterno = val),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Título o Descripción',
                          border: OutlineInputBorder(),
                          hintText: 'Ej: Examen de Historia o Acto Escolar',
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Evaluaciones', 'Proyectos', 'Actos', 'Reuniones', 'Capacitaciones'].map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              category = val;
                              if (val == 'Reuniones' || val == 'Capacitaciones') {
                                esInterno = true;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Día:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      DropdownButton<int>(
                        value: day,
                        isExpanded: true,
                        items: List.generate(31, (i) => i + 1).map((d) {
                          return DropdownMenuItem(value: d, child: Text('$d de Julio 2026'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => day = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: horaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hora (Ej: 10:00 o 14:30)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time_rounded),
                        ),
                        onChanged: (val) => hora = val,
                      ),
                      const SizedBox(height: 16),
                      const Text('Destinatarios principales / Visibilidad:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          children: destinatariosList.map((dest) {
                            final isSel = selectedDestinatarios.contains(dest);
                            return CheckboxListTile(
                              title: Text(dest, style: const TextStyle(fontSize: 12)),
                              value: isSel,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (checked) {
                                setDialogState(() {
                                  if (checked == true) {
                                    selectedDestinatarios.add(dest);
                                  } else {
                                    selectedDestinatarios.remove(dest);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Enviar recordatorio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Notificar por Cuaderno Digital', style: TextStyle(fontSize: 10)),
                        value: enviarNotificacion,
                        onChanged: (val) {
                          setDialogState(() => enviarNotificacion = val);
                        },
                      ),
                      if (enviarNotificacion) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: mensajeCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Mensaje para el Comunicado (opcional)',
                            hintText: 'Ej: Recordar asistir con uniforme escolar y autorización firmada...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor ingrese un título.')),
                      );
                      return;
                    }
                    Navigator.of(context).pop();

                    final listString = selectedDestinatarios.join(', ');
                    final dateStr = "2026-07-${day.toString().padLeft(2, '0')}";
                    final esEventoInterno = esInterno || category == 'Reuniones' || category == 'Capacitaciones' || !selectedDestinatarios.any((d) => d.contains('Familias') || d.contains('Alumnos'));

                    setState(() {
                      _customCalendarEvents[day] = {
                        'title': '${esEventoInterno && !titleCtrl.text.trim().startsWith("[INTERNO]") ? "[INTERNO] " : ""}${titleCtrl.text.trim()} - $hora hs',
                        'category': category,
                      };
                      _selectedDay = day;
                      if (!_calendarFilters.contains(category)) {
                        _calendarFilters.add(category);
                      }
                    });

                    try {
                      final desc = 'Destinatarios: $listString${mensajeCtrl.text.trim().isNotEmpty ? "\n\nMensaje: ${mensajeCtrl.text.trim()}" : ""}';
                      await _supabaseService.crearEventoCalendario(
                        titulo: '${titleCtrl.text.trim()} - $hora hs',
                        descripcion: desc,
                        fecha: dateStr,
                        tipoEvento: category,
                        cursoId: null,
                        esInterno: esEventoInterno,
                      );
                      if (enviarNotificacion) {
                        await _supabaseService.enviarComunicadoGrupal(
                          asunto: '📅 Nuevo Evento: ${titleCtrl.text.trim()} ($hora hs)',
                          texto: '${mensajeCtrl.text.trim().isNotEmpty ? "${mensajeCtrl.text.trim()}\n\n" : ""}Categoría: $category\nFecha: $day de Julio 2026 a las $hora hs\nDestinatarios: $listString',
                          destinatariosRoles: selectedDestinatarios,
                        );
                      }
                      await _cargarEventosDesdeSupabase();
                    } catch (e) {
                      print('Error al guardar evento en Supabase: $e');
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.send_rounded, color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(enviarNotificacion
                                  ? '¡Evento creado! Recordatorio y agenda guardados en la base de datos para: $listString.'
                                  : '¡Evento creado y guardado en la base de datos exitosamente!'),
                              ),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.green.shade800,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                  child: const Text('Crear Evento'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _preceptorActionCard(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: color.withAlpha(15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(40)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(30),
                radius: 18,
                child: Icon(icon, color: color, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13, height: 1.1)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: TextStyle(
                          color: colorScheme.onSurfaceVariant, fontSize: 10, height: 1.1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreceptorAsistencia(
      BuildContext context, ColorScheme colorScheme, AsistenciaProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seleccionar Curso a Tomar Asistencia',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: SupabaseService().fetchCursos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final cursos = snapshot.data ?? [];
                if (cursos.isEmpty) {
                  return const Center(child: Text('No hay cursos registrados en el SGE.'));
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: cursos.length,
                  itemBuilder: (context, index) {
                    final c = cursos[index];
                    final cursoId = c['curso_id'] as String;
                    final nombre = c['identificador_division'] as String;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.class_rounded, color: Colors.teal),
                        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Toma de asistencia diaria'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PanelAsistencia(cursoId: cursoId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TILE DE ASISTENCIA MOBILE-FIRST (reemplaza AlumnoTile para docentes)
// ─────────────────────────────────────────────────────────────────────────────
class _AsistenciaTileMobile extends StatelessWidget {
  final String alumnoId;
  const _AsistenciaTileMobile({required this.alumnoId});

  static const _estados = [
    EstadoAsistencia.presente,
    EstadoAsistencia.ausente,
    EstadoAsistencia.tarde,
    EstadoAsistencia.retiro,
  ];

  static const _etiquetas = ['Presente', 'Ausente', 'Tarde', 'Retiro'];

  static const _iconos = [
    Icons.check_circle_rounded,
    Icons.cancel_rounded,
    Icons.access_time_rounded,
    Icons.exit_to_app_rounded,
  ];

  static final _colores = [
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AsistenciaProvider>();
    final idx = provider.alumnos.indexWhere((a) => a.id == alumnoId);
    if (idx == -1) {
      return const SizedBox.shrink();
    }
    final alumno = provider.alumnos[idx];
    final colorScheme = Theme.of(context).colorScheme;
    final estadoIdx = _estados.indexOf(alumno.estado);
    final colorEstado = _colores[estadoIdx];
    final tieneHora = alumno.estado == EstadoAsistencia.tarde ||
        alumno.estado == EstadoAsistencia.retiro;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(80),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Left: Name
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colorScheme.primary.withAlpha(15),
                    child: Text(
                      alumno.nombre.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alumno.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right: Compact buttons P, A, T, R
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (i) {
                final state = _estados[i];
                final label = _etiquetas[i].substring(0, 1); // P, A, T, R
                final selected = alumno.estado == state;
                final color = _colores[i];

                return Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: GestureDetector(
                    onTap: () {
                      context
                          .read<AsistenciaProvider>()
                          .actualizarEstado(alumno.id, state);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: selected ? color : color.withAlpha(20),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? color : color.withAlpha(50),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : color,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            // Clock button if tarde or retiro
            if (tieneHora)
              IconButton(
                icon: const Icon(Icons.access_time_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final hora = await showTimePicker(
                    context: context,
                    initialTime: alumno.horaEvento ?? TimeOfDay.now(),
                  );
                  if (hora != null && context.mounted) {
                    context
                        .read<AsistenciaProvider>()
                        .actualizarHora(alumno.id, hora);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMUNICACIÓN POR CURSO
// ─────────────────────────────────────────────────────────────────────────────
class _ComunicacionPorCurso extends StatefulWidget {
  @override
  State<_ComunicacionPorCurso> createState() => _ComunicacionPorCursoState();
}

class _ComunicacionPorCursoState extends State<_ComunicacionPorCurso> {
  final _service = SupabaseService();
  late Future<List<Map<String, dynamic>>> _materiasFuture;

  @override
  void initState() {
    super.initState();
    _materiasFuture = _cargarMaterias();
  }

  Future<List<Map<String, dynamic>>> _cargarMaterias() async {
    try {
      final docenteId = await _service.obtenerDocenteIdActual();
      return await _service.fetchMateriasPorDocente(docenteId);
    } catch (_) {
      return [];
    }
  }

  void _abrirModalMensaje(String cursoId, String cursoNombre) {
    final asuntoCtrl = TextEditingController();
    final cuerpoCtrl = TextEditingController();
    bool firmado = false;
    bool enviando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.groups_rounded),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Mensaje al curso $cursoNombre',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16))),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: asuntoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Asunto',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subject_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cuerpoCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.message_rounded),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Requiere firma del padre/madre',
                    style: TextStyle(fontSize: 13)),
                value: firmado,
                onChanged: (v) => setS(() => firmado = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: enviando
                      ? null
                      : () async {
                          if (asuntoCtrl.text.trim().isEmpty ||
                              cuerpoCtrl.text.trim().isEmpty) return;
                          setS(() => enviando = true);
                          try {
                            await _service.enviarMensajeMasivo(
                              asunto: asuntoCtrl.text.trim(),
                              texto: cuerpoCtrl.text.trim(),
                              requiereFirma: firmado,
                              cursoId: cursoId,
                            );
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Mensaje enviado al curso'),
                                    backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            setS(() => enviando = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  icon: enviando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: const Text('Enviar mensaje'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _materiasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final materias = snapshot.data ?? [];
        // Agrupar por curso para no repetir
        final cursosMap = <String, Map<String, dynamic>>{};
        for (final m in materias) {
          final cId = m['curso_id'] as String;
          cursosMap[cId] = m;
        }
        final cursos = cursosMap.values.toList();

        if (cursos.isEmpty) {
          return const Center(child: Text('No tenés cursos asignados.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: cursos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = cursos[i];
            final cursoNombre = c['identificador_division'] as String;
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: colorScheme.outlineVariant)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(Icons.groups_rounded,
                      color: colorScheme.onPrimaryContainer),
                ),
                title: Text('Curso $cursoNombre',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Enviar comunicado a todos los alumnos y familias'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    _abrirModalMensaje(c['curso_id'] as String, cursoNombre),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMUNICACIÓN POR FAMILIA
// ─────────────────────────────────────────────────────────────────────────────
class _ComunicacionPorFamilia extends StatefulWidget {
  @override
  State<_ComunicacionPorFamilia> createState() =>
      _ComunicacionPorFamiliaState();
}

class _ComunicacionPorFamiliaState extends State<_ComunicacionPorFamilia> {
  final _service = SupabaseService();
  late Future<List<Map<String, dynamic>>> _familiasFuture;

  @override
  void initState() {
    super.initState();
    _familiasFuture = _service.fetchGruposFamiliares();
  }

  void _abrirChat(String grupoId, String nombreGrupo) {
    final cuerpoCtrl = TextEditingController();
    bool enviando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.family_restroom_rounded),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Mensaje a familia $nombreGrupo',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16))),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: cuerpoCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Escribí tu mensaje...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.message_rounded),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: enviando
                      ? null
                      : () async {
                          if (cuerpoCtrl.text.trim().isEmpty) return;
                          setS(() => enviando = true);
                          try {
                            await _service.enviarMensajeMasivo(
                              asunto: 'Mensaje del docente',
                              texto: cuerpoCtrl.text.trim(),
                              requiereFirma: false,
                              cursoId: null,
                            );
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Mensaje enviado'),
                                    backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            setS(() => enviando = false);
                          }
                        },
                  icon: enviando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: const Text('Enviar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _familiasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final familias = snapshot.data ?? [];
        if (familias.isEmpty) {
          return const Center(child: Text('No hay familias disponibles.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: familias.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final f = familias[i];
            final nombre = f['nombre_grupo'] as String? ?? 'Familia';
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: colorScheme.outlineVariant)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Icon(Icons.family_restroom_rounded,
                      color: colorScheme.onSecondaryContainer),
                ),
                title: Text(nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Enviar mensaje privado'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _abrirChat(f['grupo_id'] as String, nombre),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTRO DE CONDUCTA DIARIO (integrado en el portal docente)
// ─────────────────────────────────────────────────────────────────────────────
class _RegistroConductaDiario extends StatefulWidget {
  @override
  State<_RegistroConductaDiario> createState() =>
      _RegistroConductaDiarioState();
}

class _RegistroConductaDiarioState extends State<_RegistroConductaDiario> {
  final _service = SupabaseService();
  late Future<List<Map<String, dynamic>>> _alumnosFuture;

  static const _tiposIncidencia = [
    'Falta de respeto',
    'Agresión física',
    'Agresión verbal',
    'Uso indebido del celular',
    'Comportamiento disruptivo',
    'Ausencia injustificada',
    'Otro',
  ];

  static const _severidades = ['LEVE', 'MODERADA', 'GRAVE'];

  @override
  void initState() {
    super.initState();
    _alumnosFuture = _cargarAlumnos();
  }

  Future<List<Map<String, dynamic>>> _cargarAlumnos() async {
    return await _service.fetchAlumnosList();
  }

  void _abrirFormConducta(String alumnoId, String nombreAlumno) {
    String? tipoSeleccionado;
    String? severidadSeleccionada;
    final descCtrl = TextEditingController();
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.gavel_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Registrar conducta — $nombreAlumno',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15))),
                ]),
                const SizedBox(height: 16),
                const Text('Tipo de incidencia',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tiposIncidencia.map((t) {
                    final sel = tipoSeleccionado == t;
                    return GestureDetector(
                      onTap: () => setS(() => tipoSeleccionado = t),
                      child: Chip(
                        label: Text(t,
                            style: TextStyle(
                                fontSize: 12,
                                color: sel ? Colors.white : null,
                                fontWeight: sel ? FontWeight.bold : null)),
                        backgroundColor: sel
                            ? Theme.of(ctx).colorScheme.primary
                            : null,
                        side: BorderSide(
                            color: sel
                                ? Theme.of(ctx).colorScheme.primary
                                : Theme.of(ctx).colorScheme.outlineVariant),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Severidad',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: _severidades.map((s) {
                    final sel = severidadSeleccionada == s;
                    final color = s == 'LEVE'
                        ? Colors.green
                        : s == 'MODERADA'
                            ? Colors.orange
                            : Colors.red;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: s != _severidades.last ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setS(() => severidadSeleccionada = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? color : color.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: sel ? color : color.withAlpha(60)),
                            ),
                            child: Text(s,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: sel ? Colors.white : color)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción del hecho',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: guardando ||
                            tipoSeleccionado == null ||
                            severidadSeleccionada == null
                        ? null
                        : () async {
                            setS(() => guardando = true);
                            try {
                              await _service.registrarIncidencia(
                                alumnoId: alumnoId,
                                tipoIncidencia: tipoSeleccionado!,
                                severidad: severidadSeleccionada!,
                                descripcion: descCtrl.text.trim(),
                              );
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Incidencia registrada'),
                                      backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              setS(() => guardando = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                    icon: guardando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: const Text('Guardar incidencia'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _alumnosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final alumnos = snapshot.data ?? [];
        if (alumnos.isEmpty) {
          return const Center(
              child: Text('No hay alumnos disponibles para registrar conducta.'));
        }

        final hoy = DateTime.now();
        final fechaStr =
            '${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}';

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.orange.withAlpha(30),
              child: Row(
                children: [
                  const Icon(Icons.gavel_rounded, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('Registro de conducta — $fechaStr',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: alumnos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final a = alumnos[i];
                  final nombre =
                      '${a['nombre'] ?? ''} ${a['apellido'] ?? ''}'.trim();
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.errorContainer,
                        child: Text(
                          nombre.isNotEmpty
                              ? nombre.substring(0, 1).toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(nombre,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _abrirFormConducta(
                            a['legajo_id'] as String? ?? '', nombre),
                        child: const Text('+ Incidencia',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CALENDARIO DOCENTE
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarioDocente extends StatefulWidget {
  @override
  State<_CalendarioDocente> createState() => _CalendarioDocenteState();
}

class _CalendarioDocenteState extends State<_CalendarioDocente> {
  DateTime _mesActual = DateTime.now();
  DateTime? _diaSeleccionado;
  final Map<String, List<_EventoCalendario>> _eventos = {};

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static const _diasSemana = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];

  String _claveEvento(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<_EventoCalendario> _eventosDelDia(DateTime d) =>
      _eventos[_claveEvento(d)] ?? [];

  void _agregarEvento(DateTime fecha) {
    String tipo = 'evaluacion';
    final tituloCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nuevo evento — ${fecha.day}/${fecha.month}/${fecha.year}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text('Tipo de evento',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _tipoChip(ctx, setS, tipo, 'evaluacion', 'Evaluación',
                      Icons.quiz_rounded, Colors.purple,
                      onSel: (t) => tipo = t),
                  _tipoChip(ctx, setS, tipo, 'actividad', 'Actividad',
                      Icons.assignment_rounded, Colors.blue,
                      onSel: (t) => tipo = t),
                  _tipoChip(ctx, setS, tipo, 'reunion', 'Reunión',
                      Icons.people_rounded, Colors.green,
                      onSel: (t) => tipo = t),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título del evento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    if (tituloCtrl.text.trim().isEmpty) return;
                    final clave = _claveEvento(fecha);
                    setState(() {
                      _eventos.putIfAbsent(clave, () => []).add(
                        _EventoCalendario(
                          titulo: tituloCtrl.text.trim(),
                          tipo: tipo,
                        ),
                      );
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Evento "${tituloCtrl.text.trim()}" agregado'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar evento'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipoChip(BuildContext ctx, StateSetter setS, String tipoActual,
      String valor, String label, IconData icon, Color color,
      {required Function(String) onSel}) {
    final sel = tipoActual == valor;
    return GestureDetector(
      onTap: () => setS(() => onSel(valor)),
      child: Chip(
        avatar: Icon(icon, size: 14, color: sel ? Colors.white : color),
        label: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : null,
                fontSize: 12,
                fontWeight: sel ? FontWeight.bold : null)),
        backgroundColor: sel ? color : color.withAlpha(20),
        side: BorderSide(color: sel ? color : color.withAlpha(60)),
      ),
    );
  }

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'evaluacion':
        return Colors.purple;
      case 'actividad':
        return Colors.blue;
      case 'reunion':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _iconTipo(String tipo) {
    switch (tipo) {
      case 'evaluacion':
        return Icons.quiz_rounded;
      case 'actividad':
        return Icons.assignment_rounded;
      case 'reunion':
        return Icons.people_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hoy = DateTime.now();

    // Calcular días del mes
    final primerDia = DateTime(_mesActual.year, _mesActual.month, 1);
    final diasEnMes =
        DateTime(_mesActual.year, _mesActual.month + 1, 0).day;
    // lunes=1 ... domingo=7; ajustar offset para empezar en lunes
    int offsetInicio = primerDia.weekday - 1;

    final user = Supabase.instance.client.auth.currentUser;
    final rol = user?.userMetadata?['rol'] as String? ?? 'DOCENTE';
    final puedeAgregar = rol == 'ADMIN' || rol == 'PRECEPTOR';

    return Column(
      children: [
        // Header del mes
        Container(
          color: colorScheme.primaryContainer.withAlpha(60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() {
                  _mesActual = DateTime(_mesActual.year, _mesActual.month - 1);
                }),
              ),
              Expanded(
                child: Text(
                  '${_meses[_mesActual.month - 1]} ${_mesActual.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => setState(() {
                  _mesActual = DateTime(_mesActual.year, _mesActual.month + 1);
                }),
              ),
              if (puedeAgregar)
                FilledButton.icon(
                  onPressed: _diaSeleccionado != null
                      ? () => _agregarEvento(_diaSeleccionado!)
                      : null,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+ Agregar evento', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        // Días de la semana
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: _diasSemana
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant)),
                      ),
                    ))
                .toList(),
          ),
        ),
        // Grid del calendario
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: offsetInicio + diasEnMes,
            itemBuilder: (context, index) {
              if (index < offsetInicio) return const SizedBox();
              final dia = index - offsetInicio + 1;
              final fecha = DateTime(_mesActual.year, _mesActual.month, dia);
              final esHoy = fecha.year == hoy.year &&
                  fecha.month == hoy.month &&
                  fecha.day == hoy.day;
              final esSeleccionado = _diaSeleccionado != null &&
                  fecha.year == _diaSeleccionado!.year &&
                  fecha.month == _diaSeleccionado!.month &&
                  fecha.day == _diaSeleccionado!.day;
              final tieneEventos = _eventosDelDia(fecha).isNotEmpty;

              return GestureDetector(
                onTap: () => setState(() => _diaSeleccionado = fecha),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: esSeleccionado
                        ? colorScheme.primary
                        : esHoy
                            ? colorScheme.primaryContainer
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: esHoy && !esSeleccionado
                        ? Border.all(color: colorScheme.primary, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dia',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              esHoy || esSeleccionado ? FontWeight.bold : null,
                          color: esSeleccionado
                              ? colorScheme.onPrimary
                              : esHoy
                                  ? colorScheme.primary
                                  : null,
                        ),
                      ),
                      if (tieneEventos)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: esSeleccionado
                                ? colorScheme.onPrimary
                                : colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        // Lista de eventos del día seleccionado
        Expanded(
          child: _diaSeleccionado == null
              ? Center(
                  child: Text(
                    'Seleccioná un día para ver o agregar eventos',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                )
              : _eventosDelDia(_diaSeleccionado!).isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available_rounded,
                              size: 48,
                              color: colorScheme.onSurfaceVariant
                                  .withAlpha(100)),
                          const SizedBox(height: 8),
                          Text(
                            'Sin eventos el ${_diaSeleccionado!.day}/${_diaSeleccionado!.month}',
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () =>
                                _agregarEvento(_diaSeleccionado!),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Agregar evento'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _eventosDelDia(_diaSeleccionado!).length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final e = _eventosDelDia(_diaSeleccionado!)[i];
                        final color = _colorTipo(e.tipo);
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: color.withAlpha(80)),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withAlpha(30),
                              child: Icon(_iconTipo(e.tipo),
                                  color: color, size: 20),
                            ),
                            title: Text(e.titulo,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              e.tipo == 'evaluacion'
                                  ? 'Evaluación'
                                  : e.tipo == 'actividad'
                                      ? 'Actividad'
                                      : 'Reunión',
                              style: TextStyle(color: color, fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon:
                                  const Icon(Icons.delete_rounded, size: 18),
                              color: Colors.red,
                              onPressed: () {
                                setState(() {
                                  _eventosDelDia(_diaSeleccionado!).remove(e);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _EventoCalendario {
  final String titulo;
  final String tipo; // 'evaluacion', 'actividad', 'reunion'
  _EventoCalendario({required this.titulo, required this.tipo});
}
