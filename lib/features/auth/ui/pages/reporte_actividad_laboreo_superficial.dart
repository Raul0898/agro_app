import 'package:flutter/material.dart';

class ReporteActividadLaboreoSuperficialPage extends StatelessWidget {
  const ReporteActividadLaboreoSuperficialPage({
    super.key,
    required this.seleccion,
  });

  final String seleccion;

  String get _etiqueta {
    switch (seleccion.toLowerCase()) {
      case 'ambos':
        return 'Rastreo y Desterronador';
      case 'desterronador':
        return 'Desterronador';
      case 'rastra':
      default:
        return 'Rastreo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Actividad Laboreo Superficial'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actividad seleccionada: $_etiqueta'),
            const SizedBox(height: 12),
            const Text(
              'Pantalla de ejemplo para registrar actividades de laboreo superficial. Se integrará con el flujo definitivo en próximas iteraciones.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Registrar actividad'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
