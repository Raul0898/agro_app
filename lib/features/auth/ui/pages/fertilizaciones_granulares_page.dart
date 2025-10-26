import 'package:flutter/material.dart';

class FertilizacionesGranularesPage extends StatelessWidget {
  const FertilizacionesGranularesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Sin Scaffold ni AppBar: el contenedor padre ya los provee
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fertilizaciones Granulares',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Pantalla en construcción',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
