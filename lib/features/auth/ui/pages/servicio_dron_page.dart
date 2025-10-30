import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:agro_app/widgets/upload_overlay.dart';

class ServicioDronPage extends StatefulWidget {
  const ServicioDronPage({super.key});

  @override
  State<ServicioDronPage> createState() => _ServicioDronPageState();
}

class _ServicioDronPageState extends State<ServicioDronPage> {
  final _formKey = GlobalKey<FormState>();

  final _loteCtrl = TextEditingController();
  final _hectareasCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  DateTime? _fecha;
  String _objetivo = 'Fotogrametría (ortomosaico)';
  PlatformFile? _archivoSeleccionado;

  bool _enviando = false;

  final objetivos = const <String>[
    'Fotogrametría (ortomosaico)',
    'NDVI / Índices vegetativos',
    'Conteo de plantas',
    'Termografía',
    'Inspección puntual',
  ];

  @override
  void dispose() {
    _loteCtrl.dispose();
    _hectareasCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final initial = _fecha ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _fecha = picked);
    }
  }

  Future<void> _pickArchivo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['kml', 'kmz', 'geojson', 'json'],
      withData: false,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _archivoSeleccionado = res.files.first);
    }
  }

  void _quitarArchivo() {
    setState(() => _archivoSeleccionado = null);
  }

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha del servicio')),
      );
      return;
    }

    try {
      setState(() => _enviando = true);

      // 1) Subir archivo opcional a Storage
      String? storagePath;
      String? downloadUrl;
      if (_archivoSeleccionado != null) {
        final file = _archivoSeleccionado!;
        if (file.path == null) {
          throw Exception('El archivo no tiene una ruta local accesible.');
        }

        final ext = p.extension(file.name).toLowerCase().replaceAll('.', '');
        final now = DateTime.now();
        final folder = DateFormat('yyyy/MM/dd').format(now);

        final cleanName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
        storagePath = 'servicios/dron/solicitudes/$folder/$cleanName';
        final ref = FirebaseStorage.instance.ref(storagePath);
        final f = File(file.path!);

        final uploadTask = ref.putFile(
          f,
          SettableMetadata(
            contentType: ext == 'kml'
                ? 'application/vnd.google-earth.kml+xml'
                : ext == 'kmz'
                    ? 'application/vnd.google-earth.kmz'
                    : 'application/geo+json',
          ),
        );
        showUploadOverlayForTask(
          context,
          uploadTask,
          label: 'Subiendo archivo de referencia…',
        );
        await uploadTask;
        await ref.getMetadata();
        downloadUrl = await ref.getDownloadURL();
      }

      // 2) Guardar documento en Firestore
      final doc = {
        'fecha_solicitada': Timestamp.fromDate(_fecha!),
        'lote': _loteCtrl.text.trim(),
        'hectareas': double.tryParse(_hectareasCtrl.text.replaceAll(',', '.')),
        'objetivo': _objetivo,
        'notas': _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        'archivo_nombre': _archivoSeleccionado?.name,
        'archivo_storage_path': storagePath,
        'archivo_url': downloadUrl,
        'estado': 'pendiente',
        'creado_en': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('servicio_dron_solicitudes').add(doc);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada')),
      );

      // 3) Reset
      _formKey.currentState!.reset();
      setState(() {
        _fecha = null;
        _objetivo = objetivos.first;
        _archivoSeleccionado = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String _fmtFecha(DateTime? d) => d == null ? 'Seleccionar fecha' : DateFormat('yyyy-MM-dd').format(d);

  Future<void> _abrirUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final ok = await canLaunchUrl(uri);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la URL')),
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al intentar abrir la URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicio de DRON'),
        backgroundColor: const Color(0xFFF2AE2E),
        foregroundColor: Colors.black,
      ),
      body: AbsorbPointer(
        absorbing: _enviando,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ---------- FORM ----------
              Form(
                key: _formKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Nueva solicitud', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),

                      // Fecha
                      Text('Fecha', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _pickFecha,
                        icon: const Icon(Icons.event),
                        label: Text(_fmtFecha(_fecha)),
                      ),
                      const SizedBox(height: 12),

                      // Lote
                      TextFormField(
                        controller: _loteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Lote / Parcela *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el lote/parcela' : null,
                      ),
                      const SizedBox(height: 12),

                      // Hectáreas
                      TextFormField(
                        controller: _hectareasCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hectáreas *',
                          hintText: 'Ej: 12.5',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa las hectáreas';
                          final n = double.tryParse(v.replaceAll(',', '.'));
                          if (n == null || n <= 0) return 'Valor inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Objetivo
                      DropdownButtonFormField<String>(
                        initialValue: _objetivo,
                        decoration: const InputDecoration(
                          labelText: 'Objetivo del vuelo *',
                          border: OutlineInputBorder(),
                        ),
                        items: objetivos
                            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                            .toList(),
                        onChanged: (v) => setState(() => _objetivo = v ?? objetivos.first),
                      ),
                      const SizedBox(height: 12),

                      // Notas
                      TextFormField(
                        controller: _notasCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notas (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Archivo
                      Text('Archivo de referencia (KML/KMZ/GeoJSON) — opcional',
                          style: theme.textTheme.labelMedium),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickArchivo,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Adjuntar'),
                          ),
                          const SizedBox(width: 10),
                          if (_archivoSeleccionado != null)
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(_archivoSeleccionado!.name,
                                      overflow: TextOverflow.ellipsis, maxLines: 1),
                                  IconButton(
                                    tooltip: 'Quitar archivo',
                                    onPressed: _quitarArchivo,
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Enviar
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF2AE2E),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _enviando ? null : _enviarSolicitud,
                          icon: _enviando
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.send),
                          label: Text(_enviando ? 'Enviando...' : 'Enviar solicitud'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ---------- HISTORIAL ----------
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Historial de solicitudes',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('servicio_dron_solicitudes')
                    .orderBy('creado_en', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Aún no hay solicitudes.'),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final d = snapshot.data!.docs[i].data();
                      final fecha = (d['fecha_solicitada'] as Timestamp?)?.toDate();
                      final creado = (d['creado_en'] as Timestamp?)?.toDate();
                      final lote = d['lote'] as String? ?? '-';
                      final hect = (d['hectareas'] as num?)?.toDouble();
                      final objetivo = d['objetivo'] as String? ?? '-';
                      final estado = (d['estado'] as String? ?? 'pendiente');
                      final url = d['archivo_url'] as String?;
                      final archivoNombre = d['archivo_nombre'] as String?;

                      return ListTile(
                        leading: _EstadoChipMini(estado: estado),
                        title: Text('$lote • ${hect == null ? '-' : '${hect.toStringAsFixed(2)} ha'}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Objetivo: $objetivo'),
                            Text('Fecha: ${fecha == null ? '-' : DateFormat('yyyy-MM-dd').format(fecha)}'
                                '   •   Creado: ${creado == null ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(creado)}'),
                            if (archivoNombre != null) Text('Archivo: $archivoNombre'),
                          ],
                        ),
                        trailing: url == null
                            ? null
                            : IconButton(
                          tooltip: 'Ver/descargar archivo',
                          onPressed: () => _abrirUrl(url),
                          icon: const Icon(Icons.open_in_new),
                        ),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            showDragHandle: true,
                            isScrollControlled: true,
                            builder: (_) => _DetalleSolicitudSheet(data: d, onOpenUrl: _abrirUrl),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoChipMini extends StatelessWidget {
  final String estado;
  const _EstadoChipMini({required this.estado});

  Color _color() {
    switch (estado) {
      case 'completado':
        return Colors.green;
      case 'en_proceso':
        return Colors.orange;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: _color().withOpacity(0.12),
      child: Icon(
        estado == 'completado'
            ? Icons.check
            : estado == 'en_proceso'
            ? Icons.hourglass_bottom
            : estado == 'cancelado'
            ? Icons.close
            : Icons.pending,
        color: _color(),
        size: 18,
      ),
    );
  }
}

class _DetalleSolicitudSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function(String url)? onOpenUrl;
  const _DetalleSolicitudSheet({required this.data, this.onOpenUrl});

  @override
  Widget build(BuildContext context) {
    final fecha = (data['fecha_solicitada'] as Timestamp?)?.toDate();
    final creado = (data['creado_en'] as Timestamp?)?.toDate();
    final hect = (data['hectareas'] as num?)?.toDouble();
    final url = data['archivo_url'] as String?;
    final archivoNombre = data['archivo_nombre'] as String?;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detalle de la solicitud', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Lote: ${data['lote'] ?? '-'}'),
          Text('Hectáreas: ${hect == null ? '-' : hect.toStringAsFixed(2)}'),
          Text('Objetivo: ${data['objetivo'] ?? '-'}'),
          Text('Fecha solicitada: ${fecha == null ? '-' : DateFormat('yyyy-MM-dd').format(fecha)}'),
          Text('Notas: ${data['notas'] ?? '-'}'),
          Text('Estado: ${data['estado'] ?? 'pendiente'}'),
          Text('Creado: ${creado == null ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(creado)}'),
          if (archivoNombre != null) Text('Archivo: $archivoNombre'),
          if (url != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    'URL: $url',
                    style: const TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onOpenUrl == null ? null : () => onOpenUrl!(url),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}