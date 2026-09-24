import '../utils/logo_base64.dart';
import 'print_helper.dart';
import 'supabase_service.dart';

/// Alumno a incluir en el boletín. [dni] es opcional: si falta se toma de
/// los datos demográficos del legajo.
class BoletinAlumno {
  final String id;
  final String nombre;
  final String? dni;
  const BoletinAlumno({required this.id, required this.nombre, this.dni});
}

/// Una materia del boletín anual, ya resuelta: criterios del cierre y las
/// notas por etapa. La usan el PDF y las tablas en pantalla.
class FilaBoletin {
  final String materiaId;
  final String materia;
  /// clave de criterio (criterio_apropiacion, …) → S / MB / B / R
  final Map<String, String> criterios;
  final String nota1Informe;
  final String rite1Cuatri;
  final String nota1Cuatri;
  final String nota2Informe;
  final String rite2Cuatri;
  final String nota2Cuatri;
  final String intensDic;
  final String intensFeb;
  final String calFinal;

  const FilaBoletin({
    required this.materiaId,
    required this.materia,
    required this.criterios,
    required this.nota1Informe,
    required this.rite1Cuatri,
    required this.nota1Cuatri,
    required this.nota2Informe,
    required this.rite2Cuatri,
    required this.nota2Cuatri,
    required this.intensDic,
    required this.intensFeb,
    required this.calFinal,
  });

  String criterio(String key) => criterios[key] ?? '';
}

class DatosBoletin {
  final String identificadorDivision;
  final String dni;
  final List<FilaBoletin> filas;
  const DatosBoletin({required this.identificadorDivision, required this.dni, required this.filas});
}

/// Criterios en el orden del boletín, con su nombre corto para pantallas.
const List<MapEntry<String, String>> kCriteriosBoletin = [
  MapEntry('criterio_apropiacion', 'Apropiación'),
  MapEntry('criterio_resolucion', 'Resolución'),
  MapEntry('criterio_participacion', 'Participación'),
  MapEntry('criterio_planteos', 'Dudas'),
  MapEntry('criterio_entrega', 'Entrega'),
  MapEntry('criterio_prolijidad', 'Prolijidad'),
  MapEntry('criterio_aic', 'AIC'),
];

/// Boletín Académico oficial (el de la Planilla de Calificaciones). Es el
/// único formato de boletín de la app: lo usan Docente, Preceptoría/Dirección,
/// Administración y el Portal Familia, siempre con TODAS las materias del
/// curso del alumno.
///
/// Notas por etapa (aca_cierres_etapa, las carga el docente en el Boletín
/// Cualitativo): 1° SEGUIMIENTO = 1° informe, 1° CIERRE = 1° cuatrimestre,
/// 2° SEGUIMIENTO = 2° informe, 2° CIERRE = 2° cuatrimestre.
class BoletinAcademico {
  /// Datos del boletín anual de un alumno, para mostrarlo en pantalla con
  /// exactamente lo mismo que imprime el PDF. Todas las materias del curso.
  static Future<DatosBoletin> cargar({
    required SupabaseService service,
    required String cursoId,
    required BoletinAlumno alumno,
  }) async {
    final datos = await service.obtenerDatosBoletinCompleto(
      cursoId: cursoId,
      alumnosIds: [alumno.id],
    );
    final materias = _materiasOrdenadas(datos['materias']);
    final rubricas = List<Map<String, dynamic>>.from(datos['rubricas'] ?? []);
    final cierres = List<Map<String, dynamic>>.from(datos['cierres'] ?? []);
    final demo = Map<String, dynamic>.from(datos['alumnosDemoData'] ?? {});
    return DatosBoletin(
      identificadorDivision: datos['identificadorDivision']?.toString() ?? '',
      dni: _dniAlumno(alumno, demo[alumno.id] as Map<String, dynamic>?),
      filas: [
        for (final mat in materias)
          _filaAnual(alumnoId: alumno.id, mat: mat, rubricas: rubricas, cierres: cierres),
      ],
    );
  }

