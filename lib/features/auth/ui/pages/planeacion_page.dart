import 'package:flutter/material.dart';

class PlaneacionPage extends StatelessWidget {
  const PlaneacionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planeación'),
        backgroundColor: const Color(0xFFF2AE2E),
        foregroundColor: Colors.black,
      ),
      body: const Center(child: Text('Planeación (pendiente de contenido)')),
    );
  }
}