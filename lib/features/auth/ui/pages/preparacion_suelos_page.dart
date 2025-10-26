// lib/features/auth/ui/pages/preparacion_suelos_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:agro_app/features/auth/ui/pages/reporte_actividad_form_page.dart';

class PreparacionSuelosPage extends StatefulWidget {
  const PreparacionSuelosPage({super.key});

  @override
  State<PreparacionSuelosPage> createState() => _PreparacionSuelosPageState();
}

enum _CasoCompactacion { verde, amarillo, rojo }
enum _DecisionAmarillo { none, realizar, no_realizar }

class _AssetEntry {
  final String name;
  final bool isDir;
  final String fullPath;
  final bool isVirtualNone;
  const _AssetEntry({required this.name, required this.isDir, required this.fullPath, this.isVirtualNone = false});
}

class _AssetLevel {
  final String prefix;
  final String? selectedPath;
  const _AssetLevel({required this.prefix, this.selectedPath});
  _AssetLevel copyWith({String? prefix, String? selectedPath}) => _AssetLevel(prefix: prefix ?? this.prefix, selectedPath: selectedPath ?? this.selectedPath);
}

class _PreparacionSuelosPageState extends State<PreparacionSuelosPage> {
  static const kOrange = Color(0xFFF2AE2E);
  _DecisionAmarillo _amarilloDecision = _DecisionAmarillo.none;
  bool _loadingDecision = true;
  static const String kSupBase = 'Produccion e Investigacion/Preparacion de Suelos/Laboreo Superficial/';
  static const String kRastreoPrefix = '${kSupBase}Rastreo/';
  static const String kDestPrefix = '${kSupBase}Desterronador/';
  bool _manifestLoaded = false;
  String? _manifestError;
  List<String> _assets = [];
  final List<String> _laboreoOptions = const ['Rastreo', 'Desterronador', 'Ambos'];
  String? _laboreoSelected;
  late List<_AssetLevel> _levelsR;
  late List<_AssetLevel> _levelsD;
  String? _selectedFileRastreo;
  String? _selectedFileDest;
  final List<String> _repoTipos = const ['Reportes de Laboreo Profundo', 'Reportes de Laboreo Superficial'];
  String _repoTipoSel = 'Reportes de Laboreo Profundo';

  String get _repoColeccion {
    if (_repoTipoSel == 'Reportes de Laboreo Superficial') {
      return 'reportes_preparacion_suelos';
    }
    return 'reportes_preparacion_suelos';
  }

  @override
  void initState() {
    super.initState();
    _levelsR = [const _AssetLevel(prefix: kRastreoPrefix)];
    _levelsD = [const _AssetLevel(prefix: kDestPrefix)];
    _loadDecision();
    _loadAssetManifest();
  }

