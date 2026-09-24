import 'package:flutter/material.dart';

import '../services/boletin_academico.dart';

/// Tabla en pantalla del Boletín Académico: las mismas columnas y datos que
/// el PDF (BoletinAcademico.imprimir), una fila por materia del curso.
class BoletinAcademicoTabla extends StatelessWidget {
  final List<FilaBoletin> filas;

  /// Si se pasa, agrega una columna con "Ver detalle" por materia.
  final void Function(FilaBoletin fila)? onVerDetalle;

  const BoletinAcademicoTabla({super.key, required this.filas, this.onVerDetalle});

  static const _colorCuatri1 = Color(0xFFE8F4FD);
  static const _colorCuatri2 = Color(0xFFF0F7EC);

  @override
  Widget build(BuildContext context) {
    if (filas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No hay materias cargadas para este curso.')),
      );
    }

    DataColumn col(String texto, {Color? color, bool negrita = false}) => DataColumn(
          label: Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: color,
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: negrita ? FontWeight.bold : FontWeight.w600),
            ),
          ),
        );

    DataCell celda(String v, {Color? color, bool negrita = false}) => DataCell(Container(
          width: 64,
          alignment: Alignment.center,
          color: color,
          child: Text(
            v.isEmpty ? '—' : v,
            style: TextStyle(
              fontSize: 12,
              fontWeight: negrita ? FontWeight.bold : FontWeight.normal,
              color: v.isEmpty ? Colors.grey.shade400 : null,
            ),
          ),
        ));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFD9E1F2)),
        headingRowHeight: 52,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 52,
        columnSpacing: 6,
        horizontalMargin: 10,
        columns: [
          const DataColumn(
            label: SizedBox(
              width: 170,
              child: Text('MATERIA', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          for (final c in kCriteriosBoletin) col(c.value),
          col('Nota\n1° Informe', color: _colorCuatri1),
          col('RITE\n1° Cuatrim.', color: _colorCuatri1),
          col('Nota\n1° Cuatrim.', color: _colorCuatri1, negrita: true),
          col('Nota\n2° Informe', color: _colorCuatri2),
          col('RITE\n2° Cuatrim.', color: _colorCuatri2),
          col('Nota\n2° Cuatrim.', color: _colorCuatri2, negrita: true),
          col('Intens.\nDic.'),
          col('Intens.\nFeb.'),
          col('Calif.\nFinal', negrita: true),
          if (onVerDetalle != null) const DataColumn(label: SizedBox(width: 90, child: Text(''))),
        ],
        rows: [
          for (final f in filas)
            DataRow(cells: [
              DataCell(SizedBox(
                width: 170,
                child: Text(f.materia.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              )),
              for (final c in kCriteriosBoletin) celda(f.criterio(c.key)),
              celda(f.nota1Informe, color: _colorCuatri1),
              celda(f.rite1Cuatri, color: _colorCuatri1, negrita: true),
              celda(f.nota1Cuatri, color: _colorCuatri1, negrita: true),
              celda(f.nota2Informe, color: _colorCuatri2),
              celda(f.rite2Cuatri, color: _colorCuatri2, negrita: true),
              celda(f.nota2Cuatri, color: _colorCuatri2, negrita: true),
              celda(f.intensDic),
              celda(f.intensFeb),
              celda(f.calFinal, negrita: true),
              if (onVerDetalle != null)
                DataCell(TextButton(
                  onPressed: () => onVerDetalle!(f),
                  child: const Text('Ver detalle', style: TextStyle(fontSize: 12)),
                )),
            ]),
        ],
      ),
    );
  }
}

/// Leyenda del boletín (la misma que el pie del PDF).
class BoletinAcademicoLeyenda extends StatelessWidget {
  const BoletinAcademicoLeyenda({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Text(
        'Apreciaciones: S: Sobresaliente – MB: Muy bueno – B: Bueno – R: Regular\n'
        'TEA: Trayectoria Educativa Avanzada – TEP: Trayectoria Educativa en Proceso – '
        'TED: Trayectoria Educativa Discontinua\n'
        '*AIC: Acuerdos Institucionales de Convivencia.',
        style: TextStyle(fontSize: 12, height: 1.5),
      ),
    );
  }
}
