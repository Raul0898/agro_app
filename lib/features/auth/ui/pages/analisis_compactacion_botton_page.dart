// lib/features/auth/ui/pages/analisis_compactacion_botton_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, TextInputFormatter, FilteringTextInputFormatter;
import 'package:agro_app/features/auth/data/repo_queries.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ---------- Helpers de assets ----------
Future<pw.ThemeData> _loadPdfTheme() async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  return pw.ThemeData.withFont(base: regular, bold: bold);
}

Future<Uint8List?> _tryLoadAssetBytes(List<String> paths) async {
  for (final p in paths) {
    try {
      final bd = await rootBundle.load(p);
      return bd.buffer.asUint8List();
    } catch (_) {}
  }
  return null;
}

// ---------- Lógica de caso ----------
enum _Caso { verde, amarillo, rojo, ninguno }

_Caso _clasificarPorPromedios(Map<String, double?> proms) {
  final medio = proms['15-28'];
  if (medio == null) return _Caso.ninguno;
  if (medio <= 100) return _Caso.verde;
  if (medio <= 200) return _Caso.amarillo;
  return _Caso.rojo;
}

String _casoToString(_Caso c) {
  switch (c) {
    case _Caso.verde: return 'verde';
    case _Caso.amarillo: return 'amarillo';
    case _Caso.rojo: return 'rojo';
    case _Caso.ninguno:
    default: return 'ninguno';
  }
}

PdfColor _colorForCaso(_Caso c) {
  switch (c) {
    case _Caso.verde: return PdfColor(0.85, 1.0, 0.85);
    case _Caso.amarillo: return PdfColor(1.0, 1.0, 0.80);
    case _Caso.rojo: return PdfColor(1.0, 0.85, 0.85);
    case _Caso.ninguno:
    default: return PdfColor(0.95, 0.95, 0.95);
  }
}

PdfColor? _bgForPsi(double? v) {
  if (v == null) return null;
  if (v <= 100) return PdfColor(0.90, 1.0, 0.90);
  if (v <= 200) return PdfColor(1.0, 1.0, 0.90);
  return PdfColor(1.0, 0.92, 0.92);
}

String _mensajeRecomendacion(_Caso caso) {
  switch (caso) {
    case _Caso.verde:
      return 'Suelo en buenas condiciones para establecer LC. CONDICIONES OPTIMAS';
    case _Caso.amarillo:
      return 'Suelo en condiciones limitadas para establecer LC. SE PUEDE ESTABLECER LC, BAJO CRITERIO DE LAS OTRAS VARIABLES.';
    case _Caso.rojo:
      return 'Suelo muy compactado, no se recomienda establecer LC, se requiere acondicionamiento del suelo. NO ESTABLECER LC, SE REQUIERE ACONDICIONAR.';
    case _Caso.ninguno:
    default:
      return 'Sin datos suficientes para emitir recomendación.';
  }
}

String _subsueloMsg(_Caso c) {
  switch (c) {
    case _Caso.verde:
    case _Caso.amarillo:
      return 'No requiere subsuelo';
    case _Caso.rojo:
      return 'Requiere subsuelo';
    case _Caso.ninguno:
    default:
      return '—';
  }
}

String _estadoSueloMsg(_Caso c) {
  switch (c) {
    case _Caso.verde: return 'Suelo no compactado';
    case _Caso.amarillo: return 'Suelo medio compactado';
    case _Caso.rojo: return 'Suelo compactado';
    case _Caso.ninguno:
    default: return '—';
  }
}

// =======================================================
//                    PÁGINA PRINCIPAL
// =======================================================
class AnalisisCompactacionPage extends StatefulWidget {
  const AnalisisCompactacionPage({super.key});
  @override
  State<AnalisisCompactacionPage> createState() => _AnalisisCompactacionBottonPageState();
}

class _AnalisisCompactacionBottonPageState extends State<AnalisisCompactacionPage> {
  static const kOrange = Color(0xFFF2AE2E);

  String _unidad = 'Unidad';
  String _seccion = 'seccion_unica';
  bool _argsLoaded = false;

  int get _year => DateTime.now().year;
  String _ts() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  final TextEditingController _nombreCtrl = TextEditingController();

