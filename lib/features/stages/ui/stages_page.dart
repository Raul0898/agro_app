import 'package:flutter/material.dart';
import '../data/stages_repository.dart';

class StagesPage extends StatefulWidget {
  final String companyId;
  final String fieldId;
  final String workflowId;
  final String workflowName;
  const StagesPage({super.key, required this.companyId, required this.fieldId, required this.workflowId, required this.workflowName});

  @override
  State<StagesPage> createState() => _StagesPageState();
}

class _StagesPageState extends State<StagesPage> {
  StagesRepository get repo => StagesRepository(companyId: widget.companyId, fieldId: widget.fieldId, workflowId: widget.workflowId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Etapas • ${widget.workflowName}')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addStageDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final stages = snap.data!;
          if (stages.isEmpty) return const Center(child: Text('Sin etapas. Agrega una con +'));
          return ListView.separated(
            itemCount: stages.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = stages[i];
              final completed = (s['completed'] ?? false) as bool;
              return ListTile(
                title: Text('${s['order']}. ${s['title']}'),
                subtitle: (s['prerequisites'] as List<dynamic>? ?? const []).isEmpty
                    ? const Text('Sin prerequisitos')
                    : Text('Prerequisitos: ${(s['prerequisites'] as List).join(', ')}'),
                leading: Checkbox(
                  value: completed,
                  onChanged: (v) => repo.toggleComplete(s['id'], v ?? false),
                ),
                trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => repo.delete(s['id'])),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addStageDialog() async {
    final id = TextEditingController();
    final title = TextEditingController();
    final order = TextEditingController(text: '1');
    final prereq = TextEditingController(); // CSV: st_registro,st_preparacion
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva Etapa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: id, decoration: const InputDecoration(labelText: 'ID (ej. st_registro)')),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')),
            TextField(controller: order, decoration: const InputDecoration(labelText: 'Orden (número)'), keyboardType: TextInputType.number),
            TextField(controller: prereq, decoration: const InputDecoration(labelText: 'Prerequisitos (IDs, separados por coma)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final o = int.tryParse(order.text.trim()) ?? 1;
              final p = prereq.text.trim().isEmpty
                  ? <String>[]
                  : prereq.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              if (id.text.trim().isEmpty || title.text.trim().isEmpty) return;
              await repo.add(id: id.text.trim(), title: title.text.trim(), order: o, prerequisites: p);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