  Future<void> _loadDecision() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _loadingDecision = false);
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('ui_state').doc('preparacion_suelos').collection('users').doc(uid).get();
      final val = doc.data()?['amarilloSeleccion'] as String?;
      setState(() {
        if (val == 'realizar') _amarilloDecision = _DecisionAmarillo.realizar;
        else if (val == 'no_realizar') _amarilloDecision = _DecisionAmarillo.no_realizar;
        else _amarilloDecision = _DecisionAmarillo.none;
        _loadingDecision = false;
      });
    } catch (_) {
      setState(() {
        _amarilloDecision = _DecisionAmarillo.none;
        _loadingDecision = false;
      });
    }
  }

  Future<void> _saveDecision(_DecisionAmarillo d) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    String? val;
    if (d == _DecisionAmarillo.realizar) val = 'realizar';
    if (d == _DecisionAmarillo.no_realizar) val = 'no_realizar';
    await FirebaseFirestore.instance.collection('ui_state').doc('preparacion_suelos').collection('users').doc(uid).set({'amarilloSeleccion': val, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  _CasoCompactacion _evaluarCaso(double mayor) {
    if (mayor >= 200) return _CasoCompactacion.rojo;
    if (mayor >= 100) return _CasoCompactacion.amarillo;
    return _CasoCompactacion.verde;
  }

  String _textoCaso(_CasoCompactacion c) {
    switch (c) {
      case _CasoCompactacion.verde: return 'No Requiere Subsuelo';
      case _CasoCompactacion.amarillo: return 'No Requiere Subsuelo (condición limitada)';
      case _CasoCompactacion.rojo: return 'Requiere Subsuelo';
    }
  }

  Color _colorCasoBg(_CasoCompactacion c) {
    switch (c) {
      case _CasoCompactacion.verde: return Colors.green.withOpacity(0.12);
      case _CasoCompactacion.amarillo: return Colors.yellow.shade700.withOpacity(0.12);
      case _CasoCompactacion.rojo: return Colors.red.withOpacity(0.12);
    }
  }

  Color _colorCasoBorder(_CasoCompactacion c) {
    switch (c) {
      case _CasoCompactacion.verde: return Colors.green.withOpacity(0.45);
      case _CasoCompactacion.amarillo: return Colors.yellow.shade700.withOpacity(0.5);
      case _CasoCompactacion.rojo: return Colors.red.withOpacity(0.45);
    }
  }

  IconData _iconCaso(_CasoCompactacion c) {
    switch (c) {
      case _CasoCompactacion.verde: return Icons.check_circle;
      case _CasoCompactacion.amarillo: return Icons.warning_amber;
      case _CasoCompactacion.rojo: return Icons.report_gmailerrorred;
    }
  }

  Future<void> _loadAssetManifest() async {
    try {
      final raw = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> man = json.decode(raw);
      final allKeys = man.keys.map((e) => e.toString()).toList();
      _assets = allKeys.where((k) => k.startsWith(kSupBase)).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        _manifestLoaded = true;
        _manifestError = null;
      });
    } catch (e) {
      setState(() {
        _manifestLoaded = true;
        _manifestError = 'No se pudo cargar el índice de assets. Detalle: $e';
      });
    }
  }

  List<_AssetEntry> _childrenOfPrefix(String prefix) {
    final List<_AssetEntry> result = [];
    final Set<String> dirNames = {};
    final Set<String> fileNames = {};

    for (final asset in _assets) {
      if (!asset.startsWith(prefix)) continue;
      final rest = asset.substring(prefix.length);
      if (rest.isEmpty) continue;
      final parts = rest.split('/');
      if (parts.length == 1) {
        final file = parts.first;
        if (file.isNotEmpty && file != '.DS_Store') fileNames.add(file);
      } else {
        final dir = parts.first;
        if (dir.isNotEmpty) dirNames.add(dir);
      }
    }

    final sortedDirs = dirNames.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final sortedFiles = fileNames.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (final d in sortedDirs) {
      result.add(_AssetEntry(name: d, isDir: true, fullPath: '$prefix$d/'));
    }
    for (final f in sortedFiles) {
      result.add(_AssetEntry(name: f, isDir: false, fullPath: '$prefix$f'));
    }

    if (result.isEmpty) {
      result.add(const _AssetEntry(name: 'Sin contenido', isDir: false, fullPath: '', isVirtualNone: true));
    }
    return result;
  }

  void _onChangeAtLevel({required List<_AssetLevel> levels, required int levelIndex, required String? selected, required void Function(String?) assignSelectedFile}) {
    setState(() {
      if (selected == '__none__') {
        levels[levelIndex] = levels[levelIndex].copyWith(selectedPath: null);
        while (levels.length > levelIndex + 1) levels.removeLast();
        assignSelectedFile(null);
        return;
      }
      levels[levelIndex] = levels[levelIndex].copyWith(selectedPath: selected);
      while (levels.length > levelIndex + 1) levels.removeLast();
      assignSelectedFile(null);
      if (selected == null || selected.isEmpty) return;
      final entries = _childrenOfPrefix(levels[levelIndex].prefix);
      final entry = entries.firstWhere((e) => e.fullPath == selected, orElse: () => const _AssetEntry(name: '', isDir: false, fullPath: '', isVirtualNone: true));
      if (entry.isVirtualNone) return;
      if (entry.isDir) {
        levels.add(_AssetLevel(prefix: entry.fullPath));
      } else {
        assignSelectedFile(entry.fullPath);
      }
    });
  }

  List<DropdownMenuItem<String>> _itemsForLevel(String prefix) {
    final entries = _childrenOfPrefix(prefix);
    if (entries.length == 1 && entries.first.isVirtualNone) {
      return [const DropdownMenuItem<String>(value: '__none__', enabled: false, child: Row(children: [Icon(Icons.not_interested), SizedBox(width: 8), Expanded(child: Text('Sin contenido'))]))];
    }
    return entries.map((e) {
      final value = e.isVirtualNone ? '__none__' : e.fullPath;
      return DropdownMenuItem<String>(
        value: value,
        enabled: !e.isVirtualNone,
        child: Row(children: [
          Icon(e.isVirtualNone ? Icons.not_interested : (e.isDir ? Icons.folder_outlined : Icons.insert_drive_file)),
          const SizedBox(width: 8),
          Expanded(child: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false)),
        ]),
      );
    }).toList();
  }

  String _displayForSelected(String? selectedPath, String currentPrefix) {
    if (selectedPath == null || selectedPath.isEmpty || selectedPath == '__none__') return 'Elige una opción…';
    final entries = _childrenOfPrefix(currentPrefix);
    final entry = entries.firstWhere((e) => e.fullPath == selectedPath, orElse: () => _AssetEntry(name: p.basename(selectedPath), isDir: selectedPath.endsWith('/'), fullPath: selectedPath));
    return entry.name;
  }

  bool _canOpen(String? filePath) => (filePath != null && filePath.isNotEmpty && filePath != '__none__');

  Future<void> _openSelectedAsset(String assetPath) async {
    final ext = p.extension(assetPath).toLowerCase();
    final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
    final isPdf = ext == '.pdf';
    if (isImage) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ImageViewerPage(assetPath: assetPath)));
      return;
    }
    if (isPdf) {
      final tmp = await _assetToTempFile(assetPath);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PdfViewerPage(filePath: tmp.path)));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Formato no soportado. Usa PDF o JPG/PNG.')));
  }

  Future<File> _assetToTempFile(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final filename = assetPath.split('/').last;
    final file = File(p.join(dir.path, 'lab_sup_$filename'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
    final compactacionStream = FirebaseFirestore.instance.collection('resultados_analisis_compactacion').snapshots();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Recomendaciones de compactación', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: compactacionStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return _loadingBox();
              if (snap.hasError) return _errorBox('Error al cargar análisis: ${snap.error}');
              final docs = (snap.data?.docs ?? []).where((d) {
                final fecha = (d.data()['fecha'] as Timestamp?)?.toDate();
                return fecha != null && fecha.isAfter(sixMonthsAgo);
              }).toList()..sort((a, b) {
                final fa = (a.data()['fecha'] as Timestamp).toDate();
                final fb = (b.data()['fecha'] as Timestamp).toDate();
                return fb.compareTo(fa);
              });

              if (docs.isEmpty) return _noRecomendacionBox();
              final data = docs.first.data();
              final nombre = (data['nombre'] as String?) ?? 'Análisis de Compactación';
              final fecha = (data['fecha'] as Timestamp?)?.toDate();
              final fechaStr = fecha == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(fecha);
              final url = data['downloadUrl'] as String?;
              final mayor = (data['avg_mayor_importancia'] as num?)?.toDouble();

              if (mayor == null) return _warningBox('El último análisis no contiene "avg_mayor_importancia".');
              final caso = _evaluarCaso(mayor);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _docPreviewCard(title: nombre, subtitle: 'Fecha: $fechaStr', enabled: url != null, onTap: url == null ? null : () => _openByUrl(context, url)),
                  const SizedBox(height: 10),
                  _estadoRectangulo(caso, _textoCaso(caso)),
                  const SizedBox(height: 12),
                  if (caso == _CasoCompactacion.rojo) ..._bloqueRojo(),
                  if (caso == _CasoCompactacion.amarillo) ..._bloqueAmarillo(),
                  if (caso == _CasoCompactacion.verde) ..._bloqueVerde(),
                  const SizedBox(height: 16),
                  Divider(color: Colors.black.withOpacity(0.15)),
                  const SizedBox(height: 8),
                  Text('Laboreo Superficial', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                  const SizedBox(height: 10),
                  _dropdownLaboreoSelector(),
                  const SizedBox(height: 12),
                  if (!_manifestLoaded && _manifestError == null) _loadingBox()
                  else if (_manifestError != null) _errorBox(_manifestError!)
                  else _laboreoBrowser(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.assignment_outlined),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ReporteActividadFormPage(
                        titulo: 'Reporte de Actividad — Laboreo Superficial',
                        subtipo: 'Reporte de Actividad Laboreo Superficial',
                        coleccionDestino: 'reportes_preparacion_suelos',
                      ),
                    )),
                    label: const Text('Reporte de Actividad (Laboreo Superficial)'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Historial de reportes de actividad', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          _repoDropdown(),
          const SizedBox(height: 8),
          _repoList(),
        ],
      ),
    );
  }

  Widget _reporteActividadButton({required String title, required String subtipo, required String coleccion}) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.assignment_outlined),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: BorderSide(color: Colors.black.withOpacity(0.25)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ReporteActividadFormPage(
          titulo: title,
          subtipo: subtipo,
          coleccionDestino: coleccion,
        ),
      )),
      label: const Text('Reporte de Actividad', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  List<Widget> _bloqueRojo() {
    return [_reporteActividadButton(title: 'Reporte de Actividad (Laboreo Profundo)', subtipo: 'Reporte de Actividad Laboreo Profundo', coleccion: 'reportes_preparacion_suelos')];
  }

  List<Widget> _bloqueAmarillo() {
    if (_loadingDecision) return [const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator()))];
    if (_amarilloDecision == _DecisionAmarillo.realizar) {
      return [_reporteActividadButton(title: 'Reporte de Actividad (Laboreo Profundo)', subtipo: 'Reporte de Actividad Laboreo Profundo', coleccion: 'reportes_preparacion_suelos'), const SizedBox(height: 10), _volverSeleccionButton()];
    }
    if (_amarilloDecision == _DecisionAmarillo.no_realizar) {
      return [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.withOpacity(0.35))),
          child: Row(children: [const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text('Selección guardada', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w700)))]),
        ),
        const SizedBox(height: 10),
        _volverSeleccionButton(),
      ];
    }
    return [
      Row(children: [
        Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.playlist_add_check), style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () async { setState(() => _amarilloDecision = _DecisionAmarillo.realizar); await _saveDecision(_DecisionAmarillo.realizar); }, label: const Text('Realizar Actividad', style: TextStyle(fontWeight: FontWeight.w700)))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.block), style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: BorderSide(color: Colors.black.withOpacity(0.25)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () async { setState(() => _amarilloDecision = _DecisionAmarillo.no_realizar); await _saveDecision(_DecisionAmarillo.no_realizar); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se requiere realizar actividad. Selección guardada.'))); }, label: const Text('No Requiere Realizar Actividad', style: TextStyle(fontWeight: FontWeight.w700)))),
      ]),
    ];
  }

  Widget _volverSeleccionButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.undo),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: BorderSide(color: Colors.black.withOpacity(0.25)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      onPressed: () async {
        setState(() => _amarilloDecision = _DecisionAmarillo.none);
        await _saveDecision(_DecisionAmarillo.none);
      },
      label: const Text('Volver a la Selección', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  List<Widget> _bloqueVerde() {
    return [Row(children: [const Icon(Icons.verified, color: Colors.green), const SizedBox(width: 8), Text('Compactación Aceptable', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w700))])];
  }

  Widget _dropdownLaboreoSelector() { return Container(); }
  Widget _laboreoBrowser() { return Container(); }
  Widget _repoDropdown() { return Container(); }
  Widget _repoList() { return Container(); }
  Widget _loadingBox() { return const Center(child: CircularProgressIndicator()); }
  Widget _errorBox(String msg) { return Container(padding: const EdgeInsets.all(12), color: Colors.red.shade100, child: Text(msg)); }
  Widget _warningBox(String msg) { return Container(padding: const EdgeInsets.all(12), color: Colors.amber.shade100, child: Text(msg)); }
  Widget _placeholderCard(String text) { return Container(padding: const EdgeInsets.all(12), child: Text(text)); }
  Widget _noRecomendacionBox() { return Container(padding: const EdgeInsets.all(14), child: const Text('No hay ninguna recomendación emitida.')); }
  Widget _docPreviewCard({required String title, required String subtitle, bool enabled = true, VoidCallback? onTap}) { return ListTile(title: Text(title), subtitle: Text(subtitle), enabled: enabled, onTap: onTap); }
  Widget _estadoRectangulo(_CasoCompactacion caso, String texto) { return Container(padding: const EdgeInsets.all(14), child: Text(texto)); }
  Future<void> _openByUrl(BuildContext context, String url) async { /* ... */ }
}

class _PdfViewerPage extends StatelessWidget {
  final String filePath;
  const _PdfViewerPage({required this.filePath});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(filePath))),
      body: PDFView(filePath: filePath),
    );
  }
}

class _ImageViewerPage extends StatelessWidget {
  final String assetPath;
  const _ImageViewerPage({required this.assetPath});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(assetPath))),
      body: InteractiveViewer(child: Center(child: Image.asset(assetPath))),
    );
  }
}