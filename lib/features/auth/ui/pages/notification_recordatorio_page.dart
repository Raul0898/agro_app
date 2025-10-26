import 'package:flutter/material.dart';

class NotificationRecordatorioPage extends StatelessWidget {
  const NotificationRecordatorioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recordatorio')),
      body: const Center(
        child: Text(
          'Detalle del recordatorio',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}