// lib/features/auth/ui/pages/analisis_suelo_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'package:agro_app/core/firestore/repo_queries.dart';
import 'package:agro_app/features/auth/ui/pages/analisis_compactacion_botton_page.dart';
import 'package:agro_app/features/auth/ui/pages/reporte_actividad_form_page.dart';
import 'package:agro_app/features/auth/ui/pages/reporte_actividad_nutrientes.dart';
import 'package:agro_app/features/auth/ui/pages/analisis_nutrientes_botton_page.dart';

class SectionOption {
  final String label;
  final String valueSlug;
  final num? hectareas;
  SectionOption({required this.label, required this.valueSlug, this.hectareas});
}

enum RepoScope { year, last12 }

class AnalysisSoilPage extends StatefulWidget {
  const AnalysisSoilPage({super.key});
  @override
  State<AnalysisSoilPage> createState() => _AnalysisSoilPageState();
}

class _AnalysisSoilPageState extends State<AnalysisSoilPage> {
  static const kOrange = Color(0xFFF2AE2E);

  String? _unidadActual;
  List<SectionOption> _secciones = [];
  SectionOption? _seccionSeleccionada;
  bool _cargandoUnidad = true;
  bool _cargandoSecciones = false;

  final List<String> _options = const ['Análisis de Compactación', 'Análisis de Nutrientes'];
  String _selected = 'Análisis de Compactación';

  static const String kCompPdfPath = 'analisisdesuelo/Analisis_Compactacion/Manual_de_Operacion_Penetrometro.pdf';
  static const String kNutrPdfPath = 'analisisdesuelo/Analisis_Nutrientes/MANUAL_de_Operacion_Como_realizar_un_muestreo.pdf';

  final List<String> _archiveTopOptions = const ['Análisis', 'Reportes'];
  final List<String> _subAnalysis = const ['Análisis de Nutrientes', 'Análisis de Compactación'];
  final List<String> _subReports = const ['Reporte de Actividad Nutrientes', 'Reporte de Actividad Compactación'];
  String? _archiveTop;
  String? _archiveSub;

  RepoScope _repoScope = RepoScope.year;

  final List<String> _nutriAges = const ['Mayor de 2 años o sin análisis', 'Menos de 2 años'];
  String? _selectedAge;

  final List<File> _uploadedImages = [];
  final List<File> _uploadedPdfs = [];

  @override
  void initState() {
    super.initState();
    _cargarUnidadYSecciones();
  }