  static List<Map<String, dynamic>> _materiasOrdenadas(Object? materias) {
    final lista = List<Map<String, dynamic>>.from((materias as List?) ?? []);
    lista.sort((a, b) => (a['nombre_asignatura'] ?? '')
        .toString()
        .compareTo((b['nombre_asignatura'] ?? '').toString()));
    return lista;
  }

  static String _dniAlumno(BoletinAlumno alumno, Map<String, dynamic>? demo) {
    final d = alumno.dni;
    if (d != null && d.trim().isNotEmpty && !d.toLowerCase().contains('no cargado')) return d;
    return demo?['dni']?.toString() ?? '-';
  }

  static FilaBoletin _filaAnual({
    required String alumnoId,
    required Map<String, dynamic> mat,
    required List<Map<String, dynamic>> rubricas,
    required List<Map<String, dynamic>> cierres,
  }) {
    final matId = mat['materia_id'] as String;
    final rubricasMat =
        rubricas.where((r) => r['alumno_id'] == alumnoId && r['materia_id'] == matId).toList();
    Map<String, dynamic>? buscarRubrica(String et) {
      final m = rubricasMat.where((r) => r['etapa'] == et).toList();
      return m.isNotEmpty ? m.first : null;
    }

    final rubrica = buscarRubrica('1° CIERRE') ??
        buscarRubrica('1° SEGUIMIENTO') ??
        (rubricasMat.isNotEmpty ? rubricasMat.first : null);

    final cierresMat =
        cierres.where((c) => c['alumno_id'] == alumnoId && c['materia_id'] == matId).toList();
    Map<String, dynamic>? buscarCierre(String etapa) {
      final m = cierresMat.where((c) => c['etapa'] == etapa).toList();
      return m.isNotEmpty ? m.first : null;
    }

    final cierre1 = buscarCierre('1° CIERRE');
    final cierre2 = buscarCierre('2° CIERRE');
    String rite(Map<String, dynamic>? c) => c?['condicion_trayectoria']?.toString() ?? '';
    String unDecimal(Map<String, dynamic>? c) => c?['calificacion_numerica'] != null
        ? (c!['calificacion_numerica'] as num).toStringAsFixed(1)
        : '';

    final nota1 = (cierre1?['calificacion_numerica'] as num?)?.toDouble();
    final nota2 = (cierre2?['calificacion_numerica'] as num?)?.toDouble();
    String calFinal = '';
    if (nota1 != null && nota2 != null) {
      calFinal = ((nota1 + nota2) / 2).toStringAsFixed(1);
    } else if (nota1 != null) {
      calFinal = nota1.toStringAsFixed(1);
    } else if (nota2 != null) {
      calFinal = nota2.toStringAsFixed(1);
    }

    return FilaBoletin(
      materiaId: matId,
      materia: (mat['nombre_asignatura'] ?? 'Materia').toString(),
      criterios: {
        for (final c in kCriteriosBoletin) c.key: rubrica?[c.key]?.toString() ?? '',
      },
      nota1Informe: _nota(buscarCierre('1° SEGUIMIENTO')?['calificacion_numerica']),
      rite1Cuatri: rite(cierre1),
      nota1Cuatri: _nota(cierre1?['calificacion_numerica']),
      nota2Informe: _nota(buscarCierre('2° SEGUIMIENTO')?['calificacion_numerica']),
      rite2Cuatri: rite(cierre2),
      nota2Cuatri: _nota(cierre2?['calificacion_numerica']),
      intensDic: unDecimal(buscarCierre('INTENSIFICACION_DIC')),
      intensFeb: unDecimal(buscarCierre('INTENSIFICACION_FEB')),
      calFinal: calFinal,
    );
  }

