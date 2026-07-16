import 'dart:convert';
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

  List<Map<String, dynamic>> _observacionesRecibidasDirectiva = [
    {
      'id': '101',
      'curso': '3° B - Matemática',
      'fecha': '10/07/2026 - 2° Módulo',
      'foco': 'Estrategias Didácticas y Clima Áulico',
      'observacion': 'Excelente manejo del pizarrón y recursos interactivos con el grupo. Se sugiere continuar la ejercitación guiada del grupo que intensifica RITE.',
      'acuerdos': 'Se acuerda adjuntar la pauta de evaluación formativa quincenal para revisión en preceptoría.',
      'archivo': 'Devolucion_Clase_Matematica_3B_Gomez.pdf',
      'subido_por': 'Directora (Maria Funes)',
      'leido': false,
    },
    {
      'id': '102',
      'curso': '2° A - Matemática',
      'fecha': '28/06/2026 - 1° Módulo',
      'foco': 'Acompañamiento a Alumnos con Adecuación / RITE',
      'observacion': 'Clase muy ordenada con alta participación. Se verificaron las estrategias diferenciadas para alumnos con adecuación curricular.',
      'acuerdos': 'Mantener coordinación mensual con el Equipo de Orientación Escolar (EOE).',
      'archivo': 'Acta_Observacion_Aulica_2A_Gomez.pdf',
      'subido_por': 'Directora (Maria Funes)',
      'leido': true,
    }
  ];

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
        setState(() {
          _archivosDdjj = archivos.where((a) => a['tipo_archivo'] == 'DDJJ').toList();
          _archivosCv = archivos.where((a) => a['tipo_archivo'] == 'CV').toList();
          _archivosCertificados = archivos.where((a) => a['tipo_archivo'] == 'CERTIFICADO').toList();
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
        await Supabase.instance.client.from('usr_docentes').update({
          'telefono': _telefonoController.text.trim(),
          'domicilio': _domicilioController.text.trim(),
          'titulo_profesional': _tituloController.text.trim(),
          'especialidad': _especialidadController.text.trim(),
        }).eq('auth_id', _authId);

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
        title: Text('Mi Perfil Profesional - ${widget.rol}', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: colorPrincipal.withOpacity(0.15),
                        child: Icon(Icons.person_pin_rounded, size: 48, color: colorPrincipal),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nombreCompleto,
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorPrincipal),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Correo: $_email • Rol: ${widget.rol}',
                              style: const TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 40),
                  const Text('Información Profesional y de Contacto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _telefonoController,
                          decoration: InputDecoration(
                            labelText: 'Teléfono / Celular de Contacto',
                            prefixIcon: const Icon(Icons.phone_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _domicilioController,
                          decoration: InputDecoration(
                            labelText: 'Domicilio Particular',
                            prefixIcon: const Icon(Icons.home_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tituloController,
                          decoration: InputDecoration(
                            labelText: 'Título Profesional Principal',
                            prefixIcon: const Icon(Icons.school_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _especialidadController,
                          decoration: InputDecoration(
                            labelText: 'Especialidad / Área Pedagógica',
                            prefixIcon: const Icon(Icons.stars_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorPrincipal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: const Text('GUARDAR Y ACTUALIZAR DATOS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildFaltasYCertificadosTab(Color colorPrincipal) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.assignment_late_rounded, color: colorPrincipal, size: 32),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Registro de Asistencia y Licencias del Docente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                Text('Conteo anual de inasistencias y carga de justificativos médicos / administrativos.', style: TextStyle(fontSize: 13, color: Colors.black54)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                              child: Column(
                                children: [
                                  Text('0', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                  const SizedBox(height: 4),
                                  Text('Faltas Injustificadas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                              child: Column(
                                children: [
                                  Text('1', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                  const SizedBox(height: 4),
                                  Text('Licencias / Justificadas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
                              child: Column(
                                children: [
                                  Text('100%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                  const SizedBox(height: 4),
                                  Text('Presentismo Mensual', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildArchivosTab('CERTIFICADO', _archivosCertificados, colorPrincipal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchivosTab(String tipo, List<Map<String, dynamic>> archivos, Color colorPrincipal) {
    final esDdjj = tipo == 'DDJJ';
    final esCertificado = tipo == 'CERTIFICADO';
    final titulo = esDdjj
        ? 'Declaraciones Juradas de Cargos y Horarios (DDJJ)'
        : esCertificado
            ? 'Certificados Médicos y Justificativos de Inasistencia'
            : 'Currículum Vitae y Certificaciones (CV)';
    final subtitulo = esDdjj
        ? 'Suba su Declaración Jurada oficial firmada en formato Word (.docx) o PDF. Puede actualizarla cada ciclo lectivo.'
        : esCertificado
            ? 'Cargue certificados médicos, constancias de examen u otros justificativos de licencia en formato Word o PDF.'
            : 'Suba su Currículum Vitae o carpeta de títulos en formato Word o PDF para el legajo institucional del colegio.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                color: colorPrincipal.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(esDdjj ? Icons.description_rounded : Icons.folder_special_rounded, size: 40, color: colorPrincipal),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorPrincipal)),
                            const SizedBox(height: 4),
                            Text(subtitulo, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _uploading ? Colors.grey : colorPrincipal,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _uploading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                        label: Text(
                          _uploading ? 'SUBIENDO...' : 'SUBIR ARCHIVO (WORD / PDF)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _uploading ? null : () => _seleccionarYSubirArchivoWeb(tipo),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Archivos Cargados Actualmente:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (archivos.isEmpty)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.folder_open_rounded, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Aún no se ha subido ningún archivo $tipo en su perfil.',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Haga clic en el botón superior "SUBIR ARCHIVO (WORD / PDF)" para agregar uno.',
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
                        ? a['fecha_subida'].toString().substring(0, 16).replaceAll('T', ' a las ')
                        : 'Fecha reciente';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: esPdf ? Colors.red.withOpacity(0.12) : Colors.blue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            esPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                            color: esPdf ? Colors.red.shade700 : Colors.blue.shade700,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          a['nombre_archivo'] ?? 'Documento $tipo',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Formato: $formato • Subido el $fecha',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                          ),
                        ),
                        trailing: Row(
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
                              label: const Text('Ver / Descargar', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => _abrirODescargarArchivo(a),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              tooltip: 'Eliminar archivo',
                              onPressed: () => _eliminarArchivo(a['id'].toString(), a['nombre_archivo'] ?? 'Documento'),
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

  Widget _buildSupervisionAulicaDocenteTab(Color colorPrincipal) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [colorPrincipal.withOpacity(0.15), Colors.purple.shade50]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorPrincipal.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: colorPrincipal, shape: BoxShape.circle),
                  child: const Icon(Icons.co_present_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mi Historial de Supervisión y Devoluciones Directivas',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorPrincipal),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'En esta sección recibís las actas de observación áulica, sugerencias didácticas y acuerdos enviados por el Equipo Directivo luego de cada visita de clase.',
                        style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Visitas Registradas y Notificaciones Pedagógicas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Chip(
                label: Text('${_observacionesRecibidasDirectiva.length} Registros en Total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                backgroundColor: colorPrincipal.withOpacity(0.1),
                side: BorderSide(color: colorPrincipal.withOpacity(0.3)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_observacionesRecibidasDirectiva.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
              child: const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No tenés observaciones áulicas pendientes ni registradas en este período.', style: TextStyle(fontSize: 15, color: Colors.black54)),
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
                return Card(
                  elevation: leido ? 1 : 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: leido ? Colors.grey.shade300 : colorPrincipal, width: leido ? 1 : 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.school_rounded, color: colorPrincipal, size: 24),
                                const SizedBox(width: 10),
                                Text(obs['curso'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87)),
                                const SizedBox(width: 10),
                                if (obs['foco'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.shade300)),
                                    child: Text('Foco: ${obs['foco']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900)),
                                  ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: leido ? Colors.grey.shade100 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: leido ? Colors.grey.shade400 : Colors.green.shade400),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(leido ? Icons.mark_email_read_rounded : Icons.mark_email_unread_rounded, size: 14, color: leido ? Colors.grey.shade700 : Colors.green.shade700),
                                  const SizedBox(width: 6),
                                  Text(leido ? 'Leído y Confirmado' : '⚡ Nueva Devolución', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: leido ? Colors.grey.shade800 : Colors.green.shade800)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Fecha de Visita: ${obs['fecha'] ?? ""}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                        const Divider(height: 26, thickness: 1),
                        const Text('Registro de lo Observado por Dirección:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                          child: Text(obs['observacion'] ?? '', style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87)),
                        ),
                        if (obs['acuerdos'] != null && (obs['acuerdos'] as String).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Devolución Pedagógica / Acuerdos:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorPrincipal)),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: colorPrincipal.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: colorPrincipal.withOpacity(0.2))),
                            child: Text(obs['acuerdos'] ?? '', style: TextStyle(fontSize: 13.5, height: 1.4, color: colorPrincipal, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 18),
                                  label: Text(obs['archivo'] ?? 'Acta_Supervision.pdf', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                const SizedBox(width: 12),
                                Text('Enviado por: ${obs['subido_por'] ?? "Directora"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            Row(
                              children: [
                                if (!leido)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        obs['leido'] = true;
                                      });
                                      _supabaseService.obtenerAuthIdsAdministracion().then((ids) {
                                        _supabaseService.notificarSistema(
                                          asunto: 'Acuse de Recibo Directivo: Devolución Áulica Leída',
                                          texto: 'El docente ha confirmado la lectura y acuse de la devolución pedagógica del curso ${obs['curso'] ?? ''}.',
                                          destinatariosAuthIds: ids,
                                        );
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Has confirmado la lectura de la devolución pedagógica. Notificación enviada a Dirección.'), backgroundColor: Colors.green));
                                    },
                                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                                    label: const Text('Confirmar Lectura'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, elevation: 1),
                                  ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📄 Descargando / Abriendo acta: ${obs['archivo']}...')));
                                  },
                                  icon: const Icon(Icons.download_rounded, size: 16),
                                  label: const Text('Descargar Acta PDF'),
                                ),
                              ],
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
    );
  }
}
