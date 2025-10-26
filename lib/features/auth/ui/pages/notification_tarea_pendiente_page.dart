import 'package:flutter/material.dart';

class NotificationTareaPendientePage extends StatelessWidget {
  const NotificationTareaPendientePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tarea pendiente')),
      body: const Center(
        child: Text(
          'Detalle de la tarea pendiente',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}