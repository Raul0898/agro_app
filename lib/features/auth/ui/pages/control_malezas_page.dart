// lib/features/auth/ui/pages/control_malezas_page.dart
import 'package:flutter/material.dart';

class ControlMalezasPage extends StatelessWidget {
  const ControlMalezasPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Sin AppBar ni Scaffold para evitar divisor y título duplicado
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          'Control de Malezas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
