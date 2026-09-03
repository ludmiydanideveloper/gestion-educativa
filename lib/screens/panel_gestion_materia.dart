import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'panel_asistencia.dart';
import 'panel_calificaciones.dart';
import 'panel_conducta.dart';
import 'panel_conducta_diaria.dart';
import 'panel_temarios_preceptor.dart';
import 'panel_planificacion_diaria.dart';
import 'panel_eoe_docente.dart';
import 'panel_banco_evaluaciones.dart';
import 'panel_cierre_etapa.dart';
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_available_rounded, color: Colors.deepOrange, size: 22),
                            const SizedBox(width: 10),
                            const Flexible(
                              child: Text(
                                'Fechas Importantes (Evaluaciones y Entregas)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange),
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => _abrirCalendarioMateriaDialog(context),
                          icon: const Icon(Icons.calendar_today_rounded, size: 14),
                          label: const Text('Ver Calendario Completo', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.quiz_rounded, size: 16, color: Colors.purple),
                              SizedBox(width: 6),
                              Text('15/07 - Examen Trimestral', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
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
                _buildSlenderActionCard(
                  context: context,
                  title: 'Cierre de Etapa (Boletín)',
                  description: 'Cargar criterios cualitativos y promediar notas (TEA/TEP/TED)',
                  icon: Icons.grading_rounded,
                  color: Colors.red.shade700,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PanelCierreEtapa(
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
    DateTime? fechaSeleccionada;
    bool guardando = false;
    String tipoSeleccionado = 'EVALUACION';

    // Tipos de evento disponibles: valor DB → label + ícono
    const tipos = [
      {'valor': 'EVALUACION', 'label': 'Examen / Evaluación', 'icon': Icons.quiz_rounded},
      {'valor': 'ENTREGA_TP', 'label': 'Entrega de TP', 'icon': Icons.assignment_turned_in_rounded},
      {'valor': 'ACTIVIDAD',  'label': 'Actividad / Salida', 'icon': Icons.directions_walk_rounded},
      {'valor': 'REUNION',    'label': 'Reunión', 'icon': Icons.groups_rounded},
    ];

    final service = SupabaseService();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlg) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            title: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Colors.deepOrange, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Calendario: $nombreAsignatura',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.deepOrange.shade200),
                      ),
                      child: const Text(
                        'Agendá un examen o entrega de TP. Quedará visible en el Calendario General escolar.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Selector de tipo de evento
                    const Text('Tipo de evento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tipos.map((t) {
                        final val = t['valor'] as String;
                        final lbl = t['label'] as String;
                        final ico = t['icon'] as IconData;
                        final sel = tipoSeleccionado == val;
                        return ChoiceChip(
                          avatar: Icon(ico, size: 16, color: sel ? Colors.white : Colors.deepOrange),
                          label: Text(lbl, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.black87)),
                          selected: sel,
                          selectedColor: Colors.deepOrange,
                          backgroundColor: Colors.deepOrange.shade50,
                          onSelected: (_) => setDlg(() => tipoSeleccionado = val),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Evento',
                        hintText: 'Ej. Examen Parcial Unidad 3',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Selector de fecha con date picker
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final hoy = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: fechaSeleccionada ?? hoy,
                          firstDate: DateTime(hoy.year - 1),
                          lastDate: DateTime(hoy.year + 2),
                          locale: const Locale('es'),
                        );
                        if (picked != null) {
                          setDlg(() => fechaSeleccionada = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fecha del Evento',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.event_rounded),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          fechaSeleccionada != null
                            ? '${fechaSeleccionada!.day.toString().padLeft(2, '0')}/${fechaSeleccionada!.month.toString().padLeft(2, '0')}/${fechaSeleccionada!.year}'
                            : 'Tocá para elegir la fecha',
                          style: TextStyle(
                            fontSize: 14,
                            color: fechaSeleccionada != null ? null : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                icon: guardando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.event_available_rounded, size: 18),
                label: const Text('Agendar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: guardando ? null : () async {
                  final titulo = titleController.text.trim();
                  if (titulo.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Escribí el nombre del evento.')),
                    );
                    return;
                  }
                  if (fechaSeleccionada == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Elegí una fecha para el evento.')),
                    );
                    return;
                  }

                  setDlg(() => guardando = true);
                  try {
                    final fechaStr = '${fechaSeleccionada!.year}-${fechaSeleccionada!.month.toString().padLeft(2, '0')}-${fechaSeleccionada!.day.toString().padLeft(2, '0')}';
                    await service.crearEventoCalendario(
                      titulo: titulo,
                      descripcion: '$nombreAsignatura — $identificadorDivision',
                      fecha: fechaStr,
                      tipoEvento: tipoSeleccionado,
                      cursoId: cursoId,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ "$titulo" agendado en el Calendario General.'),
                          backgroundColor: Colors.green.shade800,
                        ),
                      );
                    }
                  } catch (e) {
                    setDlg(() => guardando = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('Error al agendar: $e'),
                          backgroundColor: Colors.red.shade800,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          );
        });
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
