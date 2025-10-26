import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// --------- BODY reutilizable (sin Scaffold) ----------
class RegistroTerrenosBody extends StatefulWidget {
  const RegistroTerrenosBody({super.key});

  @override
  State<RegistroTerrenosBody> createState() => _RegistroTerrenosBodyState();
}

class _RegistroTerrenosBodyState extends State<RegistroTerrenosBody> {
  static const Color kOrange = Color(0xFFF2AE2E);

  /// ✅ Carpeta base EXACTA (coincide con pubspec.yaml)
  static const String kBasePrefix = 'RecursosdeInformacion/registro_de_terreno/';

  bool _loading = true;
  String? _error;
  late List<String> _assetsUnderBase = [];

  /// Lista mutable (NO const en conjunto)
  final List<_LevelSelection> _levels = [
    const _LevelSelection(prefix: kBasePrefix, selected: null),
  ];

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
      _assetsUnderBase = keys.where((k) => k.startsWith(kBasePrefix)).toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      setState(() {
        _loading = false;
        _error = null;
      });

      if (_assetsUnderBase.isEmpty) {
        setState(() {
          _error =
          'No se encontraron archivos bajo "$kBasePrefix".\n\n'
              'Verifica que:\n'
              '• La carpeta exista con ese nombre EXACTO.\n'
              '• Está listada en pubspec.yaml con el trailing slash.\n'
              '• Ejecutaste flutter clean && flutter pub get.\n'
              '• Reiniciaste la app (no solo hot reload).';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error =
        'No se pudo cargar el índice de assets. Revisa pubspec.yaml y rutas.\n\nDetalle: $e';
      });
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
        final fileName = parts.first;
        if (fileName.isNotEmpty) fileNames.add(fileName);
      } else if (parts.length > 1) {
        final dirName = parts.first;
        if (dirName.isNotEmpty) dirNames.add(dirName);
      }
    }

    final sortedDirs = dirNames.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final d in sortedDirs) {
      result.add(_Entry(name: d, isDir: true, fullPath: '$prefix$d/'));
    }

    final sortedFiles = fileNames.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final f in sortedFiles) {
      result.add(_Entry(name: f, isDir: false, fullPath: '$prefix$f'));
    }

    if (result.isEmpty) {
      result.add(const _Entry(
        name: 'Ninguno',
        isDir: false,
        fullPath: '',
        isVirtualNone: true,
      ));
    }

    return result;
  }

  void _onChangeAtLevel(int levelIndex, _Entry? selected) {
    setState(() {
      _levels[levelIndex] = _levels[levelIndex].copyWith(selected: selected?.name);

      // Recorta niveles siguientes
      while (_levels.length > levelIndex + 1) {
        _levels.removeLast();
      }
      _selectedFilePath = null;

      if (selected == null || selected.isVirtualNone) return;

      if (selected.isDir) {
        _levels.add(_LevelSelection(prefix: selected.fullPath, selected: null));
      } else {
        _selectedFilePath = selected.fullPath;
      }
    });
  }

  /// ⚠️ Corregido: NO usar Flexible/Expanded dentro de DropdownMenuItem.
  ///    Usamos un ancho acotado para el texto + ellipsis.
  List<DropdownMenuItem<_Entry>> _itemsForLevel(int levelIndex) {
    final level = _levels[levelIndex];
    final entries = _childrenOfPrefix(level.prefix);
    // Ancho máximo sugerido del texto del ítem (ajusta si hace falta)
    final double maxTextWidth = 260;

    return entries
        .map((e) => DropdownMenuItem<_Entry>(
      value: e,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            e.isVirtualNone
                ? Icons.not_interested
                : (e.isDir ? Icons.folder_outlined : Icons.insert_drive_file),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: maxTextWidth,
            child: Text(
              e.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    ))
        .toList();
  }

  _Entry? _currentEntryForLevel(int levelIndex) {
    final level = _levels[levelIndex];
    if (level.selected == null) return null;
    final entries = _childrenOfPrefix(level.prefix);
    try {
      return entries.firstWhere((e) => e.name == level.selected);
    } catch (_) {
      return null;
    }
  }

  bool get _canOpen => (_selectedFilePath != null && _selectedFilePath!.isNotEmpty);

  Future<void> _openSelected(BuildContext context) async {
    if (!_canOpen) return;

    final ext = p.extension(_selectedFilePath!).toLowerCase();
    final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
    final isPdf = ext == '.pdf';

    if (isImage) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ImageViewerPage(assetPath: _selectedFilePath!),
        ),
      );
      return;
    }

    if (isPdf) {
      final tmp = await _assetToTempFile(_selectedFilePath!); // copiar a /tmp
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PdfViewerPage(filePath: tmp.path),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Formato no soportado. Usa PDF o JPG/PNG.')),
    );
  }

  Future<File> _assetToTempFile(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final filename = assetPath.split('/').last;
    final file = File(p.join(dir.path, 'reg_terr_$filename'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
            textAlign: TextAlign.left,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Cabecera
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: kOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kOrange.withOpacity(0.35)),
            ),
            child: Text(
              'Registro de Terrenos agrícolas',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          // Dropdowns encadenados
          Expanded(
            child: ListView.separated(
              itemCount: _levels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final currentValue = _currentEntryForLevel(index);
                final entries = _itemsForLevel(index);
                final isFirst = index == 0;

                return _DropdownCard<_Entry>(
                  label: isFirst
                      ? 'Seleccionar Equipo / Carpeta / Archivo'
                      : 'Nivel ${index + 1}',
                  hint: 'Elige una opción…',
                  value: currentValue,
                  items: entries,
                  onChanged: (val) => _onChangeAtLevel(index, val),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // Abrir
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
              label: Text(
                _canOpen
                    ? 'Abrir "${p.basename(_selectedFilePath!)}"'
                    : 'Selecciona un archivo para abrir',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----- Widgets auxiliares -----

class _DropdownCard<T> extends StatelessWidget {
  final String label;
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  const _DropdownCard({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    this.onChanged,
    this.enabled = true,
  });

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: kOrange.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 6),
            DropdownButtonFormField<T>(
              value: value,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: Colors.white.withOpacity(0.72),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
  const _ImageViewerPage({super.key, required this.assetPath});

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
  final String filePath; // ← ABRIMOS DESDE ARCHIVO TEMPORAL
  const _PdfViewerPage({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(filePath)),
        backgroundColor: const Color(0xFFF2AE2E),
        foregroundColor: Colors.black,
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: true,
        pageFling: true,
      ),
    );
  }
}

/// ----- Modelos internos -----
class _LevelSelection {
  final String prefix;
  final String? selected;

  const _LevelSelection({required this.prefix, required this.selected});

  _LevelSelection copyWith({String? prefix, String? selected}) =>
      _LevelSelection(prefix: prefix ?? this.prefix, selected: selected ?? this.selected);
}

class _Entry {
  final String name;
  final bool isDir;
  final String fullPath;
  final bool isVirtualNone;

  const _Entry({
    required this.name,
    required this.isDir,
    required this.fullPath,
    this.isVirtualNone = false,
  });
}