  Future<void> _cargarUnidadYSecciones() async {
    setState(() {
      _cargandoUnidad = true;
      _cargandoSecciones = false;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _cargandoUnidad = false);
        return;
      }
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final unidad = userDoc.data()?['unidadSeleccionada'] as String? ?? 'No asignada';
      setState(() {
        _unidadActual = unidad;
        _cargandoUnidad = false;
      });
      if (unidad.isEmpty || unidad == 'No asignada') return;

      setState(() => _cargandoSecciones = true);
      final uniDoc = await FirebaseFirestore.instance.collection('unidades_catalog').doc(unidad).get();
      final List<SectionOption> secciones = [];
      final raw = uniDoc.data()?['secciones'];

      if (raw is List) {
        for (final s in raw) {
          if (s is Map) {
            final label = (s['name'] ?? s['nombre'] ?? s['title'] ?? '').toString().trim();
            if (label.isEmpty) continue;
            final hect = s['hectarias'] ?? s['hectáreas'] ?? s['hectareas'];
            final num? hectNum = (hect is num) ? hect : num.tryParse(hect?.toString() ?? '');
            secciones.add(SectionOption(label: label, valueSlug: _slugFromName(label), hectareas: hectNum));
          } else if (s is String && s.trim().isNotEmpty) {
            final label = s.trim();
            secciones.add(SectionOption(label: label, valueSlug: _slugFromName(label)));
          }
        }
      }
      setState(() {
        _secciones = secciones;
        _cargandoSecciones = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoUnidad = false;
        _cargandoSecciones = false;
        _secciones = [];
      });
    }
  }

  String _hoyStamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  int _anioActual() => DateTime.now().year;
  String _seccionParaRuta() => _secciones.isEmpty ? 'seccion_unica' : (_seccionSeleccionada?.valueSlug ?? 'seccion_pendiente');

  // NUEVA: helper para generar slug de sección a nivel de clase
  String _slugFromName(String name) {
    final t = name.trim();
    final m = RegExp(r'(\d+)').firstMatch(t);
    if (m != null) return 'seccion_${m.group(1)}';
    final s = t
        .toLowerCase()
        .replaceAll(RegExp(r'[\\/]+'), '-')   // / y \ -> -
        .replaceAll(RegExp(r'[^a-z0-9_\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (s.isEmpty) return 'seccion';
    return s.startsWith('seccion_') ? s : 'seccion_$s';
  }

  String _sanitizeSegment(String input) {
    final s = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\\/]+'), '-')   // / y \ -> -
        .replaceAll(RegExp(r'[^a-z0-9_\s-]'), '') // quitar todo menos a-z,0-9, _, espacio y -
        .replaceAll(RegExp(r'\s+'), '_')      // espacios -> _
        .replaceAll(RegExp(r'_+'), '_');      // colapsar múltiples _
    return s.isEmpty ? 'na' : s;
  }

  String _rutaBaseNutrientes({required bool pdf}) {
    final unidad = _sanitizeSegment(_unidadActual ?? 'unidad');
    final carpetaTipo = pdf ? 'PDF' : 'imagen';
    final seccion = _sanitizeSegment(_seccionParaRuta());
    final anio = _anioActual();
    return 'unidades_info/$unidad/analisis_suelo/analisis_nutrientes/$carpetaTipo/$seccion/$anio';
  }

  String _nombreArchivoNutrientes({required bool pdf}) =>
      'analisis_laboratorio_${_hoyStamp()}${pdf ? '.pdf' : '.jpg'}';

  // Helpers TTL (12 meses)
  Timestamp _expireAt12M() => Timestamp.fromDate(DateTime.now().add(const Duration(days: 365)));

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? img = await picker.pickImage(source: ImageSource.gallery);
      if (img == null) return;
      setState(() => _uploadedImages.add(File(img.path)));
      await _guardarImagenesSeleccionadas();
    } catch (e) { _snack('No se pudo seleccionar la imagen: $e', error: true); }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      setState(() => _uploadedPdfs.add(File(path)));
      await _guardarPdfsSeleccionados();
    } catch (e) { _snack('No se pudo seleccionar el PDF: $e', error: true); }
  }

  Future<void> _guardarImagenesSeleccionadas() async {
    if (_unidadActual == null || _unidadActual!.isEmpty || _unidadActual == 'No asignada') {
      _snack('No hay Unidad seleccionada en la sesión.', error: true); return;
    }
    if (_secciones.isNotEmpty && (_seccionSeleccionada == null || _seccionSeleccionada!.valueSlug.isEmpty)) {
      _snack('Selecciona una Sección antes de subir.', error: true); return;
    }
    if (_uploadedImages.isEmpty) return;
    await _subirLoteArchivos(
      archivos: _uploadedImages,
      construirPath: (idx, f) => '${_rutaBaseNutrientes(pdf: false)}/${_nombreArchivoNutrientes(pdf: false)}',
      contentType: 'image/jpeg',
      registrarEn: 'uploads_analisis_nutrientes', // si usas otra coleccion, cámbiala aquí
      tipoArchivo: 'imagen',
    );
    setState(() => _uploadedImages.clear());
  }

  Future<void> _guardarPdfsSeleccionados() async {
    if (_unidadActual == null || _unidadActual!.isEmpty || _unidadActual == 'No asignada') {
      _snack('No hay Unidad seleccionada en la sesión.', error: true); return;
    }
    if (_secciones.isNotEmpty && (_seccionSeleccionada == null || _seccionSeleccionada!.valueSlug.isEmpty)) {
      _snack('Selecciona una Sección antes de subir.', error: true); return;
    }
    if (_uploadedPdfs.isEmpty) return;
    await _subirLoteArchivos(
      archivos: _uploadedPdfs,
      construirPath: (idx, f) => '${_rutaBaseNutrientes(pdf: true)}/${_nombreArchivoNutrientes(pdf: true)}',
      contentType: 'application/pdf',
      registrarEn: 'uploads_analisis_nutrientes', // si usas otra coleccion, cámbiala aquí
      tipoArchivo: 'PDF',
    );
    setState(() => _uploadedPdfs.clear());
  }

  Future<void> _subirLoteArchivos({
    required List<File> archivos,
    required String Function(int index, File f) construirPath,
    required String contentType,
    required String registrarEn,
    required String tipoArchivo,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _snack('Debes iniciar sesión para subir archivos.', error: true); return; }

    int subidos = 0;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Subiendo archivos…'),
          content: Row(children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(width: 12),
            Expanded(child: Text('Completados: $subidos / ${archivos.length}')),
          ]),
        ),
      ),
    );

    try {
      for (int i = 0; i < archivos.length; i++) {
        final f = archivos[i];
        final path = construirPath(i, f);
        final ref = FirebaseStorage.instance.ref(path);
        final bytes = await f.readAsBytes();
        final snap = await ref.putData(
          bytes,
          SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'uid': user.uid, // <- CRUCIAL para que las rules permitan crear y borrar
            },
          ),
        );
        final url = await snap.ref.getDownloadURL();

        // ---- escribimos metadata + TTL (expireAt) ----
        final meta = {
          'uid': user.uid,
          'unidad': _unidadActual,
          'seccion': _seccionParaRuta(),
          'tipoArchivo': tipoArchivo,
          'downloadUrl': url,
          'storagePath': path,
          'fecha': Timestamp.fromDate(DateTime.now()),
          'expireAt': _expireAt12M(), // <-- TTL 12 meses
        };

        // 1 doc por archivo: id determinístico
        final docId = path.replaceAll('/', '__');
        await FirebaseFirestore.instance.collection(registrarEn)
            .doc(docId).set(meta, SetOptions(merge: true));

        subidos++;
        if (context.mounted) {
          Navigator.of(context).pop();
          showDialog(
            context: context, barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Subiendo archivos…'),
              content: Row(children: [
                const CircularProgressIndicator(strokeWidth: 3),
                const SizedBox(width: 12),
                Expanded(child: Text('Completados: $subidos / ${archivos.length}')),
              ]),
            ),
          );
        }
      }
      if (context.mounted) Navigator.of(context).pop();
      _snack('Archivos subidos correctamente.');
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      _snack('Error al subir archivos: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green.shade700),
    );
  }

  Future<File> _assetToTempFile(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final file = File(p.join((await getTemporaryDirectory()).path, 'temp_${DateTime.now().millisecondsSinceEpoch}_${assetPath.split('/').last}'));
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _openPdf(String assetPath) async {
    try {
      final tmp = await _assetToTempFile(assetPath);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PdfViewerPage(filePath: tmp.path)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir el PDF: $e')));
    }
  }

  Future<void> _openLocalPdf(File file) async {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PdfViewerPage(filePath: file.path)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _unidadYSeccionHeader(),
          const SizedBox(height: 12),
          if (_requiereElegirSeccion() && _seccionSeleccionada == null)
            _placeholderCard('Selecciona una sección para continuar.')
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dropdownCard<String>(
                  label: 'Seleccionar concepto',
                  icon: Icons.biotech_outlined,
                  value: _selected,
                  hint: 'Elige Análisis de Compactación o de Nutrientes…',
                  items: _options.map((o) => DropdownMenuItem<String>(
                    value: o,
                    child: Row(children: [
                      Icon(o == 'Análisis de Compactación' ? Icons.analytics_outlined : Icons.science_outlined),
                      const SizedBox(width: 8),
                      Expanded(child: Text(o, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  )).toList(),
                  onChanged: (val) { if (val != null) setState(() { _selected = val; _selectedAge = null; }); },
                ),
                const SizedBox(height: 12),
                if (_selected == 'Análisis de Compactación') _soilContent(context) else _nutrientsContent(context),
              ],
            ),
        ],
      ),
    );
  }

  Widget _unidadYSeccionHeader() {
    final titulo = (_unidadActual == null || _unidadActual!.isEmpty) ? 'Cargando…' : _unidadActual!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        if (_cargandoUnidad || _cargandoSecciones) const LinearProgressIndicator(minHeight: 3),
        if (_secciones.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<SectionOption>(
            value: _seccionSeleccionada,
            isExpanded: true, isDense: true, menuMaxHeight: 320,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.segment_outlined),
              hintText: 'Selecciona Sección…',
              filled: true, fillColor: Colors.white.withOpacity(0.9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kOrange.withOpacity(0.35))),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
            items: _secciones.map((sec) {
              final hasHa = sec.hectareas != null;
              final haTxt = hasHa ? '${sec.hectareas} ha' : null;
              return DropdownMenuItem<SectionOption>(
                value: sec,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sec.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (hasHa) Text(haTxt!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ]),
              );
            }).toList(),
            selectedItemBuilder: (context) => _secciones.map((sec) {
              final hasHa = sec.hectareas != null;
              final compact = hasHa ? '${sec.label} — ${sec.hectareas} ha' : sec.label;
              return Align(alignment: Alignment.centerLeft, child: Text(compact, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)));
            }).toList(),
            onChanged: (val) => setState(() => _seccionSeleccionada = val),
          ),
        ],
      ],
    );
  }

  bool _requiereElegirSeccion() => _secciones.isNotEmpty;

  Widget _soilContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _primaryActionButton(
          icon: Icons.speed_outlined, label: 'Análisis de Compactación',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AnalisisCompactacionPage(),
            settings: RouteSettings(arguments: {
              'unidadSeleccionada': _unidadActual,
              'seccionSeleccionada': _seccionSeleccionada?.valueSlug ?? _seccionParaRuta(),
            }),
          )),
        ),
        const SizedBox(height: 10),
        _DocPreviewCard(
          leadingIcon: Icons.picture_as_pdf,
          title: p.basename(kCompPdfPath),
          subtitle: 'Toca para ver en pantalla completa',
          onTap: () => _openPdf(kCompPdfPath),
        ),
        const SizedBox(height: 12),
        _secondaryActionButton(
          icon: Icons.assignment_outlined, label: 'Reporte de Actividad',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ReporteActividadFormPage(
              titulo: 'Reporte de Actividad de Compactación',
              subtipo: 'Reporte de Actividad Compactación',
              coleccionDestino: 'reportes_compactacion',
            ),
            settings: RouteSettings(arguments: {
              'unidadSeleccionada': _unidadActual,
              'seccionSeleccionada': _seccionSeleccionada?.valueSlug ?? _seccionParaRuta(),
            }),
          )),
        ),
        const SizedBox(height: 14),
        _archiveSection(),
      ],
    );
  }

  Widget _nutrientsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dropdownCard<String>(
          label: 'Clasificación por antigüedad',
          icon: Icons.access_time_outlined,
          value: _selectedAge,
          hint: 'Selecciona una opción…',
          items: _nutriAges.map((o) => DropdownMenuItem<String>(
            value: o,
            child: Row(children: [
              Icon(o.startsWith('Mayor') ? Icons.hourglass_disabled_outlined : Icons.hourglass_bottom),
              const SizedBox(width: 8),
              Expanded(child: Text(o, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          )).toList(),
          onChanged: (val) => setState(() => _selectedAge = val),
        ),
        const SizedBox(height: 12),
        if (_selectedAge == null) _placeholderCard('Selecciona una clasificación para continuar.')
        else if (_selectedAge == 'Mayor de 2 años o sin análisis') _nutrientsOlderUI(context)
        else _nutrientsRecentUI(context),
        const SizedBox(height: 14),
        _archiveSection(),
      ],
    );
  }

  Widget _nutrientsOlderUI(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _primaryActionButton(
          icon: Icons.science_outlined, label: 'Análisis de Nutrientes',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AnalisisNutrientesPage(),
            settings: RouteSettings(arguments: {
              'unidadSeleccionada': _unidadActual,
              'seccionSeleccionada': _seccionSeleccionada?.valueSlug ?? _seccionParaRuta(),
            }),
          )),
        ),
        const SizedBox(height: 10),
        _DocPreviewCard(
          leadingIcon: Icons.picture_as_pdf,
          title: p.basename(kNutrPdfPath),
          subtitle: 'Toca para ver en pantalla completa',
          onTap: () => _openPdf(kNutrPdfPath),
        ),
        const SizedBox(height: 12),
        _secondaryActionButton(
          icon: Icons.assignment_outlined, label: 'Reporte de Actividad',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ReporteActividadNutrientesPage(),
            settings: RouteSettings(arguments: {
              'unidadSeleccionada': _unidadActual,
              'seccionSeleccionada': _seccionSeleccionada?.valueSlug ?? _seccionParaRuta(),
            }),
          )),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Subir archivos (PDF/JPG)'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            icon: const Icon(Icons.image_outlined),
            style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _pickImage, label: const Text('Subir imagen', style: TextStyle(fontWeight: FontWeight.w700)),
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: BorderSide(color: Colors.black.withOpacity(0.25)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)) ),
            onPressed: _pickPdf, label: const Text('Subir PDF', style: TextStyle(fontWeight: FontWeight.w700)),
          )),
        ]),
      ],
    );
  }

  Widget _nutrientsRecentUI(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _primaryActionButton(
          icon: Icons.science_outlined, label: 'Análisis de Nutrientes',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AnalisisNutrientesPage(),
            settings: RouteSettings(arguments: {
              'unidadSeleccionada': _unidadActual,
              'seccionSeleccionada': _seccionSeleccionada?.valueSlug ?? _seccionParaRuta(),
            }),
          )),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Subir archivos (PDF/JPG)'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            icon: const Icon(Icons.image_outlined),
            style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _pickImage, label: const Text('Subir imagen', style: TextStyle(fontWeight: FontWeight.w700)),
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: BorderSide(color: Colors.black.withOpacity(0.25)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _pickPdf, label: const Text('Subir PDF', style: TextStyle(fontWeight: FontWeight.w700)),
          )),
        ]),
      ],
    );
  }

  Widget _archiveSection() {
    final cardBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kOrange.withOpacity(0.35)));
    final List<String> subOptions = _archiveTop == 'Análisis' ? _subAnalysis : (_archiveTop == 'Reportes' ? _subReports : const []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Repositorio de resultados', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          ChoiceChip(label: const Text('Año actual'), selected: _repoScope == RepoScope.year, onSelected: (_) => setState(() => _repoScope = RepoScope.year)),
          ChoiceChip(label: const Text('Últimos 12 meses'), selected: _repoScope == RepoScope.last12, onSelected: (_) => setState(() => _repoScope = RepoScope.last12)),
        ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _archiveTop, isExpanded: true,
          decoration: InputDecoration(prefixIcon: const Icon(Icons.folder_open_outlined), hintText: 'Selecciona categoría (Análisis / Reportes)', filled: true, fillColor: Colors.white.withOpacity(0.9), border: cardBorder, contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
          items: _archiveTopOptions.map((o) => DropdownMenuItem<String>(
            value: o, child: Row(children: [Icon(o == 'Análisis' ? Icons.science_outlined : Icons.assignment_outlined), const SizedBox(width: 8), Expanded(child: Text(o, maxLines: 1, overflow: TextOverflow.ellipsis))]),
          )).toList(),
          onChanged: (val) => setState(() { _archiveTop = val; _archiveSub = null; }),
        ),
        if (_archiveTop != null) const SizedBox(height: 10),
        if (_archiveTop != null)
          DropdownButtonFormField<String>(
            value: _archiveSub, isExpanded: true,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.subdirectory_arrow_right), hintText: 'Selecciona el tipo específico', filled: true, fillColor: Colors.white.withOpacity(0.9), border: cardBorder, contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
            items: subOptions.map((o) => DropdownMenuItem<String>(value: o, child: Text(o))).toList(),
            onChanged: (val) => setState(() => _archiveSub = val),
          ),
        const SizedBox(height: 10),
        _ArchiveResultsList(
          top: _archiveTop, sub: _archiveSub, unidad: _unidadActual,
          seccion: _secciones.isEmpty ? 'seccion_unica' : (_seccionSeleccionada?.valueSlug ?? ''),
          scope: _repoScope,
        ),
      ],
    );
  }

  Widget _primaryActionButton({required IconData icon, required String label, required VoidCallback onPressed}) =>
      ElevatedButton.icon(
        icon: Icon(icon),
        style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        onPressed: onPressed, label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _secondaryActionButton({required IconData icon, required String label, required VoidCallback onPressed}) =>
      OutlinedButton.icon(
        icon: Icon(icon),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: BorderSide(color: Colors.black.withOpacity(0.25)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        onPressed: onPressed, label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  Widget _sectionTitle(String text) => Text(text, style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w700));
  Widget _uploadedImagesGrid() => Container(
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.08))),
    padding: const EdgeInsets.all(8),
    child: GridView.builder(
      itemCount: _uploadedImages.length, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
      itemBuilder: (context, i) => ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_uploadedImages[i], fit: BoxFit.cover)),
    ),
  );
  Widget _uploadedPdfsList() => Container(
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.08))),
    padding: const EdgeInsets.all(4),
    child: ListView.separated(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: _uploadedPdfs.length, separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => ListTile(
        leading: const Icon(Icons.picture_as_pdf),
        title: Text(p.basename(_uploadedPdfs[i].path), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _openLocalPdf(_uploadedPdfs[i]),
      ),
    ),
  );

  Widget _dropdownCard<T>({required String label, required IconData icon, required T? value, required String hint, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    final cardBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kOrange.withOpacity(0.35)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        value: value, isExpanded: true,
        decoration: InputDecoration(prefixIcon: Icon(icon), hintText: hint, filled: true, fillColor: Colors.white.withOpacity(0.9), border: cardBorder, contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
        items: items, onChanged: onChanged,
      ),
    ]);
  }

  Widget _placeholderCard(String text) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.08))),
    child: Text(text, style: TextStyle(color: Colors.grey.shade800)),
  );
}