  /// [tipoBoletin]: 'ANUAL' (por defecto), '1°C' o '2°C'.
  /// Devuelve un mensaje de error, o null si se abrió el boletín.
  static Future<String?> imprimir({
    required SupabaseService service,
    required String cursoId,
    required List<BoletinAlumno> alumnos,
    String tipoBoletin = 'ANUAL',
  }) async {
    if (alumnos.isEmpty) return 'No hay alumnos para imprimir.';

    final datos = await service.obtenerDatosBoletinCompleto(
      cursoId: cursoId,
      alumnosIds: alumnos.map((a) => a.id).toList(),
    );

    final List<Map<String, dynamic>> materiasCurso = _materiasOrdenadas(datos['materias']);
    final List<Map<String, dynamic>> rubricas =
        List<Map<String, dynamic>>.from(datos['rubricas'] ?? []);
    final List<Map<String, dynamic>> cierres =
        List<Map<String, dynamic>>.from(datos['cierres'] ?? []);
    final String identificadorDivision =
        datos['identificadorDivision']?.toString() ?? '';
    final Map<String, dynamic> alumnosDemoData =
        Map<String, dynamic>.from(datos['alumnosDemoData'] ?? {});

    if (materiasCurso.isEmpty) {
      return 'No se encontraron materias para este curso.';
    }

    final List<String> boletinesHtml = [];

    for (final alumno in alumnos) {
      final dni = _dniAlumno(alumno, alumnosDemoData[alumno.id] as Map<String, dynamic>?);

      final List<String> filasMaterias = [];

      for (final mat in materiasCurso) {
        final matId = mat['materia_id'] as String;
        final nombreMat =
            (mat['nombre_asignatura'] ?? 'Materia').toString().toUpperCase();

        final rubricasMat = rubricas
            .where((r) => r['alumno_id'] == alumno.id && r['materia_id'] == matId)
            .toList();

        final etapaSeg = tipoBoletin == '2°C' ? '2° SEGUIMIENTO' : '1° SEGUIMIENTO';
        final etapaCierre = tipoBoletin == '2°C' ? '2° CIERRE' : '1° CIERRE';

        Map<String, dynamic>? buscarRubrica(String et) =>
            rubricasMat.where((r) => r['etapa'] == et).isNotEmpty
                ? rubricasMat.firstWhere((r) => r['etapa'] == et)
                : null;

        final rubricaSeg = buscarRubrica(etapaSeg);
        final rubricaCierre = buscarRubrica(etapaCierre);

        final cierresMat = cierres
            .where((c) => c['alumno_id'] == alumno.id && c['materia_id'] == matId)
            .toList();

        Map<String, dynamic>? buscarCierre(String etapa) {
          final matches = cierresMat.where((c) => c['etapa'] == etapa).toList();
          return matches.isNotEmpty ? matches.first : null;
        }

        final seg1 = buscarCierre('1° SEGUIMIENTO');
        final cierre1 = buscarCierre('1° CIERRE');
        final seg2 = buscarCierre('2° SEGUIMIENTO');
        final cierre2 = buscarCierre('2° CIERRE');
        final cierreDic = buscarCierre('INTENSIFICACION_DIC');
        final cierreFeb = buscarCierre('INTENSIFICACION_FEB');

        String crs(String key) => rubricaSeg?[key]?.toString() ?? '';
        String crc(String key) => rubricaCierre?[key]?.toString() ?? '';

        String formatNota(Map<String, dynamic>? c) =>
            c?['calificacion_numerica'] != null
                ? (c!['calificacion_numerica'] as num).toStringAsFixed(1)
                : '';
        String notaEntera(Map<String, dynamic>? c) => _nota(c?['calificacion_numerica']);
        String rite(Map<String, dynamic>? c) =>
            c?['condicion_trayectoria']?.toString() ?? '';

        if (tipoBoletin == 'ANUAL') {
          final f = _filaAnual(alumnoId: alumno.id, mat: mat, rubricas: rubricas, cierres: cierres);
          filasMaterias.add('''
              <tr>
                <td class="td-mat">$nombreMat</td>
                ${kCriteriosBoletin.map((c) => '<td class="td-c">${f.criterio(c.key)}</td>').join()}
                <td class="td-c"></td>
                <td class="td-c td-inf">${f.nota1Informe}</td>
                <td class="td-c td-tray">${f.rite1Cuatri}</td>
                <td class="td-c td-final">${f.nota1Cuatri}</td>
                <td class="td-c td-inf">${f.nota2Informe}</td>
                <td class="td-c td-tray">${f.rite2Cuatri}</td>
                <td class="td-c td-final">${f.nota2Cuatri}</td>
                <td class="td-c">${f.intensDic}</td>
                <td class="td-c">${f.intensFeb}</td>
                <td class="td-c td-final">${f.calFinal}</td>
              </tr>
            ''');
        } else {
          final cierreCuat = tipoBoletin == '2°C' ? cierre2 : cierre1;
          final cierreSeg = tipoBoletin == '2°C' ? seg2 : seg1;
          String calFinal = '';
          if (tipoBoletin == '2°C') {
            final n1 = (cierre1?['calificacion_numerica'] as num?)?.toDouble();
            final n2 = (cierre2?['calificacion_numerica'] as num?)?.toDouble();
            if (n1 != null && n2 != null) {
              calFinal = ((n1 + n2) / 2).toStringAsFixed(1);
            } else if (n2 != null) {
              calFinal = n2.toStringAsFixed(1);
            }
          }
          final colsExtra = tipoBoletin == '2°C'
              ? '<td class="td-c">${formatNota(cierreDic)}</td><td class="td-c">${formatNota(cierreFeb)}</td><td class="td-c td-final">$calFinal</td>'
              : '';
          filasMaterias.add('''
              <tr>
                <td class="td-mat">$nombreMat</td>
                <td class="td-c">${crs('criterio_apropiacion')}</td>
                <td class="td-c">${crs('criterio_resolucion')}</td>
                <td class="td-c">${crs('criterio_participacion')}</td>
                <td class="td-c">${crs('criterio_planteos')}</td>
                <td class="td-c">${crs('criterio_entrega')}</td>
                <td class="td-c">${crs('criterio_prolijidad')}</td>
                <td class="td-c">${crs('criterio_aic')}</td>
                <td class="td-c"></td>
                <td class="td-c td-tray">${rite(cierreSeg)}</td>
                <td class="td-c td-final">${notaEntera(cierreSeg)}</td>
                <td class="td-c">${crc('criterio_apropiacion')}</td>
                <td class="td-c">${crc('criterio_resolucion')}</td>
                <td class="td-c">${crc('criterio_participacion')}</td>
                <td class="td-c">${crc('criterio_planteos')}</td>
                <td class="td-c">${crc('criterio_entrega')}</td>
                <td class="td-c">${crc('criterio_prolijidad')}</td>
                <td class="td-c">${crc('criterio_aic')}</td>
                <td class="td-c"></td>
                <td class="td-c td-tray">${rite(cierreCuat)}</td>
                <td class="td-c td-final">${notaEntera(cierreCuat)}</td>
                $colsExtra
              </tr>
            ''');
        }
      }

      final tablaMateriaHtml = filasMaterias.join('');

      final String tablaHeader;
      final String tablaFooter;
      if (tipoBoletin == 'ANUAL') {
        tablaHeader = '''
            <tr>
              <th rowspan="2" class="th-mat">MATERIA</th>
              <th colspan="8" class="th-group">CRITERIOS</th>
              <th colspan="3" class="th-group th-grp-seg">1° CUATRIMESTRE</th>
              <th colspan="3" class="th-group th-grp-cie">2° CUATRIMESTRE</th>
              <th colspan="3" class="th-group">CIERRE DEL AÑO</th>
            </tr>
            <tr>
              <th class="th-r"><span class="rot">Apropiación de los contenidos trabajados</span></th>
              <th class="th-r"><span class="rot">Resolución de actividades propuestas</span></th>
              <th class="th-r"><span class="rot">Participación en clases</span></th>
              <th class="th-r"><span class="rot">Planteos de dudas y sugerencias</span></th>
              <th class="th-r"><span class="rot">Entrega en tiempo y forma</span></th>
              <th class="th-r"><span class="rot">Prolijidad y carpeta completa</span></th>
              <th class="th-r"><span class="rot">Cumplimiento de los AIC*</span></th>
              <th class="th-r th-inas"><span class="rot">TOTAL INAS.</span></th>
              <th class="th-r th-grp-seg th-cal"><span class="rot">NOTA 1° INFORME</span></th>
              <th class="th-r th-grp-seg th-cal"><span class="rot">RITE 1° CUATRIM.</span></th>
              <th class="th-r th-grp-seg th-cal"><span class="rot">NOTA 1° CUATRIM.</span></th>
              <th class="th-r th-grp-cie th-cal"><span class="rot">NOTA 2° INFORME</span></th>
              <th class="th-r th-grp-cie th-cal"><span class="rot">RITE 2° CUATRIM.</span></th>
              <th class="th-r th-grp-cie th-cal"><span class="rot">NOTA 2° CUATRIM.</span></th>
              <th class="th-r"><span class="rot">INTENS. DICIEMBRE</span></th>
              <th class="th-r"><span class="rot">INTENS. FEBRERO</span></th>
              <th class="th-r"><span class="rot">CALIFICACIÓN FINAL</span></th>
            </tr>''';
        tablaFooter = '''
            <tr>
              <td class="td-foot" colspan="9">TOTAL DE INASISTENCIAS DIARIAS</td>
              <td class="td-c" colspan="9"></td>
            </tr>
            <tr>
              <td class="td-foot" colspan="18" style="height:28px;">INFORME DE PRECEPTORÍA</td>
            </tr>''';
      } else {
        final labelCuat = tipoBoletin == '1°C' ? '1° CUATRIMESTRE' : '2° CUATRIMESTRE';
        final labelInf = tipoBoletin == '1°C' ? '1° INFORME' : '2° INFORME';
        final colsExtraHeader = tipoBoletin == '2°C'
            ? '<th colspan="3" class="th-group">INTENSIFICACIONES</th>'
            : '';
        final colsExtraHeader2 = tipoBoletin == '2°C'
            ? '<th class="th-r"><span class="rot">INTENS. DIC</span></th>'
                '<th class="th-r"><span class="rot">INTENS. FEB</span></th>'
                '<th class="th-r"><span class="rot">CAL. FINAL</span></th>'
            : '';
        final totalColsCuat = tipoBoletin == '2°C' ? 24 : 21;
        tablaHeader = '''
            <tr>
              <th rowspan="2" class="th-mat">MATERIA</th>
              <th colspan="10" class="th-group">$labelInf (SEGUIMIENTO)</th>
              <th colspan="10" class="th-group">CIERRE — $labelCuat</th>
              $colsExtraHeader
            </tr>
            <tr>
              <th class="th-r th-grp-seg"><span class="rot">Apropiación de los contenidos trabajados</span></th>
              <th class="th-r th-grp-seg"><span class="rot">Resolución de actividades propuestas</span></th>
              <th class="th-r th-grp-seg"><span class="rot">Participación en clases</span></th>
              <th class="th-r th-grp-seg"><span class="rot">Planteos de dudas y sugerencias</span></th>
              <th class="th-r th-grp-seg"><span class="rot">Entrega en tiempo y forma</span></th>
              <th class="th-r th-grp-seg"><span class="rot">Prolijidad y carpeta completa</span></th>
              <th class="th-r th-grp-seg"><span class="rot">Cumplimiento de los AIC*</span></th>
              <th class="th-r th-grp-seg th-inas"><span class="rot">INAS.</span></th>
              <th class="th-r th-grp-seg th-cal"><span class="rot">RITE</span></th>
              <th class="th-r th-grp-seg th-cal"><span class="rot">NOTA INFORME</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Apropiación de los contenidos trabajados</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Resolución de actividades propuestas</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Participación en clases</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Planteos de dudas y sugerencias</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Entrega en tiempo y forma</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Prolijidad y carpeta completa</span></th>
              <th class="th-r th-grp-cie"><span class="rot">Cumplimiento de los AIC*</span></th>
              <th class="th-r th-grp-cie th-inas"><span class="rot">INAS.</span></th>
              <th class="th-r th-grp-cie th-cal"><span class="rot">RITE</span></th>
              <th class="th-r th-grp-cie th-cal"><span class="rot">NOTA CUATRIM.</span></th>
              $colsExtraHeader2
            </tr>''';
        tablaFooter = '''
            <tr>
              <td class="td-foot" colspan="$totalColsCuat" style="height:20px;">INFORME DE PRECEPTORÍA</td>
            </tr>''';
      }

      boletinesHtml.add('''
          <div class="boletin-page">

            <!-- ===== ENCABEZADO ===== -->
            <div class="header-wrap" style="position:relative;">
              <div class="header-left">
                <img src="$kLogoBase64" alt="Logo Instituto" style="height:100px; width:auto; object-fit:contain;">
                <div class="inst-sep"></div>
                <div class="inst-loc">B&nbsp;A&nbsp;R&nbsp;A&nbsp;D&nbsp;E&nbsp;R&nbsp;O</div>
              </div>
              <div class="header-center">BOLETÍN ACADÉMICO</div>
              <div class="header-right">NIVEL SECUNDARIO</div>
            </div>
            <hr class="hr-thin">

            <!-- ===== DATOS DEL ALUMNO ===== -->
            <div class="alumno-row">
              <span><span class="lbl">ALUMNO/A:</span>&nbsp;<strong>${_esc(alumno.nombre.toUpperCase())}</strong></span>
              <span><span class="lbl">DNI:</span>&nbsp;<strong>${_esc(dni)}</strong></span>
              <span><span class="lbl">AÑO:</span>&nbsp;<strong>${_esc(identificadorDivision)}</strong></span>
            </div>

            <!-- ===== TABLA PRINCIPAL ===== -->
            <table class="tbl">
              <thead>
                $tablaHeader
              </thead>
              <tbody>
                $tablaMateriaHtml
                $tablaFooter
              </tbody>
            </table>

            <!-- ===== FIRMAS ===== -->
            <div class="firmas">
              <div class="firma"><div class="firma-linea"></div>Firma Dirección</div>
              <div class="firma"><div class="firma-linea"></div>Firma Docente / Preceptor</div>
              <div class="firma"><div class="firma-linea"></div>Firma Madre / Padre / Tutor</div>
            </div>

            <!-- ===== LEYENDA ===== -->
            <div class="leyenda">
              <strong>Apreciaciones:</strong>&nbsp; S: Sobresaliente &ndash; MB: Muy bueno &ndash; B: Bueno &ndash; R: Regular<br>
              <strong>TEA:</strong> Trayectoria Educativa Avanzada &nbsp;&ndash;&nbsp;
              <strong>TEP:</strong> Trayectoria Educativa en Proceso &nbsp;&ndash;&nbsp;
              <strong>TED:</strong> Trayectoria Educativa Discontinua<br>
              <strong>*AIC:</strong> Acuerdos Institucionales de Convivencia.&nbsp;&nbsp;
              <strong>*INASISTENCIAS:</strong> Actualización según Resolución 1650/24 Régimen Académico; tardanzas se computará &frac14; de falta, total de inasistencias anuales 28.
            </div>

            <!-- ===== PIE INSTITUCIONAL ===== -->
            <div class="pie-inst">
              DIEGEP 8942 &nbsp;&bull;&nbsp; Jujuy y Saavedra, (2942) Baradero, Buenos Aires, Argentina<br>
              +54 9 3329 489305 &nbsp;&bull;&nbsp; iabar.educacionadventista.com &nbsp;&bull;&nbsp; instituto.iabar@educacionadventista.org.ar
            </div>

          </div>
        ''');
    }

    PrintHelper.imprimirHTML(
      titulo: alumnos.length == 1 ? 'Boletín - ${alumnos.first.nombre}' : 'Boletín',
      mostrarEncabezado: false,
      htmlContentBody: '''
          <style>$_css</style>
          ${boletinesHtml.join('')}
        ''',
    );
    return null;
  }

