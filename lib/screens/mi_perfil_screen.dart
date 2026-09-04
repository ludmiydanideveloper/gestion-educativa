import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/print_helper.dart';
import '../widgets/app_drawer.dart';

class MiPerfilScreen extends StatefulWidget {
  final String rol;
  const MiPerfilScreen({super.key, required this.rol});

  @override
  State<MiPerfilScreen> createState() => _MiPerfilScreenState();
}

class _MiPerfilScreenState extends State<MiPerfilScreen> with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  late TabController _tabController;
  bool _isLoading = true;

  // Datos personales
  final _telefonoController = TextEditingController();
  final _domicilioController = TextEditingController();
  final _tituloController = TextEditingController();
  final _especialidadController = TextEditingController();
  String _email = '';
  String _nombreCompleto = '';
  String _authId = '';

  // Archivos
  List<Map<String, dynamic>> _archivosDdjj = [];
  List<Map<String, dynamic>> _archivosCv = [];
  List<Map<String, dynamic>> _archivosCertificados = [];
  bool _uploading = false;

  /// Devoluciones de supervisión recibidas (usr_observaciones_aulicas)
  List<Map<String, dynamic>> _observacionesRecibidasDirectiva = [];

  /// Faltas y licencias del docente (usr_docente_inasistencias)
  List<Map<String, dynamic>> _inasistencias = [];
  Map<String, dynamic> _resumenInasistencias = const {
    'injustificadas': 0,
    'licencias': 0,
    'presentismo': 100,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _cargarDatosPerfil();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _telefonoController.dispose();
    _domicilioController.dispose();
    _tituloController.dispose();
    _especialidadController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosPerfil() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _authId = user.id;
        _email = user.email ?? '';

        // Buscar datos en usr_docentes si existe
        final res = await Supabase.instance.client
            .from('usr_docentes')
            .select('*')
            .eq('auth_id', _authId)
            .maybeSingle();

        if (res != null) {
          _nombreCompleto = '${res['nombre'] ?? ''} ${res['apellido'] ?? ''}'.trim();
          if (_nombreCompleto.isEmpty) _nombreCompleto = _email;
          _telefonoController.text = res['telefono']?.toString() ?? '';
          _domicilioController.text = res['domicilio']?.toString() ?? '';
          _tituloController.text = res['titulo_profesional']?.toString() ?? '';
          _especialidadController.text = res['especialidad']?.toString() ?? '';
        } else {
          _nombreCompleto = _email;
        }

        // Cargar archivos de DDJJ, CV y Certificados
        final archivos = await _supabaseService.obtenerArchivosPersonal(_authId);
        final inasistencias = await _supabaseService.obtenerInasistenciasDocente(_authId);
        final observaciones = await _supabaseService.obtenerObservacionesAulicas(_authId);

        if (!mounted) return;
        setState(() {
          _archivosDdjj = archivos.where((a) => a['tipo_archivo'] == 'DDJJ').toList();
          _archivosCv = archivos.where((a) => a['tipo_archivo'] == 'CV').toList();
          _archivosCertificados = archivos.where((a) => a['tipo_archivo'] == 'CERTIFICADO').toList();
          _inasistencias = inasistencias;
          _resumenInasistencias = _supabaseService.resumirInasistencias(inasistencias);
          _observacionesRecibidasDirectiva = observaciones;
        });
      }
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarDatosPersonales() async {
    setState(() => _isLoading = true);
    try {
      if (_authId.isNotEmpty) {
        await _supabaseService.actualizarMiPerfilDocente(
          telefono: _telefonoController.text.trim(),
          domicilio: _domicilioController.text.trim(),
          tituloProfesional: _tituloController.text.trim(),
          especialidad: _especialidadController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Datos personales actualizados con éxito'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _seleccionarYSubirArchivoWeb(String tipoArchivo) {
    if (_uploading) return;
    setState(() => _uploading = true);
    PrintHelper.seleccionarArchivoWeb(
      onArchivoSeleccionado: (nombreArchivo, formato, base64Data) async {
        try {
          await _supabaseService.guardarArchivoPersonal(
            authId: _authId,
            tipoArchivo: tipoArchivo,
            nombreArchivo: nombreArchivo,
            formato: formato,
            base64Data: base64Data,
          );
          await _cargarDatosPerfil();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ $tipoArchivo ($nombreArchivo) subido y registrado exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (err) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al guardar archivo: $err'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _uploading = false);
        }
      },
      onError: (err) {
        debugPrint('Error en selector web: $err');
        if (mounted) setState(() => _uploading = false);
      },
    );
  }

  void _abrirODescargarArchivo(Map<String, dynamic> archivo) {
    final base64Data = archivo['datos_base64'] as String?;
    if (base64Data != null && base64Data.isNotEmpty) {
      // Abrir en nueva pestaña o descargar
      PrintHelper.abrirArchivoWeb(base64Data);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el contenido del archivo.'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _eliminarArchivo(String id, String nombre) async {
    final confirmo = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Archivo'),
        content: Text('¿Está seguro que desea eliminar "$nombre"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmo == true) {
      await _supabaseService.eliminarArchivoPersonal(id);
      await _cargarDatosPerfil();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colorPrincipal = colorScheme.primary;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: AppDrawer.buildLeading(context),
        leadingWidth: AppDrawer.buildLeadingWidth(context),
        title: Text(
          MediaQuery.of(context).size.width < 700
              ? 'Mi Perfil'
              : 'Mi Perfil Profesional - ${widget.rol}',
          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          labelColor: colorScheme.primary,
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.person_rounded), text: 'Datos Personales'),
            Tab(icon: Icon(Icons.co_present_rounded), text: 'Observaciones de Clases / Devoluciones'),
            Tab(icon: Icon(Icons.event_busy_rounded), text: 'Faltas y Certificados'),
            Tab(icon: Icon(Icons.description_rounded), text: 'Declaración Jurada (DDJJ)'),
            Tab(icon: Icon(Icons.work_history_rounded), text: 'Currículum Vitae (CV)'),
          ],
        ),
      ),
      drawer: AppDrawer(rolOverride: widget.rol),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDatosPersonalesTab(colorPrincipal),
                _buildSupervisionAulicaDocenteTab(colorPrincipal),
                _buildFaltasYCertificadosTab(colorPrincipal),
                _buildArchivosTab('DDJJ', _archivosDdjj, colorPrincipal),
                _buildArchivosTab('CV', _archivosCv, colorPrincipal),
              ],
            ),
    );
  }

  Widget _buildDatosPersonalesTab(Color colorPrincipal) {
    final esMovil = MediaQuery.of(context).size.width < 700;

    Widget campo(TextEditingController ctrl, String label, IconData icono) {
      return TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icono),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: esMovil,
        ),
      );
    }

    // En celular los campos van uno debajo del otro: en dos columnas la
    // etiqueta se recortaba a "Telé..." / "Do...".
    Widget parDeCampos(Widget a, Widget b) {
      if (esMovil) {
        return Column(children: [a, const SizedBox(height: 16), b]);
      }
      return Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: 16),
          Expanded(child: b),
        ],
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(esMovil ? 14 : 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(esMovil ? 18 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: esMovil ? 26 : 36,
                        backgroundColor: colorPrincipal.withOpacity(0.15),
                        child: Icon(Icons.person_pin_rounded, size: esMovil ? 34 : 48, color: colorPrincipal),
                      ),
                      SizedBox(width: esMovil ? 14 : 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nombreCompleto,
                              style: TextStyle(
                                fontSize: esMovil ? 17 : 24,
                                fontWeight: FontWeight.bold,
                                color: colorPrincipal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rol: ${widget.rol}',
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                            Text(
                              _email,
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Divider(height: esMovil ? 28 : 40),
                  const Text('Información Profesional y de Contacto',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 18),
                  parDeCampos(
                    campo(_telefonoController, 'Teléfono / Celular de Contacto', Icons.phone_rounded),
                    campo(_domicilioController, 'Domicilio Particular', Icons.home_rounded),
                  ),
                  const SizedBox(height: 16),
                  parDeCampos(
                    campo(_tituloController, 'Título Profesional Principal', Icons.school_rounded),
                    campo(_especialidadController, 'Especialidad / Área Pedagógica', Icons.stars_rounded),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorPrincipal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: const Text(
                        'GUARDAR Y ACTUALIZAR DATOS',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _guardarDatosPersonales,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Faltas y licencias ────────────────────────────────────────────────

  String _fechaCorta(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _rangoFechas(Map<String, dynamic> i) {
    final desde = _fechaCorta(i['fecha_desde']?.toString());
    final hasta = _fechaCorta(i['fecha_hasta']?.toString());
    if (hasta.isEmpty || hasta == desde) return desde;
    return '$desde al $hasta';
  }

  Color _colorTipoInasistencia(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'INJUSTIFICADA':
        return Colors.red.shade700;
      case 'LICENCIA':
        return Colors.blue.shade700;
      default:
        return Colors.green.shade700;
    }
  }

  String _etiquetaTipoInasistencia(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'INJUSTIFICADA':
        return 'Falta injustificada';
      case 'LICENCIA':
        return 'Licencia';
      default:
        return 'Falta justificada';
    }
  }

  /// Alta de una falta o licencia, con certificado opcional adjunto.
  void _abrirModalNuevaInasistencia() {
    String tipo = 'LICENCIA';
    DateTime desde = DateTime.now();
    DateTime hasta = DateTime.now();
    final motivoCtrl = TextEditingController();
    final obsCtrl = TextEditingController();

    String? archivoId;
    String? archivoNombre;
    bool subiendo = false;
    bool guardando = false;

    final size = MediaQuery.of(context).size;
    final ancho = size.width < 560 ? size.width - 64 : 460.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          Future<void> elegirFecha(bool esDesde) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: esDesde ? desde : hasta,
              firstDate: DateTime(DateTime.now().year - 2),
              lastDate: DateTime(DateTime.now().year + 1, 12, 31),
            );
            if (picked == null) return;
            setDialog(() {
              if (esDesde) {
                desde = picked;
                if (hasta.isBefore(desde)) hasta = desde;
              } else {
                hasta = picked.isBefore(desde) ? desde : picked;
              }
            });
          }

          Widget selectorFecha(String etiqueta, DateTime valor, bool esDesde) {
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => elegirFecha(esDesde),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: etiqueta,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_fechaCorta(valor.toIso8601String()),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.event_busy_rounded, color: Colors.indigo),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Registrar Falta o Licencia',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ),
              ],
            ),
            content: SizedBox(
              width: ancho,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: tipo,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Tipo',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'LICENCIA', child: Text('Licencia')),
                        DropdownMenuItem(value: 'JUSTIFICADA', child: Text('Falta justificada')),
                        DropdownMenuItem(value: 'INJUSTIFICADA', child: Text('Falta injustificada')),
                      ],
                      onChanged: (v) => setDialog(() => tipo = v ?? 'LICENCIA'),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        selectorFecha('Desde', desde, true),
                        const SizedBox(width: 10),
                        selectorFecha('Hasta', hasta, false),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: motivoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Motivo',
                        hintText: 'Ej. Licencia médica, trámite personal',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: obsCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Observaciones (opcional)',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: archivoId != null ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: archivoId != null ? Colors.green.shade300 : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Certificado respaldatorio',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            archivoNombre ?? 'Opcional — queda guardado en "Archivos Cargados".',
                            style: TextStyle(
                              fontSize: 12,
                              color: archivoId != null ? Colors.green.shade900 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: subiendo
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : Icon(archivoId != null
                                      ? Icons.check_circle_rounded
                                      : Icons.attach_file_rounded),
                              label: Text(archivoId != null
                                  ? 'Reemplazar certificado'
                                  : 'Adjuntar certificado (Word / PDF)'),
                              onPressed: subiendo
                                  ? null
                                  : () {
                                      setDialog(() => subiendo = true);
                                      PrintHelper.seleccionarArchivoWeb(
                                        onArchivoSeleccionado:
                                            (nombreArchivo, formato, base64Data) async {
                                          try {
                                            final id = await _supabaseService.guardarArchivoPersonal(
                                              authId: _authId,
                                              tipoArchivo: 'CERTIFICADO',
                                              nombreArchivo: nombreArchivo,
                                              formato: formato,
                                              base64Data: base64Data,
                                            );
                                            setDialog(() {
                                              archivoId = id;
                                              archivoNombre = nombreArchivo;
                                              subiendo = false;
                                            });
                                          } catch (e) {
                                            setDialog(() => subiendo = false);
                                            if (ctx.mounted) {
                                              ScaffoldMessenger.of(ctx).showSnackBar(
                                                SnackBar(
                                                    content: Text('No se pudo subir el certificado: $e'),
                                                    backgroundColor: Colors.red),
                                              );
                                            }
                                          }
                                        },
                                        onError: (err) {
                                          debugPrint('Error al seleccionar certificado: $err');
                                          setDialog(() => subiendo = false);
                                        },
                                      );
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton.icon(
                icon: guardando
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Guardar'),
                onPressed: guardando
                    ? null
                    : () async {
                        setDialog(() => guardando = true);
                        try {
                          await _supabaseService.registrarInasistenciaDocente(
                            authId: _authId,
                            tipo: tipo,
                            fechaDesde: desde,
                            fechaHasta: hasta,
                            motivo: motivoCtrl.text.trim().isEmpty ? null : motivoCtrl.text.trim(),
                            observaciones: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
                            archivoId: archivoId,
                          );
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          await _cargarDatosPerfil();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('✅ Registro guardado'),
                                  backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          setDialog(() => guardando = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    ).then((_) {
      motivoCtrl.dispose();
      obsCtrl.dispose();
    });
  }

  Future<void> _confirmarEliminarInasistencia(Map<String, dynamic> i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text('¿Eliminar la ${_etiquetaTipoInasistencia(i['tipo']?.toString() ?? '').toLowerCase()} '
            'del ${_rangoFechas(i)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _supabaseService.eliminarInasistenciaDocente(i['id'].toString());
    await _cargarDatosPerfil();
  }

  Widget _buildFaltasYCertificadosTab(Color colorPrincipal) {
    final esMovil = MediaQuery.of(context).size.width < 700;

    Widget stat(String valor, String etiqueta, MaterialColor color) {
      return Container(
        padding: EdgeInsets.all(esMovil ? 12 : 16),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade200),
        ),
        child: esMovil
            ? Row(
                children: [
                  Text(valor,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color.shade700)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(etiqueta,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color.shade900)),
                  ),
                ],
              )
            : Column(
                children: [
                  Text(valor,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color.shade700)),
                  const SizedBox(height: 4),
                  Text(etiqueta,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color.shade900)),
                ],
              ),
      );
    }

    final stats = [
      stat('${_resumenInasistencias['injustificadas'] ?? 0}', 'Días Injustificados', Colors.red),
      stat('${_resumenInasistencias['licencias'] ?? 0}', 'Días de Licencia / Justificados', Colors.green),
      stat('${_resumenInasistencias['presentismo'] ?? 100}%', 'Presentismo del Mes', Colors.blue),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(esMovil ? 14 : 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: EdgeInsets.all(esMovil ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.assignment_late_rounded, color: colorPrincipal, size: 30),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Registro de Asistencia y Licencias del Docente',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                SizedBox(height: 4),
                                Text('Conteo anual de inasistencias y carga de justificativos médicos / administrativos.',
                                    style: TextStyle(fontSize: 13, color: Colors.black54)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // En celular las tres tarjetas apiladas: en fila el texto
                      // se partía letra por letra.
                      if (esMovil)
                        Column(
                          children: [
                            stats[0],
                            const SizedBox(height: 10),
                            stats[1],
                            const SizedBox(height: 10),
                            stats[2],
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(child: stats[0]),
                            const SizedBox(width: 16),
                            Expanded(child: stats[1]),
                            const SizedBox(width: 16),
                            Expanded(child: stats[2]),
                          ],
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _abrirModalNuevaInasistencia,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Registrar falta o licencia'),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Faltas y Licencias Registradas:',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_inasistencias.isEmpty)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(esMovil ? 24 : 36),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.event_available_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('Sin faltas ni licencias registradas en el ciclo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _inasistencias.length,
                  itemBuilder: (ctx, idx) {
                    final i = _inasistencias[idx];
                    final tipo = (i['tipo'] ?? '').toString();
                    final color = _colorTipoInasistencia(tipo);
                    final certificado = i['usr_archivos_personal'] as Map<String, dynamic>?;

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: color.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    _etiquetaTipoInasistencia(tipo),
                                    style: TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_rangoFechas(i),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                  tooltip: 'Eliminar registro',
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => _confirmarEliminarInasistencia(i),
                                ),
                              ],
                            ),
                            if ((i['motivo'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(i['motivo'].toString(), style: const TextStyle(fontSize: 13)),
                            ],
                            if ((i['observaciones'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(i['observaciones'].toString(),
                                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                            if (certificado != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                                  label: Text(
                                    certificado['nombre_archivo']?.toString() ?? 'Certificado',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onPressed: () => _abrirODescargarArchivo(certificado),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              _buildArchivosSeccion('CERTIFICADO', _archivosCertificados, colorPrincipal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchivosTab(String tipo, List<Map<String, dynamic>> archivos, Color colorPrincipal) {
    final esMovil = MediaQuery.of(context).size.width < 700;
    return SingleChildScrollView(
      padding: EdgeInsets.all(esMovil ? 14 : 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _buildArchivosSeccion(tipo, archivos, colorPrincipal),
        ),
      ),
    );
  }

  /// Cabecera + listado de archivos. Se devuelve sin scroll propio para poder
  /// insertarlo dentro de otras pestañas (Faltas y Certificados).
  Widget _buildArchivosSeccion(String tipo, List<Map<String, dynamic>> archivos, Color colorPrincipal) {
    final esMovil = MediaQuery.of(context).size.width < 700;
    final esDdjj = tipo == 'DDJJ';
    final esCertificado = tipo == 'CERTIFICADO';
    final titulo = esDdjj
        ? 'Declaraciones Juradas de Cargos y Horarios (DDJJ)'
        : esCertificado
            ? 'Certificados Médicos y Justificativos'
            : 'Currículum Vitae y Certificaciones (CV)';
    final subtitulo = esDdjj
        ? 'Suba su Declaración Jurada oficial firmada en formato Word (.docx) o PDF. Puede actualizarla cada ciclo lectivo.'
        : esCertificado
            ? 'Cargue certificados médicos, constancias de examen u otros justificativos de licencia en formato Word o PDF.'
            : 'Suba su Currículum Vitae o carpeta de títulos en formato Word o PDF para el legajo institucional del colegio.';

    final botonSubir = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: _uploading ? Colors.grey : colorPrincipal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: _uploading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
      label: Text(
        _uploading ? 'SUBIENDO...' : 'SUBIR ARCHIVO (WORD / PDF)',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      onPressed: _uploading ? null : () => _seleccionarYSubirArchivoWeb(tipo),
    );

    final encabezado = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(esDdjj ? Icons.description_rounded : Icons.folder_special_rounded, size: 34, color: colorPrincipal),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorPrincipal)),
              const SizedBox(height: 4),
              Text(subtitulo, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          color: colorPrincipal.withOpacity(0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: EdgeInsets.all(esMovil ? 16 : 20),
            // En celular el botón va debajo del texto: al ponerlo al lado,
            // el título se quedaba sin ancho y se leía letra por letra.
            child: esMovil
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      encabezado,
                      const SizedBox(height: 16),
                      botonSubir,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: encabezado),
                      const SizedBox(width: 16),
                      botonSubir,
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Archivos Cargados Actualmente:',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (archivos.isEmpty)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(esMovil ? 24 : 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Aún no se ha subido ningún archivo $tipo en su perfil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Toque el botón "SUBIR ARCHIVO (WORD / PDF)" para agregar uno.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: archivos.length,
            itemBuilder: (ctx, idx) {
              final a = archivos[idx];
              final formato = a['formato'] ?? 'PDF';
              final esPdf = formato == 'PDF';
              final fecha = a['fecha_subida'] != null
                  ? _formatearFechaSubida(a['fecha_subida'].toString())
                  : 'Fecha reciente';

              final acciones = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorPrincipal.withOpacity(0.1),
                      foregroundColor: colorPrincipal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: Text(esMovil ? 'Ver' : 'Ver / Descargar',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _abrirODescargarArchivo(a),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    tooltip: 'Eliminar archivo',
                    onPressed: () => _eliminarArchivo(a['id'].toString(), a['nombre_archivo'] ?? 'Documento'),
                  ),
                ],
              );

              final identidad = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: esPdf ? Colors.red.withOpacity(0.12) : Colors.blue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      esPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                      color: esPdf ? Colors.red.shade700 : Colors.blue.shade700,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a['nombre_archivo'] ?? 'Documento $tipo',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Formato: $formato • Subido el $fecha',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: esMovil
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [identidad, const SizedBox(height: 8), acciones],
                        )
                      : Row(
                          children: [
                            Expanded(child: identidad),
                            const SizedBox(width: 12),
                            acciones,
                          ],
                        ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// Fecha de subida en dd/mm/aaaa a las HH:MM
  String _formatearFechaSubida(String valor) {
    final d = DateTime.tryParse(valor);
    if (d == null) return valor;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
        ' a las ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSupervisionAulicaDocenteTab(Color colorPrincipal) {
    final esMovil = MediaQuery.of(context).size.width < 700;
    final sinLeer = _observacionesRecibidasDirectiva.where((o) => o['leido'] != true).length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(esMovil ? 14 : 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(esMovil ? 16 : 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [colorPrincipal.withOpacity(0.15), Colors.purple.shade50]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorPrincipal.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: colorPrincipal, shape: BoxShape.circle),
                      child: const Icon(Icons.co_present_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mi Historial de Supervisión y Devoluciones',
                            style: TextStyle(
                                fontSize: esMovil ? 17 : 20,
                                fontWeight: FontWeight.bold,
                                color: colorPrincipal),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Acá recibís las actas de observación áulica, sugerencias didácticas y acuerdos enviados por el Equipo Directivo luego de cada visita de clase.',
                            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  const Text(
                    'Visitas Registradas y Notificaciones Pedagógicas',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Chip(
                    label: Text(
                      sinLeer > 0
                          ? '$sinLeer sin leer de ${_observacionesRecibidasDirectiva.length}'
                          : '${_observacionesRecibidasDirectiva.length} registros',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    backgroundColor: colorPrincipal.withOpacity(0.1),
                    side: BorderSide(color: colorPrincipal.withOpacity(0.3)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_observacionesRecibidasDirectiva.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade300)),
                  child: Padding(
                    padding: EdgeInsets.all(esMovil ? 28 : 40),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No tenés observaciones áulicas registradas en este período.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _observacionesRecibidasDirectiva.length,
                  itemBuilder: (context, index) {
                    final obs = _observacionesRecibidasDirectiva[index];
                    final leido = obs['leido'] == true;
                    final curso = (obs['curso_texto'] ?? 'Clase observada').toString();
                    final foco = obs['foco']?.toString();
                    final modulo = obs['modulo']?.toString();
                    final acuerdos = obs['acuerdos']?.toString() ?? '';
                    final acta = obs['usr_archivos_personal'] as Map<String, dynamic>?;

                    return Card(
                      elevation: leido ? 1 : 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: leido ? Colors.grey.shade300 : colorPrincipal,
                            width: leido ? 1 : 2),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(esMovil ? 16 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.school_rounded, color: colorPrincipal, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(curso,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: leido ? Colors.grey.shade100 : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: leido ? Colors.grey.shade400 : Colors.green.shade400),
                                  ),
                                  child: Text(
                                    leido ? 'Leído' : 'Nueva',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: leido ? Colors.grey.shade800 : Colors.green.shade800),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Visita: ${_fechaCorta(obs['fecha_visita']?.toString())}'
                                  '${modulo != null && modulo.isNotEmpty ? ' · $modulo' : ''}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                if (foco != null && foco.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber.shade300)),
                                    child: Text('Foco: $foco',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber.shade900)),
                                  ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 1),
                            const Text('Registro de lo Observado por Dirección:',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade200)),
                              child: Text(obs['observacion']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 14, height: 1.4, color: Colors.black87)),
                            ),
                            if (acuerdos.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text('Devolución Pedagógica / Acuerdos:',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colorPrincipal)),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: colorPrincipal.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: colorPrincipal.withOpacity(0.2))),
                                child: Text(acuerdos,
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.4,
                                        color: colorPrincipal,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w500)),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Text('Enviado por: ${obs['subido_por'] ?? "Equipo Directivo"}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                if (acta != null)
                                  OutlinedButton.icon(
                                    onPressed: () => _abrirODescargarArchivo(acta),
                                    icon: const Icon(Icons.download_rounded, size: 16),
                                    label: Text(
                                      acta['nombre_archivo']?.toString() ?? 'Descargar acta',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (!leido)
                                  ElevatedButton.icon(
                                    onPressed: () => _confirmarLecturaObservacion(obs),
                                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                                    label: const Text('Confirmar Lectura'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        elevation: 1),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Marca la devolución como leída y avisa a Dirección.
  Future<void> _confirmarLecturaObservacion(Map<String, dynamic> obs) async {
    try {
      await _supabaseService.marcarObservacionAulicaLeida(obs['id'].toString());
      if (mounted) setState(() => obs['leido'] = true);

      final ids = await _supabaseService.obtenerAuthIdsAdministracion();
      await _supabaseService.notificarSistema(
        asunto: 'Acuse de Recibo: Devolución Áulica Leída',
        texto: 'El docente confirmó la lectura de la devolución pedagógica '
            'de ${obs['curso_texto'] ?? 'la clase observada'}.',
        destinatariosAuthIds: ids,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Lectura confirmada. Se notificó a Dirección.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo confirmar la lectura: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
