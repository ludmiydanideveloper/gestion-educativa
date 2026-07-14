import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../screens/dashboard_preceptor.dart';
import '../screens/bandeja_mensajes.dart';
import '../screens/panel_conducta.dart';
import '../screens/mi_perfil_screen.dart';
import '../screens/panel_temarios_preceptor.dart';
import '../screens/panel_libro_actas.dart';
import '../screens/panel_gestion_materia.dart';
import '../screens/panel_alumnos_preceptor.dart';
import '../screens/panel_boletines_preceptor.dart';
import '../screens/panel_alertas.dart';
import '../screens/panel_cobros.dart';
import '../screens/panel_administracion.dart';
import '../screens/panel_materias_adeudadas.dart';
import '../screens/panel_repositorio_documentos.dart';
import 'brand_widgets.dart';

class AppDrawer extends StatefulWidget {
  final String? rolOverride;
  const AppDrawer({super.key, this.rolOverride});

  static Widget? buildLeading(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canPop)
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
    );
  }

  static double? buildLeadingWidth(BuildContext context) {
    return Navigator.of(context).canPop() ? 96.0 : 48.0;
  }

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final SupabaseService _supabaseService = SupabaseService();
  String? _rol;
  String _nombre = 'Usuario';
  Future<List<Map<String, dynamic>>>? _materiasFuture;

  @override
  void initState() {
    super.initState();
    _initRolAndMaterias();
  }

  void _initRolAndMaterias() {
    final user = Supabase.instance.client.auth.currentUser;
    _rol = widget.rolOverride ?? user?.userMetadata?['rol'] as String? ?? 'DOCENTE';
    _nombre = user?.userMetadata?['nombre'] as String? ??
        user?.userMetadata?['full_name'] as String? ??
        user?.email ??
        'Usuario';

    if (_rol == 'DOCENTE') {
      _materiasFuture = _loadMaterias();
    }
  }

  Future<List<Map<String, dynamic>>> _loadMaterias() async {
    try {
      final docenteId = await _supabaseService.obtenerDocenteIdActual();
      return await _supabaseService.fetchMateriasPorDocente(docenteId);
    } catch (e) {
      debugPrint('Error al obtener materias para drawer: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const BrandLogo(height: 44, showText: true, mainAxisAlignment: MainAxisAlignment.start),
                ),
                const SizedBox(height: 10),
                Text(
                  _rol == 'ADMIN'
                      ? 'Gestión del Administrador'
                      : _rol == 'PRECEPTOR'
                          ? 'Gestión del Preceptor'
                          : 'Portal del Docente',
                  style: TextStyle(
                      color: Colors.white.withAlpha(204), fontSize: 12),
                ),
              ],
            ),
          ),

          // 1. INICIO (Dashboard)
          ListTile(
            leading: const Icon(Icons.dashboard_rounded),
            title: const Text('Inicio (Dashboard)'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardPreceptor()),
              );
            },
          ),

          // 2. MATERIAS ASIGNADAS (para Docente)
          if (_rol == 'DOCENTE') ...[
            ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.class_rounded, color: Colors.blue),
              title: const Text('Mis Materias Asignadas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _materiasFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))),
                      );
                    }
                    final materias = snapshot.data ?? [];
                    if (materias.isEmpty) {
                      return const ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.only(left: 40, right: 16),
                        title: Text('No hay materias asignadas',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      );
                    }
                    return Column(
                      children: materias.map((item) {
                        return ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.only(left: 40, right: 16),
                          leading: const Icon(Icons.arrow_right_rounded,
                              color: Colors.blue, size: 20),
                          title: Text(
                              item['nombre_asignatura']?.toString() ?? 'Materia',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(
                              item['identificador_division']?.toString() ?? 'Curso',
                              style: const TextStyle(fontSize: 11)),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PanelGestionMateria(
                                  materiaId: item['materia_id'].toString(),
                                  cursoId: item['curso_id'].toString(),
                                  nombreAsignatura:
                                      item['nombre_asignatura'].toString(),
                                  identificadorDivision:
                                      item['identificador_division'].toString(),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ],

          // 3. TEMARIO DIARIO
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: const Text('Temario Diario'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PanelTemariosPreceptor(
                    isReadOnly: _rol == 'PRECEPTOR' ? true : false,
                  ),
                ),
              );
            },
          ),

          // 4. LIBRO DE ACTAS
          ListTile(
            leading: const Icon(Icons.book_rounded),
            title: const Text('Libro de Actas'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PanelLibroActas(rolUsuario: _rol, nombreUsuario: _nombre)),
              );
            },
          ),

          // 5. CUADERNO DIGITAL
          ListTile(
            leading: const Icon(Icons.mail_rounded),
            title: const Text('Cuaderno Digital'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BandejaMensajes()),
              );
            },
          ),

          // 6. MÓDULO DE CONDUCTA
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: const Text('Módulo de Conducta'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PanelConducta()),
              );
            },
          ),

          // 7. MI PERFIL / DDJJ / CV
          ListTile(
            leading: const Icon(Icons.person_pin_circle_rounded),
            title: const Text('👤 Mi Perfil / DDJJ / CV'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => MiPerfilScreen(rol: _rol ?? 'DOCENTE')),
              );
            },
          ),

          // Ítems exclusivos para Preceptores o Admins
          if (_rol == 'PRECEPTOR' || _rol == 'ADMIN' || _rol == 'DIRECTIVO') ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text('GESTIÓN INSTITUCIONAL',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in_rounded),
              title: const Text('Toma de Asistencia'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DashboardPreceptor()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.badge_rounded),
              title: const Text('Ficha de Alumnos'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PanelAlumnosPreceptor()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_rounded),
              title: const Text('Boletines Oficiales (RITE)'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PanelBoletinesPreceptor()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmarks_rounded),
              title: const Text('Materias Adeudadas RITE'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PanelMateriasAdeudadas()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_shared_rounded),
              title: const Text('Repositorio de Documentos'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PanelRepositorioDocumentos()),
                );
              },
            ),
          ],

          if (_rol == 'ADMIN') ...[
            ListTile(
              leading: const Icon(Icons.notifications_active_rounded),
              title: const Text('Panel de Dirección (Alertas)'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PanelAlertas()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale_rounded),
              title: const Text('Panel de Cobros'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PanelCobros()),
                );
              },
            ),
          ],

          if (_rol == 'ADMIN' || _rol == 'DIRECTIVO') ...[
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_rounded),
              title: const Text('Panel de Administración'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PanelAdministracion()),
                );
              },
            ),
          ],

          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Cerrar Sesión',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.of(context).pop();
              _supabaseService.signOut();
            },
          ),
          const Divider(),
          const BrandFrankiaFooter(scale: 0.75),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
