import 'package:flutter/material.dart';
import '../data/fields_repository.dart';
import '../../workflows/ui/workflows_page.dart';

class FieldsPage extends StatefulWidget {
  final String companyId;
  const FieldsPage({super.key, required this.companyId});

  @override
  State<FieldsPage> createState() => _FieldsPageState();
}

class _FieldsPageState extends State<FieldsPage> {
  late final repo = FieldsRepository(companyId: widget.companyId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terrenos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFieldDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) return const Center(child: Text('Sin terrenos. Agrega uno con +'));
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final f = items[i];
              return ListTile(
                title: Text(f['name'] ?? ''),
                subtitle: Text(f['crop'] ?? '—'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') _showFieldDialog(existing: f);
                    if (v == 'del') await repo.delete(f['id']);
                  },
                  itemBuilder: (c) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'del', child: Text('Eliminar')),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkflowsPage(companyId: widget.companyId, fieldId: f['id'], fieldName: f['name']),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showFieldDialog({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name']);
    final crop = TextEditingController(text: existing?['crop']);
    final isEdit = existing != null;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Editar terreno' : 'Nuevo terreno'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: crop, decoration: const InputDecoration(labelText: 'Cultivo (opcional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              if (isEdit) {
                await repo.update(id: existing!['id'], name: name.text.trim(), crop: crop.text.trim().isEmpty ? null : crop.text.trim());
              } else {
                await repo.add(name: name.text.trim(), crop: crop.text.trim().isEmpty ? null : crop.text.trim());
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(isEdit ? 'Guardar' : 'Crear'),
          ),
        ],
      ),
    );
  }
}
