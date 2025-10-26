import 'package:flutter/material.dart';

class NotificationMensajePage extends StatelessWidget {
  const NotificationMensajePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensaje')),
      body: const Center(
        child: Text(
          'Detalle del mensaje',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}