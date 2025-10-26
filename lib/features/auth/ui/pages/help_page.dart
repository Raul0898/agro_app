import 'package:flutter/material.dart';
import '../../../../home_page.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda'),
        backgroundColor: const Color(0xFFF2AE2E),
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Regresar',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Inicio',
            onPressed: () => _goHome(context),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Centro de ayuda / preguntas frecuentes',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}