import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alumno_asistencia.dart';
import '../providers/asistencia_provider.dart';

/// Tile de asistencia optimizado para móvil con botones grandes y colores.
/// Reemplaza al antiguo AlumnoTile con SegmentedButton cortado.
class AlumnoTileMobile extends StatelessWidget {
  final String alumnoId;

  const AlumnoTileMobile({super.key, required this.alumnoId});

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
