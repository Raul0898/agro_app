import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/firestore/laboreo_service.dart';
import '../../core/router/app_routes.dart';

class ReporteActividadLaboreoProfundoPage extends StatefulWidget {
  const ReporteActividadLaboreoProfundoPage({super.key, required this.args});

  final LaboreoProfundoArgs args;

  @override
  State<ReporteActividadLaboreoProfundoPage> createState() =>
      _ReporteActividadLaboreoProfundoPageState();
}

class _ReporteActividadLaboreoProfundoPageState
    extends State<ReporteActividadLaboreoProfundoPage> {
  final _formKey = GlobalKey<FormState>();
  final _comentariosCtrl = TextEditingController();
  final _equipoCtrl = TextEditingController();
  final _service = LaboreoService();

  bool _saving = false;
  final DateTime _fecha = DateTime.now();

  @override
  void dispose() {
    _comentariosCtrl.dispose();
    _equipoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('reportes_preparacion_suelos')
          .add({
        'uid': widget.args.uid,
        'unidad': widget.args.unidadId,
        'tipo': 'laboreo_profundo',
        'decisionFuente': widget.args.decisionFuente,
        'notas': _comentariosCtrl.text.trim(),
        'equipo': _equipoCtrl.text.trim(),
        'fecha': Timestamp.fromDate(_fecha),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final decisionDocId = widget.args.decisionDocId;
      if (decisionDocId != null && decisionDocId.isNotEmpty) {
        await _service.setUltimoReporteProfundo(decisionDocId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte guardado correctamente.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el reporte: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fechaFmt = DateFormat('dd/MM/yyyy HH:mm', 'es_MX').format(_fecha);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Laboreo Profundo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Unidad: ${widget.args.unidadId}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (widget.args.decisionFuente != null)
                Chip(
                  avatar: const Icon(Icons.info_outline),
                  label: Text('Fuente: ${widget.args.decisionFuente}'),
                ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Fecha del reporte'),
                subtitle: Text(fechaFmt),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _comentariosCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Descripción de la actividad',
                  hintText: 'Describe la actividad realizada',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa una descripción';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _equipoCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Equipo utilizado (opcional)',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _guardar,
                  icon: const Icon(Icons.save_alt),
                  label: _saving
                      ? const Text('Guardando…')
                      : const Text('Guardar reporte'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
