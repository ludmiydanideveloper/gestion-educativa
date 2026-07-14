import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alumno_asistencia.dart';
import '../providers/asistencia_provider.dart';

class AlumnoTile extends StatelessWidget {
  final String alumnoId;

  const AlumnoTile({
    super.key,
    required this.alumnoId,
  });

  Future<void> _seleccionarHora(BuildContext context, AlumnoAsistencia alumno) async {
    final TimeOfDay? horaSeleccionada = await showTimePicker(
      context: context,
      initialTime: alumno.horaEvento ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (horaSeleccionada != null && context.mounted) {
      context.read<AsistenciaProvider>().actualizarHora(alumno.id, horaSeleccionada);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escucha ÚNICAMENTE los cambios de este alumno específico para evitar redibujados innecesarios en la lista.
    final alumno = context.select<AsistenciaProvider, AlumnoAsistencia>(
      (provider) => provider.alumnos.firstWhere((a) => a.id == alumnoId),
    );

    final tieneHora = alumno.estado == EstadoAsistencia.tarde || alumno.estado == EstadoAsistencia.retiro;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: tieneHora 
              ? colorScheme.primary.withAlpha(51) 
              : colorScheme.outlineVariant.withAlpha(127),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila 1: Nombre del Alumno
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: tieneHora 
                      ? colorScheme.primaryContainer 
                      : colorScheme.surfaceContainerHighest,
                  child: Text(
                    alumno.nombre.substring(0, 1),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tieneHora 
                          ? colorScheme.onPrimaryContainer 
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Text(
                    alumno.nombre,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Fila 2: Selector de Estado (SegmentedButton de Material 3)
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<EstadoAsistencia>(
                segments: const [
                  ButtonSegment<EstadoAsistencia>(
                    value: EstadoAsistencia.presente,
                    icon: Icon(Icons.check_circle_outlined, size: 18),
                    label: Text('Presente'),
                  ),
                  ButtonSegment<EstadoAsistencia>(
                    value: EstadoAsistencia.ausente,
                    icon: Icon(Icons.cancel_outlined, size: 18),
                    label: Text('Ausente'),
                  ),
                  ButtonSegment<EstadoAsistencia>(
                    value: EstadoAsistencia.tarde,
                    icon: Icon(Icons.access_time_outlined, size: 18),
                    label: Text('Tarde'),
                  ),
                  ButtonSegment<EstadoAsistencia>(
                    value: EstadoAsistencia.retiro,
                    icon: Icon(Icons.exit_to_app_outlined, size: 18),
                    label: Text('Retiro'),
                  ),
                ],
                selected: {alumno.estado},
                onSelectionChanged: (Set<EstadoAsistencia> newSelection) {
                  context.read<AsistenciaProvider>().actualizarEstado(alumno.id, newSelection.first);
                },
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  selectedForegroundColor: colorScheme.onPrimary,
                  selectedBackgroundColor: colorScheme.primary,
                ),
                showSelectedIcon: false,
              ),
            ),

            // Lógica de Expansión con AnimatedCrossFade
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Column(
                children: [
                  const SizedBox(height: 12.0),
                  const Divider(height: 1.0),
                  const SizedBox(height: 12.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            alumno.estado == EstadoAsistencia.tarde 
                                ? Icons.hourglass_top_rounded 
                                : Icons.hourglass_bottom_rounded,
                            size: 20.0,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            alumno.estado == EstadoAsistencia.tarde 
                                ? 'Hora de llegada registrada:' 
                                : 'Hora de retiro registrada:',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit_calendar_rounded, size: 18.0),
                        label: Text(
                          alumno.horaEvento != null 
                              ? '${alumno.horaEvento!.hour.toString().padLeft(2, '0')}:${alumno.horaEvento!.minute.toString().padLeft(2, '0')} hs'
                              : 'Seleccionar hora',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _seleccionarHora(context, alumno),
                      ),
                    ],
                  ),
                ],
              ),
              crossFadeState: tieneHora ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }
}
