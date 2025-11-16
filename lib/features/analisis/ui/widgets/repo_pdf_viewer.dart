import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:agro_app/widgets/transfer_progress_overlay.dart';

Future<Uint8List> _downloadBytesWithOverlay(
  BuildContext context,
  String url, {
  required String label,
}) async {
  final controller = TransferProgressController();
  final client = http.Client();

  try {
    controller.updateProgress(0, label: label);
    controller.show(context, label: label);

    final response = await client.send(http.Request('GET', Uri.parse(url)));
    if (response.statusCode != 200) {
      throw 'HTTP ${response.statusCode}';
    }

    final total = response.contentLength ?? 0;
    final buffer = BytesBuilder(copy: false);
    var received = 0;

    await for (final chunk in response.stream) {
      buffer.add(chunk);
      received += chunk.length;

      if (total > 0) {
        controller.updateProgress((received / total).clamp(0.0, 1.0), label: label);
      } else {
        final approx = (1 - (1 / (1 + received / 500000))).clamp(0.0, 0.95);
        controller.updateProgress(approx, label: label);
      }
    }

    controller.updateProgress(1.0, label: label);
    return buffer.takeBytes();
  } finally {
    controller.hide();
    controller.dispose();
    client.close();
  }
}

Future<void> openRepoPdf(BuildContext context, String url, {String? title}) async {
  try {
    final bytes = await _downloadBytesWithOverlay(
      context,
      url,
      label: 'Descargando PDF…',
    );
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
    final bytes = await _downloadBytesWithOverlay(
      context,
      url,
      label: 'Descargando archivo…',
    );
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(docsDir.path, '$suggestedName.pdf'));
    await file.writeAsBytes(bytes, flush: true);
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
