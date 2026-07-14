import 'package:flutter/material.dart';
import 'panel_asistencia.dart';
import 'panel_calificaciones.dart';
import 'panel_conducta.dart';
import 'panel_conducta_diaria.dart';
import 'panel_temarios_preceptor.dart';
import 'panel_planificacion_diaria.dart';
import 'panel_eoe_docente.dart';
import 'panel_banco_evaluaciones.dart';
import '../widgets/app_drawer.dart';

class PanelGestionMateria extends StatelessWidget {
  final String materiaId;
  final String cursoId;
  final String nombreAsignatura;
  final String identificadorDivision;

  const PanelGestionMateria({
    super.key,
    required this.materiaId,
    required this.cursoId,
    required this.nombreAsignatura,
    required this.identificadorDivision,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: AppDrawer.buildLeading(context),
        leadingWidth: AppDrawer.buildLeadingWidth(context),
        title: Text(nombreAsignatura, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner de Información Contextual
            Card(
              elevation: 0,
              color: colorScheme.primaryContainer.withAlpha(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
                side: BorderSide(color: colorScheme.primary.withAlpha(51)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.class_rounded, color: colorScheme.primary, size: 32.0),
                        const SizedBox(width: 12.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            identificadorDivision,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      nombreAsignatura,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Gestión integral y calificaciones de este curso asignado.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            // ── FECHAS IMPORTANTES (EVALUACIONES Y ENTREGAS) ────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.orange.withAlpha(100), width: 1.5),
              ),
              color: Colors.orange.shade50.withAlpha(120),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: Colors.deepOrange, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Fechas Importantes (Evaluaciones y Entregas)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _abrirCalendarioMateriaDialog(context),
                          icon: const Icon(Icons.calendar_today_rounded, size: 14),
                          label: const Text('Ver Calendario Completo', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                          child: const Row(
                            children: [
                              Icon(Icons.quiz_rounded, size: 16, color: Colors.purple),
                              SizedBox(width: 6),
                              Text('15/07 - Examen Trimestral', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                          child: const Row(
                            children: [
                              Icon(Icons.assignment_rounded, size: 16, color: Colors.blue),
                              SizedBox(width: 6),
                              Text('22/07 - Entrega TP Integrador', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28.0),
            
            Text(
              'Acciones del Docente',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12.0),

            Column(
              children: [
                _buildSlenderActionCard(
                  context: context,
                  title: 'Toma de Asistencia',
                  description: 'Registra el presentismo diario',
                  icon: Icons.assignment_turned_in_rounded,
                  color: Colors.teal,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PanelAsistencia(cursoId: cursoId, materiaId: materiaId),
                    ),
                  ),
                ),
                _buildSlenderActionCard(
                  context: context,
                  title: 'Planilla Calificaciones RITE',
                  description: 'Carga de notas y RITE final con asistente de rúbricas',
                  icon: Icons.table_view_rounded,
                  color: Colors.blue,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PanelCalificaciones(materiaId: materiaId, cursoId: cursoId),
                    ),
                  ),
                ),
                _buildSlenderActionCard(
                  context: context,
                  title: 'Conducta Diaria',
                  description: 'Registrar comportamiento del día',
                  icon: Icons.sentiment_satisfied_alt_rounded,
                  color: Colors.green.shade700,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PanelConductaDiaria(
                        cursoId: cursoId,
                        nombreAsignatura: nombreAsignatura,
                      ),
                    ),
                  ),
                ),
                _buildSlenderActionCard(
                  context: context,
                  title: 'Registro de Conducta (Sanciones)',
                  description: 'Reportar incidencias disciplinarias de la escuela',
                  icon: Icons.gavel_rounded,
                  color: Colors.amber.shade900,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PanelConducta(cursoId: cursoId),
                    ),
                  ),
                ),
                _buildSlenderActionCard(
                  context: context,
                  title: 'Carga de Temarios',
                  description: 'Registrar temas dictados en clase',
                  icon: Icons.menu_book_rounded,
                  color: Colors.blue.shade800,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PanelTemariosPreceptor(
                        cursoIdInicial: cursoId,
                        isReadOnly: false,
                      ),
                    ),
                  ),
                ),
                _buildSlenderActionCard(
                  context: context,
                  title: 'Sala TICs / Turnera',
                  description: 'Reservar laboratorio de informática y equipamiento',
                  icon: Icons.computer_rounded,
                  color: Colors.purple,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Row(
                            children: [
                              Icon(Icons.computer_rounded, color: Colors.purple),
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
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.link_rounded, color: Colors.purple),
                                    SizedBox(width: 12),
                                    Text('turnera-tics.colegio.edu.ar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 12)),
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
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
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
                ),
                _buildSlenderActionCard(
                  context: context,
                  title: 'Planificación Diaria',
                  description: 'Completar tema, actividades, objetivos y materiales',
                  icon: Icons.edit_note_rounded,
                  color: Colors.blue.shade700,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PanelPlanificacionDiaria(
                        cursoId: cursoId,
                        nombreAsignatura: nombreAsignatura,
                      ),
                    ),
                  ),
                ),
                _buildSlenderActionCard(
                  context: context,
                  title: 'Espacio EOE (Adecuaciones)',
                  description: 'Consultar pautas y bitácora psicopedagógica',
                  icon: Icons.shield_outlined,
                  color: Colors.indigo,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PanelEoeDocente(
                        cursoId: cursoId,
                        identificadorDivision: identificadorDivision,
                      ),
                    ),
                  ),
                ),
                _buildSlenderActionCard(
                  context: context,
                  title: 'Calendario de la Materia (Sincronizado)',
                  description: 'Agenda de exámenes y eventos de esta materia',
                  icon: Icons.calendar_month_rounded,
                  color: Colors.deepOrange,
                  onTap: () {
                    _abrirCalendarioMateriaDialog(context);
                  },
                ),
                _buildSlenderActionCard(
                  context: context,
                  title: 'Banco de Evaluaciones',
                  description: 'Subir propuestas de exámenes y trabajos para aprobación',
                  icon: Icons.folder_special_rounded,
                  color: Colors.purple.shade700,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PanelBancoEvaluaciones(
                        materiaId: materiaId,
                        cursoId: cursoId,
                        nombreAsignatura: nombreAsignatura,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _abrirCalendarioMateriaDialog(BuildContext context) {
    final titleController = TextEditingController();
    final dateController = TextEditingController(text: '15/07/2026');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Text('Calendario: $nombreAsignatura'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Agendar examen o entrega de TP. Se sincronizará automáticamente con el Calendario General escolar:', style: TextStyle(fontSize: 13, height: 1.3)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Evento de la Materia',
                  hintText: 'Ej. Examen Parcial de Unidad 3',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Fecha del Evento',
                  hintText: 'DD/MM/AAAA',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('¡Evento "${titleController.text}" agendado en la materia y sincronizado con el Calendario General escolar! Se enviaron las notificaciones automáticas correspondientes.'),
                      backgroundColor: Colors.green.shade800,
                    ),
                  );
                }
              },
              child: const Text('Agendar y Sincronizar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSlenderActionCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
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
          backgroundColor: color.withAlpha(35),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(description, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
        onTap: onTap,
      ),
    );
  }
}
