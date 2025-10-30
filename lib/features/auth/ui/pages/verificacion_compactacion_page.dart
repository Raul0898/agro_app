// lib/features/auth/ui/pages/verificacion_compactacion_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// PDF / Storage
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart' show rootBundle;

// Visor PDF (reutilizamos el que ya tienes en otras pantallas)
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:agro_app/widgets/upload_overlay.dart';

class VerificacionCompactacionPage extends StatefulWidget {
  const VerificacionCompactacionPage({super.key});

  @override
  State<VerificacionCompactacionPage> createState() => _VerificacionCompactacionPageState();
}

enum _ResultadoColor { verde, amarillo, rojo }

class _VerificacionCompactacionPageState extends State<VerificacionCompactacionPage> {
  static const kOrange = Color(0xFFF2AE2E);

  // Profundidades (15 filas). La "Media" sólo se muestra abajo, no tiene input.
  final List<String> _profundidades = const [
    '3', '5', '8', '10', '13', '15', '18', '20', '23', '25', '28', '30', '33', '36', '38'
  ];

  // 15 controladores de entrada
  late final List<TextEditingController> _psiCtrls;

  // Estado de captura/resultado (pantalla)
  bool _puedeCapturar = true;          // si es false => muestra resultado + “Renovar”
  double? _mediaVerificada;            // media del último registro cargado
  _ResultadoColor? _colorVerificado;   // color del último registro cargado
  DateTime? _fechaVerificada;          // fecha del último registro cargado

  // Media dinámica mientras el usuario escribe
  double? _mediaEnEdicion;

  // Firestore
  final _uiStateRef = FirebaseFirestore.instance.collection('ui_state');
  final _verifRef = FirebaseFirestore.instance.collection('verificaciones_compactacion');
  final _pdfRef = FirebaseFirestore.instance.collection('verificacion_compactacion_pdfs');

  // Validación: máx 3 enteros y decimales opcionales (300.2, 300, 50)
  final RegExp _reNum = RegExp(r'^\d{1,3}(\.\d+)?$');

  // --- Repositorio PDF UI ---
  String? _selectedPdfId; // doc id seleccionado en el dropdown

  @override
  void initState() {
    super.initState();
    _psiCtrls = List.generate(15, (_) => TextEditingController());
    for (final c in _psiCtrls) {
      c.addListener(_recalcMediaEnEdicion);
    }
    _cargarEstadoInicial();
  }

  @override
  void dispose() {
    for (final c in _psiCtrls) {
      c.removeListener(_recalcMediaEnEdicion);
      c.dispose();
    }
    super.dispose();
  }

  // ======== CARGA INICIAL (persistencia de vista) ========
  Future<void> _cargarEstadoInicial() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // 1) Leer UI flag
      final uiDoc = await _uiStateRef.doc('verificacion_compactacion').collection('users').doc(uid).get();
      bool canEdit = (uiDoc.data()?['canEdit'] as bool?) ?? true;

      // 2) Traer SIEMPRE la última verificación (para “failsafe” visual)
      final last = await _verifRef
          .where('uid', isEqualTo: uid)
          .orderBy('fecha', descending: true)
          .limit(1)
          .get();

      if (last.docs.isNotEmpty) {
        final d = last.docs.first.data();
        final media = (d['media'] as num?)?.toDouble();
        final color = _parseResultado(d['resultado'] as String?);
        final fecha = (d['fecha'] as Timestamp?)?.toDate();

        // Si hay una verificación reciente pero canEdit == true (inconsistencia),
        // mostramos el último resultado y bloqueamos captura hasta “Renovar”.
        if (canEdit == true) {
          canEdit = false;
        }

        setState(() {
          _puedeCapturar   = canEdit;
          _mediaVerificada = media;
          _colorVerificado = color;
          _fechaVerificada = fecha;
        });
        return;
      }

