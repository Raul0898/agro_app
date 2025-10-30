import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/firestore/laboreo_service.dart';
import '../../core/router/app_routes.dart';

class ReporteActividadLaboreoSuperficialPage extends StatefulWidget {
  const ReporteActividadLaboreoSuperficialPage({super.key, required this.args});

  final LaboreoSuperficialArgs args;

  @override
  State<ReporteActividadLaboreoSuperficialPage> createState() =>
      _ReporteActividadLaboreoSuperficialPageState();
}

class _ReporteActividadLaboreoSuperficialPageState
    extends State<ReporteActividadLaboreoSuperficialPage> {
  final _formKey = GlobalKey<FormState>();
  final _observacionesCtrl = TextEditingController();
  final _service = LaboreoService();

  bool _saving = false;
  final DateTime _fecha = DateTime.now();

  @override
  void dispose() {
    _observacionesCtrl.dispose();
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
        'tipo': 'laboreo_superficial',
        'actividades': widget.args.actividades,
        'notas': _observacionesCtrl.text.trim(),
        'fecha': Timestamp.fromDate(_fecha),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final docId = widget.args.actividadDocId;
      if (docId != null && docId.isNotEmpty) {
        await _service.setReporteSuperficial(docId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte superficial guardado.')),
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
    final actividades = widget.args.actividades;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Laboreo Superficial'),
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actividades
                    .map((actividad) => Chip(
                          avatar: const Icon(Icons.agriculture),
                          label: Text(_nombreActividad(actividad)),
                        ))
                    .toList(),
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
                controller: _observacionesCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  hintText: 'Describe la actividad realizada',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa observaciones';
                  }
                  return null;
                },
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

  String _nombreActividad(String raw) {
    switch (raw.toLowerCase()) {
      case 'rastra':
        return 'Rastreo';
      case 'desterronador':
        return 'Desterronador';
      default:
        return raw;
    }
  }
}