// =================== Soporte: Cards reutilizables ===================

class _DocPreviewCard extends StatelessWidget {
  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DocPreviewCard({
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const kOrange = Color(0xFFF2AE2E);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: kOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(leadingIcon, size: 32, color: Colors.black87),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivePlaceholderCard extends StatelessWidget {
  final String? top;
  final String? sub;

  const _ArchivePlaceholderCard({required this.top, required this.sub});

  @override
  Widget build(BuildContext context) {
    final hasSelection = (top != null && sub != null);
    final text = hasSelection
        ? 'No se encontraron resultados para:\n• $top\n• $sub'
        : 'Selecciona una categoría y una subcategoría para ver los archivos generados aquí.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade800),
      ),
    );
  }
}

class _ArchiveResultsList extends StatelessWidget {
  final String? top;
  final String? sub;
  final String? unidad;
  final String? seccion;
  final RepoScope scope;
  const _ArchiveResultsList({required this.top, required this.sub, required this.unidad, required this.seccion, required this.scope});

  // Filtro por colección
  String _coleccionFS() {
    if (top == 'Análisis') {
      if (sub == 'Análisis de Compactación') return 'resultados_analisis_compactacion';
      if (sub == 'Análisis de Nutrientes') return 'resultados_analisis_nutrientes';
    } else if (top == 'Reportes') {
      if (sub == 'Reporte de Actividad Compactación') return 'reportes_compactacion';
      if (sub == 'Reporte de Actividad Nutrientes') return 'reportes_nutrientes';
    }
    return '';
  }