  /// Nota de etapa: entera si no tiene decimales (7), si no con uno (7.5).
  static String _nota(Object? v) {
    if (v is! num) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  static String _esc(String v) =>
      v.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static const String _css = '''
            @page { size: A4 landscape; margin: 4mm; }
            * { box-sizing: border-box; }
            body { font-family: Arial, Helvetica, sans-serif; font-size: 10px; color: #111; margin: 0; padding: 0; }

            .boletin-page {
              padding: 2mm 3mm;
              page-break-after: always;
              background: #fff;
            }

            /* --- ENCABEZADO --- */
            .header-wrap {
              display: flex;
              justify-content: space-between;
              align-items: center;
              margin-bottom: 1px;
            }
            .header-left { display: flex; align-items: center; gap: 8px; }
            .inst-sep { width: 1px; height: 36px; background: #bbb; }
            .inst-loc { font-size: 10px; letter-spacing: 2px; color: #1565C0; font-weight: bold; }
            .header-center {
              position: absolute; left: 50%; transform: translateX(-50%);
              font-size: 13px; font-weight: bold; color: #111;
              letter-spacing: 1px;
            }
            .header-right { font-size: 14px; font-weight: bold; letter-spacing: 1px; }
            .hr-thin { border: none; border-top: 1.5px solid #1565C0; margin: 1px 0 3px; }

            /* --- ALUMNO --- */
            .alumno-row {
              display: flex;
              justify-content: flex-end;
              align-items: center;
              font-size: 12px;
              margin-bottom: 3px;
              gap: 20px;
            }
            .lbl { font-weight: bold; }

            /* --- TABLA --- */
            .tbl {
              width: 100%;
              margin: 0;
              border-collapse: collapse;
              table-layout: fixed;
            }
            .tbl th, .tbl td { border: 1px solid #333; }

            .th-mat {
              background: #D9E1F2; font-weight: bold;
              text-align: center; vertical-align: middle;
              font-size: 10px; padding: 2px 3px;
              width: 13%;
            }
            .th-group {
              background: #D9E1F2; font-weight: bold;
              text-align: center; font-size: 10px; padding: 2px;
            }
            .th-r {
              width: 4.2%; padding: 2px 1px;
              vertical-align: middle; text-align: center;
              background: #fff;
            }
            .th-inas { width: 2.8% !important; }
            .th-cal  { width: 3.8% !important; }
            .th-grp-seg { background: #E8F4FD; }
            .th-grp-cie { background: #F0F7EC; }
            .rot {
              display: block;
              font-size: 7.5px;
              font-weight: bold;
              white-space: normal;
              word-break: break-word;
              line-height: 1.2;
            }

            .td-mat {
              text-align: left; font-weight: bold;
              font-size: 10px; padding: 3px 4px;
            }
            .td-c {
              text-align: center; font-size: 10px;
              padding: 2px 1px;
            }
            .td-tray { font-weight: bold; font-size: 9px; }
            .td-inf { font-size: 10px; }
            .td-final { font-weight: bold; font-size: 10px; }
            .td-foot {
              background: #f2f2f2; font-weight: bold;
              font-size: 9.5px; padding: 2px 4px;
              text-align: left;
            }

            /* --- FIRMAS --- */
            .firmas {
              display: flex;
              justify-content: space-around;
              margin-top: 10px;
              text-align: center;
              font-size: 11px;
            }
            .firma { width: 26%; }
            .firma-linea {
              border-top: 1.5px solid #444;
              margin: 32px 0 4px;
            }

            /* --- LEYENDA --- */
            .leyenda {
              margin-top: 4px;
              border-top: 1px solid #ccc;
              padding-top: 2px;
              font-size: 8.5px;
              line-height: 1.4;
            }

            /* --- PIE INSTITUCIONAL --- */
            .pie-inst {
              margin-top: 3px;
              border-top: 1px solid #1565C0;
              padding-top: 2px;
              text-align: center;
              font-size: 8px;
              color: #444;
              line-height: 1.5;
            }
  ''';
}
