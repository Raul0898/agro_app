import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> openRepoPdf(BuildContext context, String url, {String? title}) async {
  try {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw 'HTTP ${resp.statusCode} al descargar el archivo';
    }
    final bytes = resp.bodyBytes;
    if (bytes.isEmpty) {
      throw 'El archivo descargado está vacío (0 bytes).';
    }
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw 'El archivo no es un PDF válido (no inicia con %PDF-).';
    }
    final tmpDir = await getTemporaryDirectory();
    final file = File(
      p.join(tmpDir.path, 'repo_${DateTime.now().millisecondsSinceEpoch}.pdf'),
    );
    await file.writeAsBytes(bytes, flush: true);
    // ignore: use_build_context_synchronously
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepoPdfViewerPage(filePath: file.path, title: title),
      ),
    );
  } catch (e) {
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo abrir el PDF: $e')),
    );
  }
}

Future<void> downloadRepoFile(
  BuildContext context,
  String url, {
  required String suggestedName,
}) async {
  try {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw 'HTTP ${resp.statusCode}';
    }
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(docsDir.path, '$suggestedName.pdf'));
    await file.writeAsBytes(resp.bodyBytes, flush: true);
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Descargado en: ${file.path}')),
    );
  } catch (e) {
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo descargar: $e')),
    );
  }
}

String sanitizeRepoFileName(String input) {
  final s = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_\-\. ]+'), '')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll('__', '_');
  return s.isEmpty ? 'reporte' : s;
}

class RepoPdfViewerPage extends StatelessWidget {
  final String filePath;
  final String? title;

  const RepoPdfViewerPage({super.key, required this.filePath, this.title});

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = (title != null && title!.trim().isNotEmpty)
        ? title!.trim()
        : p.basename(filePath);
    return Scaffold(
      appBar: AppBar(
        title: Text(resolvedTitle),
        backgroundColor: const Color(0xFFF2AE2E),
        foregroundColor: Colors.black,
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        autoSpacing: true,
        pageFling: true,
        onError: (error) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al renderizar PDF: $error')),
        ),
        onPageError: (page, error) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en página $page: $error')),
        ),
        onRender: (pages) {
          if (pages == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('El PDF no tiene páginas para mostrar.')),
            );
          }
        },
      ),
    );
  }
}