  // Fechas segun toggle
  DateTime _fromDate() {
    if (scope == RepoScope.last12) return DateTime.now().subtract(const Duration(days: 365));
    // Año actual
    final now = DateTime.now();
    return DateTime(now.year, 1, 1);
  }

  // Stream Firestore (solo docs “visibles” por rango + unidad + sección)
  Stream<QuerySnapshot<Map<String, dynamic>>> _firestoreStream() {
    final col = _coleccionFS();
    final needsSeccion = top == 'Análisis';
    if (col.isEmpty || unidad == null || unidad!.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    if (needsSeccion && (seccion == null || seccion!.isEmpty)) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    final desde = _fromDate();
    final selectedUnidad = unidad!;
    final selectedSeccion = needsSeccion ? seccion : null;

    switch (col) {
      case 'resultados_analisis_compactacion':
        return RepoQueries.resultadosCompactacion(
          unidadId: selectedUnidad,
          seccionId: selectedSeccion,
          desde: desde,
        ).snapshots();
      case 'resultados_analisis_nutrientes':
        return RepoQueries.resultadosNutrientes(
          unidadId: selectedUnidad,
          seccionId: selectedSeccion,
          desde: desde,
        ).snapshots();
      case 'reportes_compactacion':
        return RepoQueries.reportesCompactacion(
          unidadId: selectedUnidad,
          seccionId: selectedSeccion,
          desde: desde,
        ).snapshots();
      case 'reportes_nutrientes':
        return RepoQueries.reportesNutrientes(
          unidadId: selectedUnidad,
          seccionId: selectedSeccion,
          desde: desde,
        ).snapshots();
      default:
        return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
  }

  // De-dup por storagePath (o nombre+downloadUrl)
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _dedupeDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final map = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in docs) {
      final data = d.data();
      final storagePath = (data['storagePath'] as String?)?.trim() ?? '';
      final fecha = (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      final key = storagePath.isNotEmpty
          ? 'sp:$storagePath'
          : 'nf:${(data['nombre'] ?? '').toString()}|${(data['downloadUrl'] ?? '').toString()}';
      if (!map.containsKey(key)) {
        map[key] = d;
      } else {
        final oldFecha = (map[key]!.data()['fecha'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (fecha.isAfter(oldFecha)) map[key] = d; // conservar más reciente
      }
    }
    final list = map.values.toList();
    list.sort((a, b) {
      final fa = (a.data()['fecha'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      final fb = (b.data()['fecha'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      return fb.compareTo(fa);
    });
    return list;
  }

  Color _casoColor(String? caso) {
    switch (caso) { case 'verde': return const Color(0xFF2E7D32); case 'amarillo': return const Color(0xFFF9A825); case 'rojo': return const Color(0xFFC62828); default: return Colors.grey; }
  }

  String _safeFileName(String input) {
    final s = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_\-\. ]+'), '') // quitar raros
        .replaceAll(RegExp(r'\s+'), '_')             // espacios -> _
        .replaceAll('__', '_');
    return s.isEmpty ? 'reporte' : s;
  }

  @override
  Widget build(BuildContext context) {
    if (top == null || sub == null) return const _ArchivePlaceholderCard(top: null, sub: null);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestoreStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(alignment: Alignment.center, padding: const EdgeInsets.all(16), child: const CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.25))),
            child: Text('Error en Firestore: ${snap.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        final raw = snap.data?.docs ?? [];
        final fromDate = _fromDate();
        final filtered = raw.where((doc) {
          final fecha = (doc.data()['fecha'] as Timestamp?)?.toDate();
          if (fecha == null) return true;
          return !fecha.isBefore(fromDate);
        }).toList();
        final docs = _dedupeDocs(filtered);
        if (docs.isEmpty) return _ArchivePlaceholderCard(top: top, sub: sub);

        return Container(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.08))),
          child: ListView.separated(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length, separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final refDoc = docs[i].reference;
              final data = docs[i].data();
              final nombre = (data['nombre'] as String?) ?? 'Sin nombre';
              final encabezadoNombre = data['encabezado_nombre'] as String?;
              final fecha = (data['fecha'] as Timestamp?)?.toDate();
              final fechaStr = fecha == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(fecha);
              final url = data['downloadUrl'] as String?;
              final storagePath = data['storagePath'] as String?;
              final caso = data['caso'] as String?;

              Future<String?> _freshUrl() async {
                if (storagePath == null || storagePath.isEmpty) return url;
                try { return await FirebaseStorage.instance.ref(storagePath).getDownloadURL(); } catch (_) { return url; }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.picture_as_pdf, size: 20), const SizedBox(width: 8),
                    Expanded(child: Text(nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (caso != null) ...[
                      const SizedBox(width: 8),
                      Chip(label: Text(caso.toUpperCase(), style: const TextStyle(color: Colors.white)), backgroundColor: _casoColor(caso), visualDensity: VisualDensity.compact),
                    ],
                  ]),
                  if (encabezadoNombre != null)
                    Padding(padding: const EdgeInsets.only(top: 2), child: Text('Nombre: $encabezadoNombre', style: TextStyle(color: Colors.grey.shade800, fontSize: 12))),
                  Text(fechaStr, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Vista previa'),
                      onPressed: () async { final u = await _freshUrl(); if (u != null) await _openByUrl(context, u); },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Descargar'),
                      onPressed: () async { final u = await _freshUrl(); if (u != null) await _downloadToDevice(context, u, suggestedName: _safeFileName(nombre)); },
                    ),
                    // Eliminar: Firestore + Storage
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Eliminar'),
                            content: Text('¿Eliminar "$nombre"? Esta acción no se puede deshacer.\nSe borrará el registro (Firestore) y el archivo (Storage).'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                              ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
                            ],
                          ),
                        );
                        if (ok != true) return;

                        try {
                          // 1) Storage (si hay path)
                          if (storagePath != null && storagePath.isNotEmpty) {
                            await FirebaseStorage.instance.ref(storagePath).delete();
                          }
                          // 2) Firestore doc
                          await refDoc.delete();

                          // feedback
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Eliminado (Firestore + Storage)')));
                        } on FirebaseException catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('No se pudo eliminar: ${e.message ?? e.code}')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
                        }
                      },
                    ),
                  ]),
                ]),
              );
            },
          ),
        );
      },
    );
  }

  // Helpers reutilizados del padre (copiados porque estamos en Stateless)
  Future<void> _downloadToDevice(BuildContext context, String url, {required String suggestedName}) async {
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) throw 'HTTP ${resp.statusCode}';
      final file = File(p.join((await getApplicationDocumentsDirectory()).path, '$suggestedName.pdf'));
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Descargado en: ${file.path}')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo descargar: $e')));
    }
  }

  Future<void> _openByUrl(BuildContext context, String url) async {
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) throw 'HTTP ${resp.statusCode} al descargar el archivo';
      final bytes = resp.bodyBytes;
      if (bytes.isEmpty) throw 'El archivo descargado está vacío (0 bytes).';
      if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
        throw 'El archivo no es un PDF válido (no inicia con %PDF-).';
      }
      final file = File(p.join((await getTemporaryDirectory()).path, 'repo_${DateTime.now().millisecondsSinceEpoch}.pdf'));
      await file.writeAsBytes(bytes, flush: true);
      if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PdfViewerPage(filePath: file.path)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir el PDF: $e')));
    }
  }
}

// =================== Visor PDF simple ===================

class _PdfViewerPage extends StatelessWidget {
  final String filePath;
  const _PdfViewerPage({required this.filePath});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(filePath)), backgroundColor: const Color(0xFFF2AE2E), foregroundColor: Colors.black),
      body: PDFView(
        filePath: filePath, enableSwipe: true, autoSpacing: true, pageFling: true,
        onError: (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al renderizar PDF: $error'))),
        onPageError: (page, error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en página $page: $error'))),
        onRender: (pages) {
          if (pages == 0) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El PDF no tiene páginas para mostrar.')));
          }
        },
      ),
    );
  }
}