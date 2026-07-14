import 'package:flutter/material.dart';
import '../data/horarios_data.dart';

/// Widget que muestra el horario semanal de un curso en formato tabla coloreada.
class HorarioSemanal extends StatefulWidget {
  /// Nombre del curso para buscar en HorariosData (ej: "1° SEC")
  final String? nombreCurso;

  /// Si se pasa un HorarioCurso directamente (opcional)
  final HorarioCurso? horario;

  const HorarioSemanal({super.key, this.nombreCurso, this.horario})
      : assert(nombreCurso != null || horario != null,
            'Se requiere nombreCurso o horario');

  @override
  State<HorarioSemanal> createState() => _HorarioSemanalState();
}

class _HorarioSemanalState extends State<HorarioSemanal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  HorarioCurso? _horario;
  int _tabIndex = 0;

  // Índice del día actual (0=Lu, 1=Ma, 2=Mi, 3=Ju, 4=Vi)
  int get _diaHoy {
    final wd = DateTime.now().weekday; // 1=Lu … 7=Do
    return (wd >= 1 && wd <= 5) ? wd - 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    _horario = widget.horario ??
        (widget.nombreCurso != null
            ? HorariosData.buscarPorNombre(widget.nombreCurso!)
            : null);
    final cantDias = _horario?.dias.length ?? 5;
    _tabIndex = _diaHoy.clamp(0, cantDias - 1);
    _tabController = TabController(
        length: cantDias, vsync: this, initialIndex: _tabIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_horario == null) {
      return const Center(child: Text('Horario no disponible'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Encabezado con info del curso ─────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary,
                colorScheme.primary.withBlue(
                    (colorScheme.primary.blue + 40).clamp(0, 255)),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _horario!.curso,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.schedule_rounded,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text('${_horario!.totalModulos}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.login_rounded,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text('Entrada: ${_horario!.horaEntrada} hs',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      const Icon(Icons.logout_rounded,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text('Salida: ${_horario!.horaSalida} hs',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Tabs de días ──────────────────────────────────────────────
        TabBar(
          controller: _tabController,
          isScrollable: false,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: _horario!.dias.asMap().entries.map((e) {
            final esHoy = e.key == _diaHoy;
            return Tab(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.value.dia.substring(0, 2)),
                    if (esHoy) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),

        // ── Lista de bloques del día seleccionado ─────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _horario!.dias.map((dia) {
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                itemCount: dia.bloques.length,
                itemBuilder: (context, i) {
                  final bloque = dia.bloques[i];
                  final esReceso = bloque.materia
                          .toLowerCase()
                          .contains('recreo') ||
                      bloque.materia.toLowerCase().contains('receso');

                  if (esReceso) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Icon(Icons.coffee_rounded,
                              size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Text(
                            'RECREO  ${bloque.hora}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                                letterSpacing: 1),
                          ),
                          Expanded(
                              child: Divider(
                                  color: Colors.grey.shade300)),
                        ],
                      ),
                    );
                  }

                  final color = HorariosData.colorMateria(bloque.materia);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: color.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: color.withAlpha(60), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        // Franja de color izquierda
                        Container(
                          width: 4,
                          height: 56,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Hora
                        SizedBox(
                          width: 80,
                          child: Text(
                            bloque.hora,
                            style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Separador vertical
                        Container(
                          width: 1,
                          height: 32,
                          color: color.withAlpha(60),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                bloque.materia,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              if (bloque.profesor != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  bloque.profesor!,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.onSurfaceVariant.withAlpha(204),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Ícono pequeño de materia
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: color.withAlpha(30),
                            child: Text(
                              bloque.materia.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
