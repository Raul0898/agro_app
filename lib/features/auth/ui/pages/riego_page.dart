import 'package:flutter/material.dart';

class RiegoPage extends StatelessWidget {
  const RiegoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riego'),
        backgroundColor: const Color(0xFFF2AE2E),
        foregroundColor: Colors.black,
      ),
      body: const Center(child: Text('Riego (pendiente de contenido)')),
    );
  }
}