      // Si no hay historial
      setState(() {
        _puedeCapturar = canEdit;
      });
    } catch (_) {
      setState(() {
        _puedeCapturar = true;
      });
    }
  }

  // ======== Reglas de resultado ========
  _ResultadoColor _evaluarColor(double media) {
    if (media >= 201) return _ResultadoColor.rojo;
    if (media >= 101) return _ResultadoColor.amarillo;
    return _ResultadoColor.verde;
  }

  _ResultadoColor? _parseResultado(String? s) {
    switch (s) {
      case 'verde': return _ResultadoColor.verde;
      case 'amarillo': return _ResultadoColor.amarillo;
      case 'rojo': return _ResultadoColor.rojo;
    }
    return null;
  }

  String _resultadoTexto(_ResultadoColor c) {
    switch (c) {
      case _ResultadoColor.verde: return 'APROBADO';
      case _ResultadoColor.amarillo: return 'APROBADO EN CONDICIONES LIMITADA';
      case _ResultadoColor.rojo: return 'NO APROBADO';
    }
  }

  String? _resultadoRecomendacion(_ResultadoColor c) =>
      c == _ResultadoColor.rojo ? 'Recomendación: Volver a realizar Laboreo Superficial.' : null;

  Color _colorBg(_ResultadoColor c) {
    switch (c) {
      case _ResultadoColor.verde: return Colors.green.withOpacity(0.12);
      case _ResultadoColor.amarillo: return Colors.yellow.shade700.withOpacity(0.12);
      case _ResultadoColor.rojo: return Colors.red.withOpacity(0.12);
    }
  }

  Color _colorBorde(_ResultadoColor c) {
    switch (c) {
      case _ResultadoColor.verde: return Colors.green.withOpacity(0.45);
      case _ResultadoColor.amarillo: return Colors.yellow.shade700.withOpacity(0.5);
      case _ResultadoColor.rojo: return Colors.red.withOpacity(0.45);
    }
  }

  IconData _icono(_ResultadoColor c) {
    switch (c) {
      case _ResultadoColor.verde: return Icons.check_circle;
      case _ResultadoColor.amarillo: return Icons.warning_amber_rounded;
      case _ResultadoColor.rojo: return Icons.report_gmailerrorred;
    }
  }

  // ======== Validación y helpers numéricos ========
  String? _validatePsi(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Requerido';
    if (!_reNum.hasMatch(s)) return 'Máx 3 dígitos. Ej: 300 o 300.2';
    return null;
  }

  double? _tryParse(String s) {
    try { return double.parse(s); } catch (_) { return null; }
  }

  // ======== Media en vivo ========
  void _recalcMediaEnEdicion() {
    final vals = <double>[];
    for (final c in _psiCtrls) {
      final s = c.text.trim();
      if (s.isEmpty) continue;
      if (!_reNum.hasMatch(s)) continue;
      final v = _tryParse(s);
      if (v != null) vals.add(v);
    }
    setState(() {
      _mediaEnEdicion = vals.isEmpty ? null : (vals.reduce((a, b) => a + b) / vals.length);
    });
  }

  // ======== Acciones ========
  Future<void> _onVerificar() async {
    // Validar las 15 celdas
    final values = <double>[];
    for (final c in _psiCtrls) {
      final s = c.text.trim();
      final err = _validatePsi(s);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verifica todas las lecturas: $err')),
        );
        return;
      }
      final v = _tryParse(s);
      if (v == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lectura inválida.')),
        );
        return;
      }
      values.add(v);
    }
    if (values.isEmpty) return;

    // *** Exigir autenticación ***
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para guardar la verificación.')),
      );
      return;
    }

    final media = values.reduce((a, b) => a + b) / values.length;
    final color = _evaluarColor(media);
    final now = DateTime.now();

    try {
      // 1) Guardar verificación en Firestore
      final verifDoc = await _verifRef.add({
        'uid': uid,
        'fecha': Timestamp.fromDate(now),
        'media': media,
        'resultado': color.name,
        'lecturas': values,
      });

      // 2) Bloquear captura hasta “Renovar”
      await _uiStateRef
          .doc('verificacion_compactacion')
          .collection('users')
          .doc(uid)
          .set(
        {'canEdit': false, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      // 3) Generar y subir PDF + registrar en colección de PDFs
      final pdfUrl = await _generateAndUploadPdf(
        uid: uid,
        fecha: now,
        media: media,
        color: color,
        lecturas: values,
      );

      if (pdfUrl != null) {
        await _pdfRef.add({
          'uid': uid,
          'fecha': Timestamp.fromDate(now),
          'nombre': 'Verificación de Compactación ${DateFormat('yyyy-MM-dd HHmm').format(now)}.pdf',
          'downloadUrl': pdfUrl,
          'verificacionId': verifDoc.id, // útil para trazabilidad
        });
      }

      // 4) Limpiar inputs y mostrar resultado bloqueado SOLO ahora que sí guardó
      for (final c in _psiCtrls) {
        c.clear();
      }
      setState(() {
        _mediaVerificada = media;
        _colorVerificado = color;
        _fechaVerificada = now;
        _puedeCapturar = false;
        _mediaEnEdicion = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verificación guardada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar verificación: $e')),
        );
      }
    }
  }

  Future<void> _onRenovar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      if (uid != null) {
        await _uiStateRef
            .doc('verificacion_compactacion')
            .collection('users')
            .doc(uid)
            .set(
          {'canEdit': true, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }
      setState(() {
        _puedeCapturar = true;
        _mediaVerificada = null;
        _colorVerificado = null;
        _fechaVerificada = null;
        _mediaEnEdicion = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al renovar: $e')),
        );
      }
    }
  }

  // ======== UI ========
  @override
  Widget build(BuildContext context) {
    final twelveMonthsAgo = DateTime.now().subtract(const Duration(days: 365));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Verificación de Compactación',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
          const SizedBox(height: 12),

          // Si hay resultado vigente o se permite captura
          if (_puedeCapturar) ...[
            _tablaLecturas(),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.done_all),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                onPressed: _onVerificar,
                label: const Text('Verificar', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ] else ...[
            if (_colorVerificado != null && _mediaVerificada != null)
              _bloqueResultado(_colorVerificado!, _mediaVerificada!, _fechaVerificada),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.black.withOpacity(0.25)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _onRenovar,
              label: const Text('Renovar Verificación', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],

          const SizedBox(height: 18),
          // ---------- Repositorio de PDFs ----------
          Text('Repositorio de PDFs (últimos 12 meses)',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          _repoPdfDropdown(twelveMonthsAgo),
          const SizedBox(height: 8),
          _repoPdfPreviewCard(),

          const SizedBox(height: 18),
          // ---------- Historial (muestra bloques de resultado) ----------
          Text('Historial (últimos 12 meses)',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
          const SizedBox(height: 8),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _historialStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return _loadingBox();
              if (snap.hasError) return _errorBox('Error al cargar historial: ${snap.error}');

              var docs = snap.data?.docs ?? [];

              // Filtrar últimos 12 meses y ordenar
              final twelveAgo = twelveMonthsAgo;
              docs = docs.where((d) {
                final f = (d.data()['fecha'] as Timestamp?)?.toDate() ?? DateTime(1970);
                return f.isAfter(twelveAgo);
              }).toList()
                ..sort((a, b) {
                  final fa = (a.data()['fecha'] as Timestamp?)?.toDate() ?? DateTime(1970);
                  final fb = (b.data()['fecha'] as Timestamp?)?.toDate() ?? DateTime(1970);
                  return fb.compareTo(fa);
                });

              if (docs.isEmpty) {
                return _placeholderCard('Sin verificaciones dentro de los últimos 12 meses.');
              }

              return Column(
                children: List.generate(docs.length, (i) {
                  final docSnap = docs[i];
                  final d = docSnap.data();
                  final f = (d['fecha'] as Timestamp?)?.toDate();
                  final media = (d['media'] as num?)?.toDouble() ?? 0.0;
                  final res = _parseResultado(d['resultado'] as String?);

                  return Container(
                    margin: EdgeInsets.only(bottom: i == docs.length - 1 ? 0 : 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (res != null)
                          _bloqueResultado(res, media, f),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Eliminar verificación',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Eliminar verificación'),
                                  content: const Text('¿Seguro que deseas eliminar esta verificación?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await docSnap.reference.delete();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Verificación eliminada')),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------- Streams ----------
  Stream<QuerySnapshot<Map<String, dynamic>>> _historialStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _verifRef
        .where('uid', isEqualTo: uid)
        .orderBy('fecha', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _repoPdfStream(DateTime from) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    // Traemos todos, filtramos últimos 12 meses en memoria (evita índice compuesto)
    return _pdfRef
        .where('uid', isEqualTo: uid)
        .orderBy('fecha', descending: true)
        .snapshots();
  }

  // ---------- Repositorio PDF UI ----------
  Widget _repoPdfDropdown(DateTime twelveMonthsAgo) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _repoPdfStream(twelveMonthsAgo),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return _loadingBox();
        if (snap.hasError) return _errorBox('Error al cargar PDFs: ${snap.error}');

        var docs = snap.data?.docs ?? [];

        // Filtrar últimos 12 meses en memoria
        docs = docs.where((d) {
          final f = (d.data()['fecha'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return f.isAfter(twelveMonthsAgo);
        }).toList()
          ..sort((a, b) {
            final fa = (a.data()['fecha'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final fb = (b.data()['fecha'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return fb.compareTo(fa);
          });

        if (docs.isEmpty) {
          return _placeholderCard('No hay PDFs generados en los últimos 12 meses.');
        }

        // Asegurar que el seleccionado siga existiendo
        if (_selectedPdfId != null && !docs.any((d) => d.id == _selectedPdfId)) {
          _selectedPdfId = null;
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedPdfId,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.picture_as_pdf),
            hintText: 'Selecciona un PDF…',
            filled: true,
            fillColor: Colors.white.withOpacity(0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: kOrange.withOpacity(0.35)),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          ),
          items: docs.map((d) {
            final data = d.data();
            final nombre = (data['nombre'] as String?) ?? 'Verificación.pdf';
            final f = (data['fecha'] as Timestamp?)?.toDate();
            final fechaStr = f == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(f);
            return DropdownMenuItem<String>(
              value: d.id,
              child: Text('$nombre  —  $fechaStr', maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedPdfId = val),
        );
      },
    );
  }

  Widget _repoPdfPreviewCard() {
    if (_selectedPdfId == null) {
      return _placeholderCard('Selecciona un PDF para previsualizar/abrir o eliminar.');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _pdfRef.doc(_selectedPdfId!).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return _loadingBox();
        if (snap.hasError) return _errorBox('Error al leer PDF: ${snap.error}');
        if (!snap.hasData || !snap.data!.exists) {
          return _placeholderCard('PDF no disponible.');
        }

        final data = snap.data!.data()!;
        final nombre = (data['nombre'] as String?) ?? 'Verificación.pdf';
        final url = data['downloadUrl'] as String?;
        final f = (data['fecha'] as Timestamp?)?.toDate();
        final fechaStr = f == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(f);

        return Material(
          color: Colors.white,
          elevation: 1.5,
          borderRadius: BorderRadius.circular(10),
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
                  child: const Icon(Icons.picture_as_pdf, size: 32, color: Colors.black87),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$nombre\n$fechaStr',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Abrir',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: url == null ? null : () => _openByUrl(context, url),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar PDF'),
                        content: const Text('¿Seguro que deseas eliminar este PDF?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      // También intentamos borrar del Storage usando la URL
                      try {
                        if (url != null) {
                          final ref = FirebaseStorage.instance.refFromURL(url);
                          await ref.delete();
                        }
                      } catch (_) {}
                      await _pdfRef.doc(_selectedPdfId!).delete();
                      if (!mounted) return;
                      setState(() => _selectedPdfId = null);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PDF eliminado')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================== Tabla ==================
  Widget _tablaLecturas() {
    final headerStyle = TextStyle(fontWeight: FontWeight.w800, color: Colors.grey.shade900);
    final border = TableBorder.symmetric(
      inside: BorderSide(color: Colors.black.withOpacity(0.08)),
      outside: BorderSide(color: Colors.black.withOpacity(0.12)),
    );

    final rows = <TableRow>[];

    // Encabezados
    rows.add(
      TableRow(
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9)),
        children: [
          _cellHeader('Profundidad (cm)', headerStyle),
          _cellHeader('Compactación (PSI)', headerStyle),
        ],
      ),
    );

    // 15 filas de entrada
    for (int i = 0; i < _profundidades.length; i++) {
      final prof = _profundidades[i];
      rows.add(
        TableRow(
          decoration: BoxDecoration(color: i.isEven ? Colors.white : Colors.white.withOpacity(0.96)),
          children: [
            _cellText(prof),
            _cellInput(_psiCtrls[i]),
          ],
        ),
      );
    }

    // Fila final: MEDIA — sólo visual
    final mediaDisplay = _puedeCapturar
        ? (_mediaEnEdicion == null ? '—' : '${_mediaEnEdicion!.toStringAsFixed(2)} PSI')
        : (_mediaVerificada == null ? '—' : '${_mediaVerificada!.toStringAsFixed(2)} PSI');

    rows.add(
      TableRow(
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.96)),
        children: [
          _cellText('Media', isBold: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                mediaDisplay,
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800),
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.white,
      elevation: 1.5,
      borderRadius: BorderRadius.circular(10),
      child: Table(
        border: border,
        columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    );
  }

  Widget _cellHeader(String text, TextStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Text(text, style: style),
    );
  }

  Widget _cellText(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _cellInput(TextEditingController c) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'PSI',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: const BorderSide(color: kOrange, width: 1.2)),
        ),
        onChanged: (_) => _recalcMediaEnEdicion(),
      ),
    );
  }

  // ================== Bloques auxiliares ==================
  Widget _bloqueResultado(_ResultadoColor color, double media, DateTime? fecha) {
    final fechaStr = fecha == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(fecha);
    final recomend = _resultadoRecomendacion(color);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _colorBg(color),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _colorBorde(color)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icono(color), color: _colorBorde(color), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _resultadoTexto(color),
                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Media: ${media.toStringAsFixed(2)} PSI',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
          if (fechaStr.isNotEmpty)
            Text('Fecha: $fechaStr', style: TextStyle(color: Colors.grey.shade700)),
          if (recomend != null) ...[
            const SizedBox(height: 6),
            Text(recomend, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _loadingBox() {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: const CircularProgressIndicator(),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Text(msg, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _placeholderCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Text(text, style: TextStyle(color: Colors.grey.shade800)),
    );
  }

  // ================== PDF Helpers ==================
  Future<String?> _generateAndUploadPdf({
    required String uid,
    required DateTime fecha,
    required double media,
    required _ResultadoColor color,
    required List<double> lecturas,
  }) async {
    // --- Paleta PDF (sin opacidad, tonos claros para relleno y fuertes para borde)
    PdfColor resultFill;
    PdfColor resultStroke;
    switch (color) {
      case _ResultadoColor.verde:
        resultFill   = PdfColor.fromInt(0xC8E6C9); // Green 100
        resultStroke = PdfColor.fromInt(0x2E7D32); // Green 800
        break;
      case _ResultadoColor.amarillo:
        resultFill   = PdfColor.fromInt(0xFFF8E1); // Amber 100
        resultStroke = PdfColor.fromInt(0xF9A825); // Amber 700
        break;
      case _ResultadoColor.rojo:
        resultFill   = PdfColor.fromInt(0xFFCDD2); // Red 100
        resultStroke = PdfColor.fromInt(0xC62828); // Red 800
        break;
    }

    final doc = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(fecha);

    // Cargar logo desde assets (ajusta si tu ruta es distinta)
    Uint8List? logoBytes;
    try {
      logoBytes = (await rootBundle.load('IMG/Logo1.png')).buffer.asUint8List();
    } catch (_) {
      logoBytes = null;
    }

    // Tabla de lecturas (Profundidad, PSI)
    final tableRows = <List<String>>[];
    for (int i = 0; i < _profundidades.length; i++) {
      tableRows.add([_profundidades[i], i < lecturas.length ? lecturas[i].toStringAsFixed(2) : '']);
    }

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoBytes != null)
                pw.Container(
                  width: 64,
                  height: 64,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(pw.MemoryImage(logoBytes)),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Verificación de Compactación',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('Fecha: $dateStr',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Resultado destacado
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: resultFill,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: resultStroke, width: 1),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 8,
                  height: 40,
                  color: resultStroke,
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _resultadoTexto(color),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: resultStroke,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Media: ${media.toStringAsFixed(2)} PSI',
                          style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // Tabla de lecturas
          pw.Table.fromTextArray(
            headers: const ['Profundidad (cm)', 'Compactación (PSI)'],
            data: tableRows,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 11),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            border: null,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),

          pw.SizedBox(height: 10),

          // Recomendación (si aplica)
          if (_resultadoRecomendacion(color) != null)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: resultFill,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: resultStroke, width: 1),
              ),
              child: pw.Text(
                _resultadoRecomendacion(color)!,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: resultStroke,
                ),
              ),
            ),
        ],
      ),
    );

    final bytes = await doc.save();

    try {
      final storage = FirebaseStorage.instance;
      final fileName = 'verificacion_${uid}_${DateFormat('yyyyMMdd_HHmmss').format(fecha)}.pdf';
      final ref = storage.ref().child('verificaciones_compactacion').child(uid).child(fileName);
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'application/pdf'),
      );
      showUploadOverlayForTask(
        context,
        uploadTask,
        label: 'Subiendo reporte…',
      );
      await uploadTask;
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      return null;
    }
  }

  // ================== Abrir PDF por URL ==================
  Future<void> _openByUrl(BuildContext context, String url) async {
    try {
      final tmp = await getTemporaryDirectory();
      final file = File(p.join(tmp.path, 'verif_${DateTime.now().millisecondsSinceEpoch}.pdf'));
      final resp = await http.get(Uri.parse(url));
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _PdfViewerPage(filePath: file.path)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el PDF: $e')),
      );
    }
  }
}

// --------------------------- Visor PDF simple ----------------------------
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