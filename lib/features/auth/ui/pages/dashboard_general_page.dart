import 'package:flutter/material.dart';

class DashboardGeneralPage extends StatelessWidget {
  const DashboardGeneralPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'En este Dashboard estarán los avances de todas las actividades en forma de diagrama de flujo como se tiene en Canva con porcentajes y gráfica.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
