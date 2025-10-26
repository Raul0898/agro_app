// lib/verificacion/verificacion_base_page.dart
import 'package:flutter/material.dart';
import 'package:agro_app/cultivos/configs.dart';

class VerificacionBasePage extends StatelessWidget {
  final CultivoConfig config;
  const VerificacionBasePage({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verificación • ${config.nombre}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: config.defaultMenus.length,
        itemBuilder: (_, i) {
          final m = config.defaultMenus[i];
          return Card(
            child: ListTile(
              title: Text(m.title),
              subtitle: Text(
                m.items.isEmpty ? 'Sin subitems' : m.items.join(' • '),
              ),
            ),
          );
        },
      ),
    );
  }
}