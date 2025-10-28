// lib/features/auth/ui/pages/reporte_actividad_nutrientes.dart

import 'dart:typed_data';
import 'package:agro_app/core/firestore/repo_queries.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, NetworkAssetBundle;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:agro_app/widgets/upload_overlay.dart';

class ReporteActividadNutrientesPage extends StatefulWidget {
  const ReporteActividadNutrientesPage({super.key});

  @override
  State<ReporteActividadNutrientesPage> createState() =>
      _ReporteActividadNutrientesPageState();
}

class _ReporteActividadNutrientesPageState extends State<ReporteActividadNutrientesPage> {
  static const kOrange = Color(0xFFF2AE2E);

  static const String _tituloPagina = 'Reporte de Actividad de Nutrientes';
  static const String _subtipo = 'Reporte de Actividad Nutrientes';
  static const String _coleccionDestino = 'reportes_nutrientes';

  // ===== contexto y autollenado =====
  String _unidad = 'Unidad';
  String _seccion = 'seccion_unica';
  String _nombrePerfil = 'No asignado';
  bool _argsLoaded = false;

  int get _year => DateTime.now().year;
  int get _month => DateTime.now().month;
  String _ts() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  final _formKey = GlobalKey<FormState>();
  DateTime _fechaHora = DateTime.now();

  // ===== Campos =====
  final _ubicacionCtrl = TextEditingController();   // Unidad (solo lectura)
  final _responsableCtrl = TextEditingController(); // Responsable (solo lectura)

  String _nombreReporte() =>
      'Reporte de Actividad - Análisis de Nutrientes - ${DateFormat('dd/MM/yyyy HH:mm', 'es_MX').format(_fechaHora)}';

  final _comentariosCtrl = TextEditingController();
  final _incidenciasTextoCtrl = TextEditingController();
  final _combustibleCtrl = TextEditingController();
  final _herramientasCtrl = TextEditingController();
  final _recomendacionesCtrl = TextEditingController();

  final List<Uint8List> _incidenciasImgs = [];
  final List<String> _incidenciasPaths = [];
  final List<Uint8List> _reporteImgs = [];
  final List<String> _reportePaths = [];

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_MX');
    _fechaHora = DateTime.now();
    _cargarPerfilYAutollenar(); // respaldo si no llegan args
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final unidadArg = (args['unidadSeleccionada'] as String?);
      final responsableArg = (args['responsableNombre'] as String?);

      if (unidadArg != null && unidadArg.trim().isNotEmpty) {
        _unidad = unidadArg.trim();
        _ubicacionCtrl.text = _unidad;
      }
      if (responsableArg != null && responsableArg.trim().isNotEmpty) {
        _nombrePerfil = responsableArg.trim();
        _responsableCtrl.text = _nombrePerfil;
      }

