import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// Detalle + historial de una materia adeudada (Intensifica / Recursa /
/// Adeuda Previa). Lo abre tanto Dirección (panel_materias_adeudadas.dart)
/// como el docente titular de la materia original, desde su propio panel —
/// la política RLS es la que decide quién puede además cargar un período.
Future<void> mostrarGestionAdeudada(
  BuildContext context, {
  required Map<String, dynamic> adeudada,
  required String nombreAlumno,
  VoidCallback? onCambio,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _GestionAdeudadaSheet(adeudada: adeudada, nombreAlumno: nombreAlumno, onCambio: onCambio),
  );
}

class _GestionAdeudadaSheet extends StatefulWidget {
  final Map<String, dynamic> adeudada;
  final String nombreAlumno;
  final VoidCallback? onCambio;

  const _GestionAdeudadaSheet({required this.adeudada, required this.nombreAlumno, this.onCambio});

  @override
  State<_GestionAdeudadaSheet> createState() => _GestionAdeudadaSheetState();
}

class _GestionAdeudadaSheetState extends State<_GestionAdeudadaSheet> {
  final _service = SupabaseService();
  bool _loading = true;
  List<Map<String, dynamic>> _periodos = [];
  late Map<String, dynamic> _adeudada;

  @override
  void initState() {
    super.initState();
    _adeudada = widget.adeudada;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      _periodos = await _service.obtenerPeriodosAdeudada(_adeudada['adeudada_id'].toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _agregarPeriodo() async {
    final periodoCtrl = TextEditingController();
    final notaCtrl = TextEditingController();
    String resultado = 'PENDIENTE';
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Registrar mesa / período'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: periodoCtrl,
                decoration: const InputDecoration(labelText: 'Período', hintText: 'Ej. Febrero 2026, Mesa de Marzo...'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notaCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Nota (opcional)', hintText: 'Ej. 7.0'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: resultado,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Resultado'),
                items: const [
                  DropdownMenuItem(value: 'PENDIENTE', child: Text('Pendiente')),
                  DropdownMenuItem(value: 'APROBADO', child: Text('Aprobado')),
                  DropdownMenuItem(value: 'DESAPROBADO', child: Text('Desaprobado')),
                ],
                onChanged: (v) => setD(() => resultado = v ?? resultado),
              ),
              if (resultado == 'APROBADO')
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Al guardar como Aprobado, la materia pasa a la ficha del alumno como materia aprobada.',
                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: guardando ? null : () => Navigator.pop(dCtx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (periodoCtrl.text.trim().isEmpty) return;
                      setD(() => guardando = true);
                      try {
                        await _service.agregarPeriodoAdeudada(
                          adeudadaId: _adeudada['adeudada_id'].toString(),
                          periodo: periodoCtrl.text.trim(),
                          nota: double.tryParse(notaCtrl.text.replaceAll(',', '.')),
                          resultado: resultado,
                        );
                        if (resultado == 'APROBADO') _adeudada['estado'] = 'APROBADA';
                        if (dCtx.mounted) Navigator.pop(dCtx);
                        await _cargar();
                        widget.onCambio?.call();
                        if (mounted) setState(() {});
                      } catch (e) {
                        setD(() => guardando = false);
                        if (dCtx.mounted) {
                          ScaffoldMessenger.of(dCtx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        }
                      }
                    },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorResultado(String r) {
    switch (r) {
      case 'APROBADO':
        return Colors.green;
      case 'DESAPROBADO':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final condicion = (_adeudada['condicion'] ?? '').toString();
    final esIntensificaOPrevia =
        condicion == SupabaseService.kCondicionIntensifica || condicion == SupabaseService.kCondicionPreviaLibre;
    final aprobada = (_adeudada['estado'] ?? '') == 'APROBADA';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(widget.nombreAlumno, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text('${_adeudada['nombre_materia'] ?? ''} · Año origen: ${_adeudada['anio_origen'] ?? '-'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(SupabaseService.labelCondicionAdeudada(condicion)),
                    backgroundColor: Colors.deepPurple.withAlpha(25),
                  ),
                  Chip(
                    label: Text(aprobada ? 'APROBADA' : 'PENDIENTE'),
                    backgroundColor: (aprobada ? Colors.green : Colors.orange).withAlpha(30),
                    labelStyle: TextStyle(color: aprobada ? Colors.green.shade800 : Colors.orange.shade800, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 28),
              Expanded(
                child: !esIntensificaOPrevia
                    ? SingleChildScrollView(
                        controller: scrollController,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withAlpha(60)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Colors.blue),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Está recursando esta materia: la cursa de nuevo este año. El docente titular le carga '
                                  'notas como a cualquier alumno, desde la Planilla de Calificaciones de esa materia.',
                                  style: TextStyle(fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _loading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Historial de mesas / coloquios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  TextButton.icon(
                                    onPressed: _agregarPeriodo,
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: const Text('Agregar período', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: _periodos.isEmpty
                                    ? const Center(
                                        child: Text('Todavía no hay períodos registrados.', style: TextStyle(color: Colors.grey)),
                                      )
                                    : ListView.builder(
                                        controller: scrollController,
                                        itemCount: _periodos.length,
                                        itemBuilder: (context, index) {
                                          final p = _periodos[index];
                                          final resultado = (p['resultado'] ?? 'PENDIENTE').toString();
                                          final color = _colorResultado(resultado);
                                          return Card(
                                            elevation: 0,
                                            margin: const EdgeInsets.only(bottom: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              side: BorderSide(color: color.withAlpha(80)),
                                            ),
                                            child: ListTile(
                                              dense: true,
                                              title: Text(p['periodo']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              subtitle: Text(p['nota'] != null ? 'Nota: ${p['nota']}' : 'Sin nota registrada'),
                                              trailing: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                                                child: Text(resultado, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
