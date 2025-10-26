import 'package:flutter/material.dart';

class DashboardCeiPage extends StatelessWidget {
  const DashboardCeiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'En este Dashboard irán los avances en forma de concepto por actividad y porcentajes según avances (C.e.I).',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