      _seccion =
      (args['seccionSeleccionada'] as String?)?.trim().isNotEmpty == true
          ? (args['seccionSeleccionada'] as String).trim()
          : _seccion;
    }
    _argsLoaded = true;
  }

  Future<void> _cargarPerfilYAutollenar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
      final unidad = (data['unidadSeleccionada'] as String?) ?? _unidad;
      final nombre = (data['nombre'] as String?) ?? 'No asignado';

      if (_ubicacionCtrl.text.trim().isEmpty) {
        _unidad = unidad;
        _ubicacionCtrl.text = _unidad;
      }
      if (_responsableCtrl.text.trim().isEmpty) {
        _nombrePerfil = nombre;
        _responsableCtrl.text = _nombrePerfil;
      }
    } catch (_) {
      if (_ubicacionCtrl.text.trim().isEmpty) {
        _ubicacionCtrl.text = _unidad;
      }
    }
  }

  @override
  void dispose() {
    _ubicacionCtrl.dispose();
    _responsableCtrl.dispose();
    _comentariosCtrl.dispose();
    _incidenciasTextoCtrl.dispose();
    _combustibleCtrl.dispose();
    _herramientasCtrl.dispose();
    _recomendacionesCtrl.dispose();
    super.dispose();
  }

  // ====================== UI ======================
  @override
  Widget build(BuildContext context) {
    final fechaTxt =
    DateFormat('dd/MM/yyyy HH:mm', 'es_MX').format(_fechaHora);

    return Scaffold(
      appBar: AppBar(
        title: Text(_tituloPagina),
        backgroundColor: kOrange,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _dateField(fechaTxt),

              const SizedBox(height: 8),
              _sectionTitle('1. Datos Generales'),
              _readonlyFieldCtrl(_ubicacionCtrl, 'Unidad', icon: Icons.place_outlined),
              _readonlyFieldCtrl(_responsableCtrl, 'Responsable', icon: Icons.badge_outlined),

              const SizedBox(height: 8),
              _sectionTitle('2. Nombre del Reporte'),
              _chipInfo(_nombreReporte()),

              const SizedBox(height: 8),
              _sectionTitle('3. Comentarios y/o Incidencias'),
              _textArea(_comentariosCtrl, 'Comentarios (opcional)'),
              _textArea(_incidenciasTextoCtrl, 'Incidencias (opcional)'),
              _uploadRow(
                label: 'Subir Incidencia',
                onTap: () => _pickAndUploadImage(isIncidencia: true),
              ),
              _thumbs(_incidenciasImgs),

              const SizedBox(height: 8),
              _sectionTitle('4. Recursos Utilizados'),
              _textField(_combustibleCtrl, 'Combustible / Lts',
                  icon: Icons.local_gas_station_outlined,
                  keyboard: TextInputType.number),
              _textArea(_herramientasCtrl, 'Herramientas Utilizadas'),

              const SizedBox(height: 8),
              _sectionTitle('5. Recomendaciones'),
              _textArea(_recomendacionesCtrl, 'Ajustes / Recomendaciones'),

              const SizedBox(height: 8),
              _sectionTitle('6. Firma y Validación'),
              _uploadRow(
                label: 'Subir imágenes de Reporte',
                onTap: () => _pickAndUploadImage(isIncidencia: false),
              ),
              _thumbs(_reporteImgs),

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOrange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _onTapGenerarYGuardar,
                  label: const Text(
                    'Generar PDF y Guardar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================== Widgets helper ======================
  Widget _sectionTitle(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: TextStyle(
        color: Colors.grey.shade800,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _chipInfo(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: kOrange.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kOrange.withOpacity(0.45)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );

  Widget _readonlyFieldCtrl(TextEditingController c, String label, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: c,
        enabled: false,
        decoration: InputDecoration(
          prefixIcon: icon == null ? null : Icon(icon),
          labelText: label,
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black26),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        style: const TextStyle(color: Colors.black87),
      ),
    );
  }

  Widget _textField(TextEditingController c, String hint,
      {bool required = false, IconData? icon, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          prefixIcon: icon == null ? null : Icon(icon),
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.92),
        ),
        validator: (v) =>
        (required && (v == null || v.trim().isEmpty)) ? 'Completa este campo' : null,
      ),
    );
  }

  Widget _textArea(TextEditingController c, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: c,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.92),
        ),
      ),
    );
  }

  Widget _dateField(String text) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event),
                const SizedBox(width: 8),
                Expanded(child: Text('Fecha y hora: $text')),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_calendar_outlined),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDate: _fechaHora,
            );
            if (d == null) return;
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(_fechaHora),
            );
            if (t == null) return;
            setState(() => _fechaHora =
                DateTime(d.year, d.month, d.day, t.hour, t.minute));
          },
          label: const Text('Cambiar'),
        ),
      ],
    );
  }

  Widget _uploadRow({required String label, required VoidCallback onTap}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add_a_photo_outlined),
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            side: const BorderSide(color: Colors.black12),
          ),
          label: Text(label),
        ),
      ),
    );
  }

  Widget _thumbs(List<Uint8List> images) {
    if (images.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: images
            .map((b) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(b, width: 90, height: 90, fit: BoxFit.cover),
        ))
            .toList(),
      ),
    );
  }

  // ====================== Paths ======================
  String _sanitizeSegment(String input) {
    final s = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\\/]+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9_\-\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return s.isEmpty ? 'na' : s;
  }

  String _month2() => _month.toString().padLeft(2, '0');

  String _incidenciaPath(String fileName) {
    final u = _sanitizeSegment(_unidad);
    return 'unidades_info/$u/analisis_suelo/img/incidencias_img/img_reporte_nutrientes/$_year/${_month2()}/$fileName';
  }

  String _reportePath(String fileName) {
    final u = _sanitizeSegment(_unidad);
    return 'unidades_info/$u/analisis_suelo/img/reporte_actividad_analisis_nutrientes_img/$_year/${_month2()}/$fileName';
  }

  String _pdfFileName() {
    final name = _nombreReporte()
        .replaceAll('/', '-')
        .replaceAll(':', '-')
        .replaceAll('\n', ' ')
        .trim();
    return name.isEmpty
        ? 'Reporte de Actividad - Analisis de Nutrientes.pdf'
        : '$name.pdf';
  }

  String _pdfPath() {
    final u = _sanitizeSegment(_unidad);
    final name = _pdfFileName();
    return 'unidades_info/$u/analisis_suelo/reportes/reporte_actividad_analisis_nutrientes/$_year/${_month2()}/$name';
  }

  Future<(String path, String url)> _uploadBytes(Uint8List data, String path,
      {String contentType = 'image/jpeg'}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ref = FirebaseStorage.instance.ref(path);
    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        if (uid != null) 'uid': uid,
        'unidad': _unidad,
        'tipo': _subtipo,
      },
    );
    final uploadTask = ref.putData(data, metadata);
    showUploadOverlayForTask(
      context,
      uploadTask,
      label: 'Subiendo archivo…',
    );
    await uploadTask;
    final url = await ref.getDownloadURL();
    return (path, url);
  }

  Future<void> _deletePathsSafe(List<dynamic>? paths) async {
    if (paths == null) return;
    for (final p in paths) {
      if (p is! String) continue;
      final path = p.trim();
      if (path.isEmpty) continue;
      try {
        await FirebaseStorage.instance.ref(path).delete();
      } catch (_) {}
    }
  }

  // ====================== Picker ======================
  Future<ImageSource?> _chooseImageSourceSheet() {
    return showModalBottomSheet<ImageSource?>(
      context: context,
      backgroundColor: Colors.grey.shade100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Theme(
          data: Theme.of(ctx).copyWith(
            iconTheme: const IconThemeData(color: Colors.black87),
            textTheme: Theme.of(ctx)
                .textTheme
                .apply(bodyColor: Colors.black87, displayColor: Colors.black87),
            listTileTheme: const ListTileThemeData(
              iconColor: Colors.black87,
              textColor: Colors.black87,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 6),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galería (múltiples)'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Cámara'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage({required bool isIncidencia}) async {
    final source = await _chooseImageSourceSheet();
    if (source == null) return;

    try {
      if (source == ImageSource.gallery) {
        final images = await _picker.pickMultiImage(imageQuality: 85);
        if (images.isEmpty) return;

        for (final x in images) {
          final bytes = await x.readAsBytes();
          final fileName = '${isIncidencia ? 'inc' : 'rep'}_${_ts()}_${x.name}';
          final dest =
          isIncidencia ? _incidenciaPath(fileName) : _reportePath(fileName);
          final (path, _) = await _uploadBytes(bytes, dest);

          setState(() {
            if (isIncidencia) {
              _incidenciasImgs.add(bytes);
              _incidenciasPaths.add(path);
            } else {
              _reporteImgs.add(bytes);
              _reportePaths.add(path);
            }
          });
        }
      } else {
        final x =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (x == null) return;
        final bytes = await x.readAsBytes();
        final fileName = '${isIncidencia ? 'inc' : 'rep'}_${_ts()}_${x.name}';
        final dest =
        isIncidencia ? _incidenciaPath(fileName) : _reportePath(fileName);
        final (path, _) = await _uploadBytes(bytes, dest);

        setState(() {
          if (isIncidencia) {
            _incidenciasImgs.add(bytes);
            _incidenciasPaths.add(path);
          } else {
            _reporteImgs.add(bytes);
            _reportePaths.add(path);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir imagen: $e')),
      );
    }
  }

  // ====================== PDF — 1 hoja, 2 columnas, inicio más bajo, iconos naranjas ======================
  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    final fechaFmt = DateFormat('dd/MM/yyyy HH:mm', 'es_MX').format(_fechaHora);

    final bgData = await rootBundle.load('IMG/portada_reportes_1.jpg');
    final bg = pw.MemoryImage(bgData.buffer.asUint8List());

    // ------ Encabezado con "icono" + título (naranja corporativo) ------
    pw.Widget _header(String emoji, String title) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF2AE2E),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: pw.Text(emoji,
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.black,
              )),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFFF2AE2E),
          ),
        ),
      ],
    );

    // Párrafos (sin guiones)
    pw.Widget _lines(List<String> items) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final t in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(t,
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
          ),
      ],
    );

    // Rejilla imágenes (3x2) que no se salen del área
    pw.Widget _imagesGrid({
      required List<Uint8List> images,
      required double height,
    }) {
      if (images.isEmpty) return pw.SizedBox(height: height);
      final imgs = images.take(6).toList();
      return pw.Container(
        height: height,
        child: pw.ClipRect(
          child: pw.GridView(
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            children: [
              for (final b in imgs)
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.FittedBox(
                    fit: pw.BoxFit.contain,
                    child: pw.Image(pw.MemoryImage(b)),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Datos
    final datosGenerales = <String>[
      'Unidad: ${_ubicacionCtrl.text.trim()}',
      'Responsable: ${_responsableCtrl.text.trim()}',
      'Fecha y Hora: $fechaFmt',
    ];
    final nombreReporte = _nombreReporte();
    final comentarios = _comentariosCtrl.text.trim().isEmpty
        ? ['(sin comentarios)']
        : _comentariosCtrl.text.trim().split('\n');
    final incidenciasTxt = _incidenciasTextoCtrl.text.trim().isEmpty
        ? ['(sin incidencias)']
        : _incidenciasTextoCtrl.text.trim().split('\n');
    final recursos = <String>[
      'Combustible / Lts: ${_combustibleCtrl.text.trim().isEmpty ? '-' : _combustibleCtrl.text.trim()}',
      'Herramientas Utilizadas: ${_herramientasCtrl.text.trim().isEmpty ? '-' : _herramientasCtrl.text.trim()}',
    ];
    final recomendaciones = _recomendacionesCtrl.text.trim().isEmpty
        ? ['(sin recomendaciones)']
        : _recomendacionesCtrl.text.trim().split('\n');

    // -------- Layout A4: 2 columnas, todo en 1 hoja --------
    const pageW = 595.0; // A4 points
    const side = 32.0;
    const top = 340.0; // más abajo para despegar del mapa
    const gapX = 18.0;
    const gapY = 10.0;
    final colW = (pageW - side * 2 - gapX) / 2;

    // Alturas por bloque (ajustadas para caber en 1 hoja)
    const hDatos = 70.0;
    const hNombre = 55.0;
    const hComentarios = 100.0;
    const hIncidTxt = 45.0;
    const hIncidImgs = 135.0;

    const hRecursos = 110.0;
    const hRecomend = 120.0;
    const hImgsRep = 180.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) {
          return pw.Stack(
            children: [
              pw.Positioned.fill(child: pw.Image(bg, fit: pw.BoxFit.cover)),

              // -------- Columna Izquierda --------
              pw.Positioned(
                left: side,
                top: top,
                child: pw.Container(
                  width: colW,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _header('📍', '01 DATOS GENERALES'),
                      pw.SizedBox(height: 6),
                      pw.Container(height: hDatos, child: _lines(datosGenerales)),
                      pw.SizedBox(height: gapY),

                      _header('📝', '02 NOMBRE DEL REPORTE'),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        height: hNombre,
                        child: pw.Text(nombreReporte,
                            style: const pw.TextStyle(fontSize: 11)),
                      ),
                      pw.SizedBox(height: gapY),

                      _header('💬', '03 COMENTARIOS'),
                      pw.SizedBox(height: 6),
                      pw.Container(height: hComentarios, child: _lines(comentarios)),
                      pw.SizedBox(height: gapY),

                      _header('⚠️', '04 INCIDENCIAS'),
                      pw.SizedBox(height: 6),
                      pw.Container(height: hIncidTxt, child: _lines(incidenciasTxt)),
                      pw.SizedBox(height: 6),
                      _imagesGrid(images: _incidenciasImgs, height: hIncidImgs),
                    ],
                  ),
                ),
              ),

              // -------- Columna Derecha --------
              pw.Positioned(
                left: side + colW + gapX,
                top: top,
                child: pw.Container(
                  width: colW,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _header('⛽', '05 RECURSOS UTILIZADOS'),
                      pw.SizedBox(height: 6),
                      pw.Container(height: hRecursos, child: _lines(recursos)),
                      pw.SizedBox(height: gapY),

                      _header('✅', '06 RECOMENDACIÓN'),
                      pw.SizedBox(height: 6),
                      pw.Container(height: hRecomend, child: _lines(recomendaciones)),
                      pw.SizedBox(height: gapY),

                      _header('🖼️', '07 IMÁGENES DEL REPORTE'),
                      pw.SizedBox(height: 6),
                      _imagesGrid(images: _reporteImgs, height: hImgsRep),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ====================== Guardado ======================
  Future<void> _onTapGenerarYGuardar() async {
    if (!_formKey.currentState!.validate()) return;

    final first = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text(
            'Selecciona una opción para continuar con el guardado del reporte.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'rev'),
              child: const Text('Revisión')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'ok'),
              child: const Text('Validado')),
        ],
      ),
    );
    if (first != 'ok') return;

    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cómo deseas guardar?'),
        content: const Text(
            'Elige si crear un nuevo archivo o sobrescribir uno existente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'overwrite'),
              child: const Text('Sobrescribir archivo')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'new'),
              child: const Text('Nuevo archivo')),
        ],
      ),
    );
    if (mode == null) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (mode == 'new') {
        final pdfBytes = await _buildPdfBytes();
        final pdfStoragePath = _pdfPath();
        final (_, pdfUrl) = await _uploadBytes(pdfBytes, pdfStoragePath,
            contentType: 'application/pdf');

        final doc = {
          'uid': uid,
          'unidad': _ubicacionCtrl.text.trim(),
          'responsable': _responsableCtrl.text.trim(),
          'fechaHora': Timestamp.fromDate(_fechaHora),
          'fecha': Timestamp.fromDate(_fechaHora),
          'nombreReporte': _nombreReporte(),
          'nombre': _nombreReporte(),
          'comentarios': _comentariosCtrl.text.trim(),
          'incidenciasTexto': _incidenciasTextoCtrl.text.trim(),
          'recursos': {
            'combustibleLts': _combustibleCtrl.text.trim(),
            'herramientas': _herramientasCtrl.text.trim(),
          },
          'recomendaciones': _recomendacionesCtrl.text.trim(),
          'incidenciasImgs': _incidenciasPaths,
          'reporteImgs': _reportePaths,
          'pdfPath': pdfStoragePath,
          'pdfUrl': pdfUrl,
          'downloadUrl': pdfUrl,
          'storagePath': pdfStoragePath,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'seccion': _seccion,
          'subtipo': _subtipo,
        };

        await FirebaseFirestore.instance
            .collection(_coleccionDestino)
            .add(doc);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte guardado como nuevo archivo.')),
        );
        Navigator.of(context).pop();
        return;
      }

      // === SOBRESCRIBIR ===
      final selected = await _pickExistingResultForOverwrite();
      if (!mounted) return;
      if (selected == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se seleccionó ningún archivo.')),
        );
        return;
      }

      final docId = selected.id;
      final data = selected.data() as Map<String, dynamic>? ?? {};
      String? existingPdfPath = data['pdfPath'] as String?;
      String? existingPdfUrl = data['pdfUrl'] as String?;
      final oldIncPaths =
          (data['incidenciasImgs'] as List?)?.cast<String>() ?? [];
      final oldRepPaths = (data['reporteImgs'] as List?)?.cast<String>() ?? [];

      // ¿Subiste nuevas en esta sesión?
      final hasNewInc = _incidenciasPaths.isNotEmpty;
      final hasNewRep = _reportePaths.isNotEmpty;

      // Si NO hay nuevas, usa las previas también para el PDF
      Future<void> _loadOldBytesIfNeeded() async {
        Future<void> loadList(
            List<String> paths, List<Uint8List> into) async {
          for (final p in paths) {
            try {
              final url =
              await FirebaseStorage.instance.ref(p).getDownloadURL();
              final b =
              await NetworkAssetBundle(Uri.parse(url)).load("");
              into.add(b.buffer.asUint8List());
            } catch (_) {}
          }
        }

        if (!hasNewInc && _incidenciasImgs.isEmpty) {
          await loadList(oldIncPaths, _incidenciasImgs);
          _incidenciasPaths
            ..clear()
            ..addAll(oldIncPaths);
        }
        if (!hasNewRep && _reporteImgs.isEmpty) {
          await loadList(oldRepPaths, _reporteImgs);
          _reportePaths
            ..clear()
            ..addAll(oldRepPaths);
        }
      }

      await _loadOldBytesIfNeeded();

      // Borrar del storage solo si subiste nuevas
      if (hasNewInc) await _deletePathsSafe(oldIncPaths);
      if (hasNewRep) await _deletePathsSafe(oldRepPaths);

      existingPdfPath ??= _pdfPath();

      final pdfBytes = await _buildPdfBytes();

      final (finalPath, finalUrl) = await _uploadBytes(
        pdfBytes,
        existingPdfPath,
        contentType: 'application/pdf',
      );

      final update = {
        'uid': uid,
        'unidad': _ubicacionCtrl.text.trim(),
        'responsable': _responsableCtrl.text.trim(),
        'fechaHora': Timestamp.fromDate(_fechaHora),
        'fecha': Timestamp.fromDate(_fechaHora),
        'nombreReporte': _nombreReporte(),
        'nombre': _nombreReporte(),
        'comentarios': _comentariosCtrl.text.trim(),
        'incidenciasTexto': _incidenciasTextoCtrl.text.trim(),
        'recursos': {
          'combustibleLts': _combustibleCtrl.text.trim(),
          'herramientas': _herramientasCtrl.text.trim(),
        },
        'recomendaciones': _recomendacionesCtrl.text.trim(),
        'incidenciasImgs': _incidenciasPaths,
        'reporteImgs': _reportePaths,
        'pdfPath': finalPath,
        'pdfUrl': finalUrl,
        'downloadUrl': finalUrl,
        'storagePath': finalPath,
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'seccion': _seccion,
        'subtipo': _subtipo,
      };

      await FirebaseFirestore.instance
          .collection(_coleccionDestino)
          .doc(docId)
          .update(update);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Reporte sobrescrito ${existingPdfUrl != null ? '(mismo archivo)' : '(nuevo archivo)'}.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  // ====================== Diálogo para sobrescribir ======================
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
  _pickExistingResultForOverwrite() async {
    try {
      final q = await RepoQueries.reportesNutrientes(
        unidadId: _ubicacionCtrl.text.trim(),
        seccionId: _seccion,
        desde: null,
      ).limit(50).get();

      final docs = q.docs;

      docs.sort((a, b) {
        final ad = (a.data()['createdAt'] is Timestamp)
            ? (a.data()['createdAt'] as Timestamp).toDate()
            : (a.data()['fechaHora'] is Timestamp)
            ? (a.data()['fechaHora'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bd = (b.data()['createdAt'] is Timestamp)
            ? (b.data()['createdAt'] as Timestamp).toDate()
            : (b.data()['fechaHora'] is Timestamp)
            ? (b.data()['fechaHora'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

      if (docs.isEmpty) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No hay reportes'),
            content:
            const Text('No se encontraron reportes para esta unidad.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Ok'))
            ],
          ),
        );
        return null;
      }

      return await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
        context: context,
        builder: (ctx) {
          final themed = Theme.of(ctx).copyWith(
            iconTheme: const IconThemeData(color: Colors.black87),
            textTheme: Theme.of(ctx)
                .textTheme
                .apply(bodyColor: Colors.black87, displayColor: Colors.black87),
            listTileTheme: const ListTileThemeData(
                iconColor: Colors.black87, textColor: Colors.black87),
          );

          return Theme(
            data: themed,
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.grey.shade100,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kOrange.withOpacity(0.25),
                        border: const Border(
                            bottom: BorderSide(color: Colors.black12)),
                      ),
                      child: const Text('Selecciona un reporte para sobrescribir',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final d = docs[i].data();
                          final fecha = (d['createdAt'] is Timestamp)
                              ? (d['createdAt'] as Timestamp).toDate()
                              : (d['fechaHora'] is Timestamp)
                              ? (d['fechaHora'] as Timestamp).toDate()
                              : null;
                          final fechaTxt = fecha != null
                              ? DateFormat('dd/MM/yyyy HH:mm', 'es_MX')
                              .format(fecha)
                              : 's/f';
                          final nombre =
                          (d['responsable'] ?? '—').toString();
                          final titulo =
                          (d['nombreReporte'] ?? 'Reporte').toString();
                          final path = (d['pdfPath'] ?? 'sin path').toString();

                          return ListTile(
                            title: Text(titulo),
                            subtitle:
                            Text('Fecha: $fechaTxt · Resp: $nombre\n$path'),
                            isThreeLine: true,
                            leading: const Icon(Icons.picture_as_pdf),
                            onTap: () => Navigator.pop(ctx, docs[i]),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            child: const Text('Cancelar')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al consultar reportes: $e')));
      return null;
    }
  }
}
