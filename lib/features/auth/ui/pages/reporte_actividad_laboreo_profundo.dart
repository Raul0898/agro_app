import 'package:flutter/material.dart';

class ReporteActividadLaboreoProfundoPage extends StatelessWidget {
  const ReporteActividadLaboreoProfundoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Actividad Laboreo Profundo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este es un formulario de ejemplo. Próximamente se integrará con el flujo completo de reportes.',
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
