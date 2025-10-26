import 'package:flutter/material.dart';

class VerificacionGerminacionPage extends StatelessWidget {
  const VerificacionGerminacionPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Sin Scaffold ni AppBar
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verificación de Germinación',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Pantalla en construcción',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
