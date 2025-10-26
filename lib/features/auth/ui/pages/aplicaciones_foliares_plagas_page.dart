// lib/features/auth/ui/pages/aplicaciones_foliares_plagas_page.dart
import 'package:flutter/material.dart';

class AplicacionesFoliaresPlagasPage extends StatelessWidget {
  const AplicacionesFoliaresPlagasPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Sin AppBar ni Scaffold para evitar divisor y título duplicado
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          'Aplicaciones Foliares - Plagas - Enfermedades',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
