// lib/features/auth/ui/pages/registro_terrenos_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:agro_app/features/auth/ui/pages/reporte_actividad_form_page.dart';

class RegistroTerrenosBody extends StatefulWidget {
  const RegistroTerrenosBody({super.key});

  @override
  State<RegistroTerrenosBody> createState() => _RegistroTerrenosBodyState();
}

enum _RegistroMode { none, nuevo, existente }

class _RegistroTerrenosBodyState extends State<RegistroTerrenosBody> {
  static const Color kOrange = Color(0xFFF2AE2E);
  static const String kBasePrefix = 'RecursosdeInformacion/registro_de_terreno/';
  bool _loading = true;
  String? _error;
  late List<String> _assetsUnderBase = [];
  _RegistroMode _mode = _RegistroMode.none;
  final List<_LevelSelection> _levels = [const _LevelSelection(prefix: kBasePrefix, selectedPath: null)];
  String? _selectedFilePath;

  @override
  void initState() {
    super.initState();
    _loadManifest();
  }

  Future<void> _loadManifest() async {
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestJson);
      final keys = manifest.keys.cast<String>().toList();
      _assetsUnderBase = keys.where((k) => k.startsWith(kBasePrefix)).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo cargar el índice de assets: $e');
    }
  }

  List<_Entry> _childrenOfPrefix(String prefix) {
    final List<_Entry> result = [];
    final Set<String> dirNames = {};
    final Set<String> fileNames = {};
    for (final asset in _assetsUnderBase) {
      if (!asset.startsWith(prefix)) continue;
      final remainder = asset.substring(prefix.length);
      if (remainder.isEmpty) continue;
      final parts = remainder.split('/');
      if (parts.length == 1) {
        if (parts.first.isNotEmpty) fileNames.add(parts.first);
      } else {
        if (parts.first.isNotEmpty) dirNames.add(parts.first);
      }
    }
    dirNames.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))..forEach((d) => result.add(_Entry(name: d, isDir: true, fullPath: '$prefix$d/')));
    fileNames.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))..forEach((f) => result.add(_Entry(name: f, isDir: false, fullPath: '$prefix$f')));
    if (result.isEmpty) result.add(const _Entry(name: 'Sin contenido', isDir: false, fullPath: '', isVirtualNone: true));
    return result;
  }

  void _onChangeAtLevel(int levelIndex, String? selectedPath) {
    setState(() {
      _levels[levelIndex] = _levels[levelIndex].copyWith(selectedPath: selectedPath);
      while (_levels.length > levelIndex + 1) {
        _levels.removeLast();
      }
      _selectedFilePath = null;
      if (selectedPath == null || selectedPath.isEmpty) return;
      final entries = _childrenOfPrefix(_levels[levelIndex].prefix);
      final entry = entries.firstWhere((e) => e.fullPath == selectedPath, orElse: () => const _Entry(name: '', isDir: false, fullPath: '', isVirtualNone: true));
      if (entry.isDir) {
        _levels.add(_LevelSelection(prefix: entry.fullPath, selectedPath: null));
      } else {
        _selectedFilePath = entry.fullPath;
      }
    });
  }

  List<DropdownMenuItem<String>> _itemsForLevel(int levelIndex) {
    final level = _levels[levelIndex];
    final entries = _childrenOfPrefix(level.prefix);
    return entries.map((e) {
      return DropdownMenuItem<String>(
        value: e.isVirtualNone ? '' : e.fullPath,
        child: Row(children: [
          Icon(e.isDir ? Icons.folder_outlined : Icons.insert_drive_file),
          const SizedBox(width: 8),
          Expanded(child: Text(e.name, overflow: TextOverflow.ellipsis)),
        ]),
      );
    }).toList();
  }

  String _displayTextForSelected(int levelIndex) {
    final level = _levels[levelIndex];
    if (level.selectedPath == null || level.selectedPath!.isEmpty) return 'Elige una opción…';
    return p.basename(level.selectedPath!.endsWith('/') ? level.selectedPath!.substring(0, level.selectedPath!.length - 1) : level.selectedPath!);
  }

  bool get _canOpen => (_selectedFilePath != null && _selectedFilePath!.isNotEmpty);

  Future<void> _openSelected(BuildContext context) async {
    if (!_canOpen) return;
    final ext = p.extension(_selectedFilePath!).toLowerCase();
    if (ext == '.pdf') {
      final tmp = await _assetToTempFile(_selectedFilePath!);
      if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PdfViewerPage(filePath: tmp.path)));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Formato no soportado.')));
    }
  }

  Future<File> _assetToTempFile(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final filename = p.basename(assetPath);
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red))),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_mode == _RegistroMode.none) _selectorInicial(),
          if (_mode == _RegistroMode.nuevo) _nuevoTerrenoUI(context),
          if (_mode == _RegistroMode.existente) _terrenoExistenteUI(context),
        ],
      ),
    );
  }

  Widget _selectorInicial() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => setState(() => _mode = _RegistroMode.nuevo),
            label: const Text('Nuevo Terreno', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.inventory_2_outlined),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: BorderSide(color: Colors.black.withOpacity(0.25)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => setState(() => _mode = _RegistroMode.existente),
            label: const Text('Terreno en Existencia', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _nuevoTerrenoUI(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text('Alta de nuevo terreno', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _selectorDeCarpetasYArchivos(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.assignment_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReporteActividadFormPage(
                  titulo: 'Reporte de Actividad — Registro de Terreno',
                  subtipo: 'Reporte de Actividad Terreno',
                  coleccionDestino: 'reportes_registro_terrenos',
                ),
              ),
            );
          },
          label: const Text('Reporte de Actividad'),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          icon: const Icon(Icons.undo),
          onPressed: () => setState(() => _mode = _RegistroMode.none),
          label: const Text('Revertir Acción'),
        ),
      ],
    );
  }

  Widget _terrenoExistenteUI(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _successCard(),
        const SizedBox(height: 10),
        TextButton.icon(
          icon: const Icon(Icons.undo),
          onPressed: () => setState(() => _mode = _RegistroMode.none),
          label: const Text('Revertir Acción'),
        ),
      ],
    );
  }

  Widget _selectorDeCarpetasYArchivos() {
    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _levels.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final items = _itemsForLevel(index);
            final value = _levels[index].selectedPath;
            return _DropdownCard<String>(
              label: index == 0 ? 'Seleccionar carpeta/archivo' : 'Nivel ${index + 1}',
              hint: _displayTextForSelected(index),
              value: value == null || value.isEmpty ? null : value,
              items: items,
              onChanged: (val) => _onChangeAtLevel(index, val),
            );
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.open_in_full),
            style: ElevatedButton.styleFrom(
              backgroundColor: kOrange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _canOpen ? () => _openSelected(context) : null,
            label: Text(_canOpen ? 'Abrir "${p.basename(_selectedFilePath!)}"' : 'Selecciona un archivo para abrir', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _successCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.35))),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Text('Actividad Realizada', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _DropdownCard<T> extends StatelessWidget {
  final String label;
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  const _DropdownCard({required this.label, required this.hint, required this.value, required this.items, this.onChanged, this.enabled = true});

  static const Color kOrange = Color(0xFFF2AE2E);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
          border: Border.all(color: kOrange.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelLarge?.copyWith(color: Colors.black87, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            DropdownButtonFormField<T>(
              initialValue: value,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: Colors.white.withOpacity(0.72),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
              icon: const Icon(Icons.arrow_drop_down),
              items: items,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageViewerPage extends StatelessWidget {
  final String assetPath;
  const _ImageViewerPage({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(p.basename(assetPath)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.asset(assetPath, fit: BoxFit.contain, width: double.infinity),
        ),
      ),
    );
  }
}

class _PdfViewerPage extends StatelessWidget {
  final String filePath;
  const _PdfViewerPage({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(filePath)),
        backgroundColor: const Color(0xFFF2AE2E),
        foregroundColor: Colors.black,
      ),
      body: PDFView(filePath: filePath),
    );
  }
}

class _LevelSelection {
  final String prefix;
  final String? selectedPath;
  const _LevelSelection({required this.prefix, required this.selectedPath});
  _LevelSelection copyWith({String? prefix, String? selectedPath}) => _LevelSelection(prefix: prefix ?? this.prefix, selectedPath: selectedPath ?? this.selectedPath);
}

class _Entry {
  final String name;
  final bool isDir;
  final String fullPath;
  final bool isVirtualNone;
  const _Entry({required this.name, required this.isDir, required this.fullPath, this.isVirtualNone = false});
}