  final List<int> _pruebas = List<int>.generate(15, (i) => i + 1);
  final List<int> _profundidades = const [3, 5, 8, 10, 13, 15, 18, 20, 23, 25, 28, 30, 33, 36, 38];
  late final List<TextEditingController> _psiCtrls;
  final List<TextInputFormatter> _numFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}$')),
  ];

  @override
  void initState() {
    super.initState();
    _psiCtrls = List<TextEditingController>.generate(15, (_) => TextEditingController());
    for (final c in _psiCtrls) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _unidad = (args['unidadSeleccionada'] as String?)?.trim().isNotEmpty == true
          ? (args['unidadSeleccionada'] as String).trim()
          : _unidad;
      _seccion = (args['seccionSeleccionada'] as String?)?.trim().isNotEmpty == true
          ? (args['seccionSeleccionada'] as String).trim()
          : _seccion;
    }
    _argsLoaded = true;
  }

  @override
  void dispose() {
    for (final c in _psiCtrls) c.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  double? get _avgPSI {
    final values = _psiCtrls
        .map((c) => double.tryParse(c.text.trim().replaceAll(',', '.')))
        .where((v) => v != null)
        .cast<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  void _clearAll() {
    for (final c in _psiCtrls) c.clear();
    FocusScope.of(context).unfocus();
  }

  Map<String, double?> _promediosPorRango() {
    double s0_13 = 0; int n0_13 = 0;
    double s15_28 = 0; int n15_28 = 0;
    double s30_38 = 0; int n30_38 = 0;
    for (int i = 0; i < _profundidades.length; i++) {
      final d = _profundidades[i];
      final v = double.tryParse(_psiCtrls[i].text.trim().replaceAll(',', '.'));
      if (v == null) continue;
      if (d <= 13) { s0_13 += v; n0_13++; }
      else if (d >= 15 && d <= 28) { s15_28 += v; n15_28++; }
      else if (d >= 30) { s30_38 += v; n30_38++; }
    }
    return {
      '0-13': n0_13 == 0 ? null : s0_13 / n0_13,
      '15-28': n15_28 == 0 ? null : s15_28 / n15_28,
      '30-38': n30_38 == 0 ? null : s30_38 / n30_38,
      'Mayor': n15_28 == 0 ? null : s15_28 / n15_28,
    };
  }

  // ---------------- Generación de PDF ----------------
  Future<Uint8List> _buildPdfBytes({
    required List<int> pruebas,
    required List<int> profundidades,
    required List<double?> psiValues,
    required double? avgGlobal,
    required Map<String, double?> promedios,
    String? nombre,
  }) async {
    final theme = await _loadPdfTheme();
    final doc = pw.Document(theme: theme);

    final caso = _clasificarPorPromedios(promedios);
    final recomendacion = _mensajeRecomendacion(caso);

    final headerBytes = await _tryLoadAssetBytes([
      'IMG/recomendaciones.png',
      'IMG/recomendaciones.jpg',
      'IMG/recomendaciones.jpeg',
    ]);

    final subsueloBytes = await _tryLoadAssetBytes([
      'IMG/subsuelo.png',
      'IMG/subsuelo.jpg',
      'IMG/subsuelo.jpeg',
    ]);

    pw.Widget _headerText() => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Análisis de Compactación', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text('Unidad: $_unidad   —   Sección: $_seccion', style: const pw.TextStyle(fontSize: 11)),
        if (nombre != null) pw.SizedBox(height: 2),
        if (nombre != null) pw.Text('Nombre: $nombre', style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 2),
        pw.Text('Fecha: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
      ],
    );

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFE2BF)),
        children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('N°', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Profundidad (cm)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Compactación (PSI)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ],
      ),
    ];

    for (var i = 0; i < pruebas.length; i++) {
      final psi = psiValues[i];
      rows.add(
        pw.TableRow(
          children: [
            pw.Container(color: PdfColors.white, child: pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${pruebas[i]}'))),
            pw.Container(color: PdfColors.white, child: pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${profundidades[i]}'))),
            pw.Container(
              color: _bgForPsi(psi) ?? PdfColors.white,
              child: pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(psi == null ? '—' : psi.toStringAsFixed(2))),
            ),
          ],
        ),
      );
    }

    pw.Widget _promsBox() {
      pw.Widget line(String label, double? v) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label), pw.Text(v == null ? '—' : v.toStringAsFixed(2))],
      );
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromInt(0x22000000)),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Promedios', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            line('0–13 cm', promedios['0-13']),
            line('15–28 cm', promedios['15-28']),
            line('30–38 cm', promedios['30-38']),
            pw.Divider(),
            line('Media Global (PSI)', avgGlobal),
          ],
        ),
      );
    }

    pw.Widget _recoBox() => pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _colorForCaso(caso),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFBFBFBF)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Recomendación', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text(_subsueloMsg(caso), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(_estadoSueloMsg(caso), style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.Text(recomendacion, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 28, 24, 28),
        build: (ctx) => [
          if (headerBytes != null)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Image(
                pw.MemoryImage(headerBytes),
                width: PdfPageFormat.a4.availableWidth,
                height: PdfPageFormat.a4.availableHeight * 0.22,
                fit: pw.BoxFit.contain,
              ),
            ),
          _headerText(),
          pw.SizedBox(height: 10),
          pw.Table(border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFD9D9D9)), defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle, children: rows),
          pw.SizedBox(height: 12),
          _promsBox(),
          pw.SizedBox(height: 12),
          _recoBox(),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('≤100 PSI: Verde', style: pw.TextStyle(fontSize: 9)),
              pw.Text('101–200 PSI: Amarillo', style: pw.TextStyle(fontSize: 9)),
              pw.Text('≥201 PSI: Rojo', style: pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Generado por IDRA', style: pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------- Diálogos de progreso ----------------
  void _showStorageUploadDialog(UploadTask task) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StreamBuilder<TaskSnapshot>(
                stream: task.snapshotEvents,
                builder: (context, snap) {
                  final transferred = snap.data?.bytesTransferred ?? 0;
                  final total = snap.data?.totalBytes ?? 1;
                  final pct = total == 0 ? 0.0 : (transferred / total).clamp(0.0, 1.0);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LogoProgress(progress: pct),
                      const SizedBox(height: 12),
                      Text('Subiendo reporte… ${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      const Text('No cierres esta ventana', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _withBlockingSavingDialog(Future<void> Function() action, {String message = 'Guardando…'}) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(width: 6),
              CircularProgressIndicator(strokeWidth: 3),
              SizedBox(width: 14),
              Text('Guardando…'),
            ],
          ),
        ),
      ),
    );
    try {
      await action();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green.shade700),
    );
  }

  // ---------------- Guardado / Duplicados / Sobrescritura ----------------
  Future<void> _emitirRecomendacion() async {
    final mode = await _showSaveModeDialog();
    if (mode == null || !mounted) return;

    final psiValues = _psiCtrls.map((c) => double.tryParse(c.text.trim().replaceAll(',', '.'))).toList();
    final tieneDatos = _psiCtrls.any((c) => double.tryParse(c.text.trim().replaceAll(',', '.')) != null);
    if (!tieneDatos) {
      _showSnack('Ingresa al menos un valor de PSI para generar el reporte.', error: true);
      return;
    }

    bool ok = false;
    if (mode == _SaveMode.nuevo) {
      final nombreArchivo = await _askFileNameEnsureUniqueOrOverwrite();
      if (nombreArchivo == null || !mounted) return;
      ok = await _saveNewResult(nombreArchivo: nombreArchivo, psiValues: psiValues);
      if (ok) {
        _showSnack('Archivo creado y guardado exitosamente.');
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.of(context).pop();
      }
    } else {
      final doc = await _pickExistingResultForOverwrite();
      if (doc == null || !mounted) return;
      ok = await _overwriteExistingResult(doc, psiValues: psiValues);
      if (ok) {
        _showSnack('Archivo sobrescrito/actualizado exitosamente.');
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  String _buildStoragePathNew(String fileName) {
    final u = _sanitizeSegment(_unidad);
    final s = _sanitizeSegment(_seccion);
    return 'unidades_info/$u/analisis_suelo/analisis/analisis_compactacion/$s/$_year/$fileName';
  }

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

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findDuplicateByName(String nombreExacto) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final q = await FirebaseFirestore.instance
        .collection('resultados_analisis_compactacion')
        .where('uid', isEqualTo: user.uid)
        .where('unidad', isEqualTo: _unidad)
        .where('seccion', isEqualTo: _seccion)
        .where('year', isEqualTo: _year)
        .where('nombre', isEqualTo: nombreExacto)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first;
  }

  Future<String?> _askFileNameEnsureUniqueOrOverwrite() async {
    while (mounted) {
      final name = await _askFileName();
      if (name == null) return null;
      final dup = await _findDuplicateByName(name);
      if (dup == null) return name;

      final choice = await showDialog<_DupChoice>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('El nombre ya existe'),
          content: Text('Ya existe un archivo llamado "$name" en esta unidad, sección y año.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(_DupChoice.rename), child: const Text('Renombrar')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(_DupChoice.overwrite), child: const Text('Sobrescribir')),
            TextButton(onPressed: () => Navigator.of(context).pop(_DupChoice.cancel), child: const Text('Cancelar')),
          ],
        ),
      );

      if (choice == _DupChoice.cancel || choice == null) return null;
      if (choice == _DupChoice.rename) continue;

      final psiValues = _psiCtrls.map((c) => double.tryParse(c.text.trim().replaceAll(',', '.'))).toList();
      final ok = await _overwriteExistingResult(dup, psiValues: psiValues);
      if (ok) {
        _showSnack('Archivo sobrescrito/actualizado exitosamente.');
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.of(context).pop();
      }
      return null;
    }
    return null;
  }

  Future<bool> _saveNewResult({required String nombreArchivo, required List<double?> psiValues}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Error: No se ha iniciado sesión.', error: true);
      return false;
    }

    try {
      final now = DateTime.now();
      final proms = _promediosPorRango();
      final caso = _clasificarPorPromedios(proms);

      final pdfBytes = await _buildPdfBytes(
        pruebas: _pruebas,
        profundidades: _profundidades,
        psiValues: psiValues,
        avgGlobal: _avgPSI,
        promedios: proms,
        nombre: _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
      );

      final fileName = 'Analisis_Compactacion_${_ts()}.pdf';
      final storagePath = _buildStoragePathNew(fileName);
      final ref = FirebaseStorage.instance.ref(storagePath);

      final uploadTask = ref.putData(
        pdfBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: { 'uid': user.uid },
        ),
      );
      _showStorageUploadDialog(uploadTask);
      final snap = await uploadTask;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      final downloadUrl = await snap.ref.getDownloadURL();

      await _withBlockingSavingDialog(() async {
        await FirebaseFirestore.instance.collection('resultados_analisis_compactacion').add({
          'uid': user.uid,
          'ownerUid': user.uid,
          'canDelete': true,
          'tipo': 'Análisis',
          'nombre': nombreArchivo,
          'year': _year,
          'encabezado_nombre': _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
          'caso': _casoToString(caso),
          'fecha': Timestamp.fromDate(now),
          'storagePath': storagePath,
          'downloadUrl': downloadUrl,
          'unidad': _unidad,
          'seccion': _seccion,
          'promedio_global': _avgPSI,
          'avg_0_13': proms['0-13'],
          'avg_15_28': proms['15-28'],
          'avg_30_38': proms['30-38'],
          'avg_mayor_importancia': proms['Mayor'],
          'valores': List.generate(
            _pruebas.length,
                (i) => {'n': _pruebas[i], 'profundidad_cm': _profundidades[i], 'psi': psiValues[i]},
          ),
        });
      }, message: 'Guardando en la base de datos…');

      return true;
    } catch (e) {
      _showSnack('No se pudo crear el archivo: $e', error: true);
      return false;
    }
  }

  Future<bool> _overwriteExistingResult(
      DocumentSnapshot<Map<String, dynamic>> doc, {
        required List<double?> psiValues,
      }) async {
    final data = doc.data();
    if (data == null) {
      _showSnack('Documento inválido.', error: true);
      return false;
    }

    try {
      final storagePath = data['storagePath'] as String?;
      final now = DateTime.now();
      final proms = _promediosPorRango();
      final caso = _clasificarPorPromedios(proms);

      final pdfBytes = await _buildPdfBytes(
        pruebas: _pruebas,
        profundidades: _profundidades,
        psiValues: psiValues,
        avgGlobal: _avgPSI,
        promedios: proms,
        nombre: _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
      );

      UploadTask uploadTask;
      Reference ref;
      if (storagePath != null && storagePath.isNotEmpty) {
        ref = FirebaseStorage.instance.ref(storagePath);
      } else {
        final fileName = 'Analisis_Compactacion_${_ts()}.pdf';
        final newPath = _buildStoragePathNew(fileName);
        ref = FirebaseStorage.instance.ref(newPath);
      }

      final user = FirebaseAuth.instance.currentUser!;
      uploadTask = ref.putData(
        pdfBytes,
        SettableMetadata(contentType: 'application/pdf', customMetadata: {'uid': user.uid}),
      );
      _showStorageUploadDialog(uploadTask);
      final snap = await uploadTask;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      final downloadUrl = await snap.ref.getDownloadURL();
      final finalPath = ref.fullPath;

      await _withBlockingSavingDialog(() async {
        await FirebaseFirestore.instance.collection('resultados_analisis_compactacion').doc(doc.id).update({
          'fecha': Timestamp.fromDate(now),
          'downloadUrl': downloadUrl,
          'storagePath': finalPath,
          'ownerUid': user.uid,
          'canDelete': true,
          'year': _year,
          'unidad': _unidad,
          'seccion': _seccion,
          'encabezado_nombre': _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
          'caso': _casoToString(caso),
          'promedio_global': _avgPSI,
          'avg_0_13': proms['0-13'],
          'avg_15_28': proms['15-28'],
          'avg_30_38': proms['30-38'],
          'avg_mayor_importancia': proms['Mayor'],
          'valores': List.generate(
            _pruebas.length,
                (i) => {'n': _pruebas[i], 'profundidad_cm': _profundidades[i], 'psi': psiValues[i]},
          ),
        });
      }, message: 'Actualizando en la base de datos…');

      return true;
    } catch (e) {
      _showSnack('No se pudo sobrescribir el archivo: $e', error: true);
      return false;
    }
  }

  // === CAMBIO: listar candidatos a sobrescribir DESDE FIRESTORE con fallback ===
  Future<DocumentSnapshot<Map<String, dynamic>>?> _pickExistingResultForOverwrite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // Trae TODO lo del usuario y filtramos en memoria por unidad/sección o por storagePath
      final query = RepoQueries.resultadosCompactacion(
        unidadId: _unidad,
        seccionId: _seccion,
        desde: null,
      );
      final snap = await query.get();

      final uSan = _sanitizeSegment(_unidad);
      final sSan = _sanitizeSegment(_seccion);

      bool coincidePorCampos(Map<String, dynamic> d) {
        final u = d['unidad'];
        final s = d['seccion'];
        if (u is String && s is String) {
          return u == _unidad && s == _seccion; // comparación exacta (mantienes mayúsculas/espacios)
        }
        return false;
      }

      bool coincidePorRuta(Map<String, dynamic> d) {
        final path = d['storagePath'] as String?;
        if (path == null || path.isEmpty) return false;
        // unidades_info/<uSan>/analisis_suelo/analisis/analisis_compactacion/<sSan>/
        return path.contains('/unidades_info/$uSan/')
            && path.contains('/analisis_suelo/analisis/analisis_compactacion/$sSan/');
      }

      var docs = snap.docs.where((e) {
        final d = e.data();
        final ownerUid = d['ownerUid'] as String?;
        final legacyUid = d['uid'] as String?;
        final belongsToUser = ownerUid == user.uid || legacyUid == user.uid;
        if (!belongsToUser) return false;
        return coincidePorCampos(d) || coincidePorRuta(d);
      }).toList();

      if (docs.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (_) => Theme(
            data: Theme.of(context).copyWith(
              dialogBackgroundColor: Colors.white,
              textTheme: Theme.of(context).textTheme.apply(
                bodyColor: Colors.black,
                displayColor: Colors.black,
              ),
              iconTheme: const IconThemeData(color: Colors.black87),
            ),
            child: const AlertDialog(
              title: Text('No hay archivos', style: TextStyle(color: Colors.black)),
              content: Text('No se encontraron resultados para esta unidad y sección.', style: TextStyle(color: Colors.black87)),
            ),
          ),
        );
        return null;
      }

      return showDialog<DocumentSnapshot<Map<String, dynamic>>?>(
        context: context,
        builder: (_) => Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.white,
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.black,
              displayColor: Colors.black,
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
          ),
          child: AlertDialog(
            title: const Text('Selecciona archivo a sobrescribir', style: TextStyle(color: Colors.black)),
            content: SizedBox(
              width: double.maxFinite,
              child: Scrollbar(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1F000000)),
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final nombre = (d['nombre'] as String?) ?? 'Sin nombre';
                    final fecha = (d['fecha'] as Timestamp?)?.toDate();
                    final fechaStr = fecha == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(fecha);
                    return ListTile(
                      leading: const Icon(Icons.picture_as_pdf,color: Colors.orange),
                      title: Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.orange),
                      ),
                      subtitle: Text(
                        fechaStr,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      onTap: () => Navigator.of(context).pop(docs[i]),
                    );
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar', style: TextStyle(color: Colors.black87)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      await showDialog<void>(
        context: context,
        builder: (_) => Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.white,
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.black,
              displayColor: Colors.black,
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
          ),
          child: AlertDialog(
            title: const Text('Error', style: TextStyle(color: Colors.black)),
            content: Text('No se pudo cargar la lista desde Firestore: $e', style: const TextStyle(color: Colors.black87)),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK', style: TextStyle(color: Colors.black87))),
            ],
          ),
        ),
      );
      return null;
    }
  }

  Future<_SaveMode?> _showSaveModeDialog() async {
    return showDialog<_SaveMode>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Guardar resultado'),
        content: const Text('¿Deseas crear un nuevo archivo o sobrescribir uno existente?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(_SaveMode.nuevo), child: const Text('Nuevo archivo')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(_SaveMode.sobrescribir), child: const Text('Sobrescribir')),
        ],
      ),
    );
  }

  Future<String?> _askFileName() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nombre del archivo'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Ej: Lote A - Penetrómetro Mayo',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(context).pop(name); // nombre EXACTO
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.black87);
    final cellTextStyle = theme.textTheme.bodyMedium?.copyWith(color: Colors.black87);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis de Compactación'),
        backgroundColor: kOrange,
        foregroundColor: Colors.black,
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre (opcional)',
                hintText: 'Ej: Lote A',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kOrange.withOpacity(0.35)),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: kOrange.withOpacity(0.18),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 70, child: Text('N°', style: headerStyle)),
                        SizedBox(width: 120, child: Text('Prof. (cm)', style: headerStyle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('PSI', style: headerStyle)),
                      ],
                    ),
                  ),
                  ...List.generate(_pruebas.length, (i) {
                    final stripe = i.isEven ? Colors.white : Colors.grey.withOpacity(0.04);
                    return Container(
                      color: stripe,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 70, child: Text('${_pruebas[i]}', style: cellTextStyle)),
                          SizedBox(width: 120, child: Text('${_profundidades[i]}', style: cellTextStyle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _psiCtrls[i],
                              keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                              inputFormatters: _numFormatters,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'PSI',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.black.withOpacity(0.08)))),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(width: 70, child: Text('Media', style: cellTextStyle?.copyWith(fontWeight: FontWeight.w700))),
                        const SizedBox(width: 120, child: Text('—')),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black.withOpacity(0.08)),
                            ),
                            child: Text(
                              _avgPSI == null ? '—' : _avgPSI!.toStringAsFixed(2),
                              style: cellTextStyle?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _emitirRecomendacion,
                    label: const Text('Emitir Recomendación', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.black.withOpacity(0.25)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _clearAll,
                    label: const Text('Borrar todo', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _SaveMode { nuevo, sobrescribir }
enum _DupChoice { rename, overwrite, cancel }

class _LogoProgress extends StatelessWidget {
  final double progress;
  const _LogoProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160, height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('IMG/Logo1.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: CircularProgressIndicator(strokeWidth: 3))),
          Positioned.fill(
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: progress.clamp(0.0, 1.0),
                child: Image.asset('IMG/Logo1.png', fit: BoxFit.contain, colorBlendMode: BlendMode.srcATop),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
