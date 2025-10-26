import 'package:flutter/material.dart';

class NotificationAvisoPage extends StatelessWidget {
  const NotificationAvisoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aviso')),
      body: const Center(
        child: Text(
          'Detalle del aviso',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}