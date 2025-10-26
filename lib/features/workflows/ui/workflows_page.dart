import 'package:flutter/material.dart';
import '../data/workflows_repository.dart';
import '../../stages/ui/stages_page.dart';

class WorkflowsPage extends StatefulWidget {
  final String companyId;
  final String fieldId;
  final String fieldName;
  const WorkflowsPage({super.key, required this.companyId, required this.fieldId, required this.fieldName});

  @override
  State<WorkflowsPage> createState() => _WorkflowsPageState();
}

class _WorkflowsPageState extends State<WorkflowsPage> {
  late final repo = WorkflowsRepository(companyId: widget.companyId, fieldId: widget.fieldId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Workflows • ${widget.fieldName}')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newWorkflow(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) return const Center(child: Text('Sin workflows. Agrega uno con +'));
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final w = items[i];
              return ListTile(
                title: Text(w['name'] ?? ''),
                subtitle: Text(w['id']),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'ren') _rename(w);
                    if (v == 'del') await repo.delete(w['id']);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'ren', child: Text('Renombrar')),
                    PopupMenuItem(value: 'del', child: Text('Eliminar')),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StagesPage(
                        companyId: widget.companyId,
                        fieldId: widget.fieldId,
                        workflowId: w['id'],
                        workflowName: w['name'] ?? w['id'],
                      ),
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

  Future<void> _newWorkflow() async {
    final c = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo Workflow'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () async { if (c.text.trim().isNotEmpty) await repo.add(name: c.text.trim()); if (context.mounted) Navigator.pop(context); }, child: const Text('Crear')),
        ],
      ),
    );
  }

  Future<void> _rename(Map<String, dynamic> w) async {
    final c = TextEditingController(text: w['name']);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar Workflow'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () async { if (c.text.trim().isNotEmpty) await repo.rename(w['id'], c.text.trim()); if (context.mounted) Navigator.pop(context); }, child: const Text('Guardar')),
        ],
      ),
    );
  }
}
