// lib/widgets/menu_selector.dart
import 'package:flutter/material.dart';

import '../cultivos/configs.dart';

/// Convención de claves:
///   - Menú:    "menu:{menuId}"
///   - Submenú: "submenu:{menuId}/{textoSubmenu}"
///
/// Este widget:
/// 1) Muestra los menús y submenús para seleccionar con checkboxes.
/// 2) Permite AGREGAR submenús (conceptos) nuevos a un menú existente.
/// 3) Devuelve la selección a través de [onChanged] como List<String>
///    de claves con el formato descrito arriba.
class MenuSelector extends StatefulWidget {
  final List<MenuDef> baseMenus;              // menús base (p.ej. desde maizConfig)
  final Set<String> initialSelectedKeys;      // claves seleccionadas al inicio
  final ValueChanged<List<String>> onChanged; // callback de cambios

  const MenuSelector({
    super.key,
    required this.baseMenus,
    required this.initialSelectedKeys,
    required this.onChanged,
  });

  @override
  State<MenuSelector> createState() => _MenuSelectorState();
}

class _MenuSelectorState extends State<MenuSelector> {
  late List<MenuDef> _menus;          // copia modificable (para añadir submenús)
  late Set<String> _selected;         // selección actual

  @override
  void initState() {
    super.initState();
    _menus = widget.baseMenus
        .map((m) => MenuDef(id: m.id, title: m.title, items: List<String>.from(m.items)))
        .toList();
    _selected = Set<String>.from(widget.initialSelectedKeys);
  }

  void _toggleMenu(String menuId, bool value) {
    setState(() {
      final key = 'menu:$menuId';
      if (value) {
        _selected.add(key);
      } else {
        _selected.remove(key);
        // al desmarcar el menú, opcionalmente desmarcamos todos sus submenús
        for (final s in _subItemsOf(menuId)) {
          _selected.remove('submenu:$menuId/$s');
        }
      }
    });
    widget.onChanged(_selected.toList()..sort());
  }

  void _toggleSubmenu(String menuId, String subItem, bool value) {
    setState(() {
      final key = 'submenu:$menuId/$subItem';
      if (value) {
        // si marcamos un submenú, marcamos también el menú padre
        _selected.add('menu:$menuId');
        _selected.add(key);
      } else {
        _selected.remove(key);
      }
    });
    widget.onChanged(_selected.toList()..sort());
  }

  List<String> _subItemsOf(String menuId) {
    final m = _menus.where((e) => e.id == menuId).cast<MenuDef?>().firstWhere((_) => true, orElse: () => null);
    return m?.items ?? const <String>[];
  }

  Future<void> _addConceptDialog() async {
    String? selectedMenuId = _menus.isNotEmpty ? _menus.first.id : null;
    final textCtrl = TextEditingController();

    final added = await showDialog<_AddConceptResult>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Añadir concepto (submenú)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedMenuId,
                items: _menus
                    .map((m) =>
                    DropdownMenuItem(value: m.id, child: Text(m.title)))
                    .toList(),
                onChanged: (v) => selectedMenuId = v,
                decoration: const InputDecoration(
                  labelText: 'Añadir en el menú',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del concepto',
                  hintText: 'Ej. “Conductividad eléctrica”',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final menu = selectedMenuId?.trim();
                final concept = textCtrl.text.trim();
                if (menu == null || menu.isEmpty || concept.isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop(_AddConceptResult(menuId: menu, text: concept));
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (added == null) return;

    // Inserta el nuevo submenú en memoria y lo marca seleccionado.
    setState(() {
      final idx = _menus.indexWhere((m) => m.id == added.menuId);
      if (idx >= 0) {
        final items = List<String>.from(_menus[idx].items);
        if (!items.contains(added.text)) {
          items.add(added.text);
        }
        _menus = List<MenuDef>.from(_menus)
          ..[idx] = MenuDef(id: _menus[idx].id, title: _menus[idx].title, items: items);

        // Marca el menú y el submenú recién creado
        _selected.add('menu:${added.menuId}');
        _selected.add('submenu:${added.menuId}/${added.text}');
      }
    });

    widget.onChanged(_selected.toList()..sort());
  }

  @override
  Widget build(BuildContext context) {
    if (_menus.isEmpty) {
      return const Text('No hay menús para mostrar.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botón para agregar conceptos (submenús)
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Añadir concepto'),
            onPressed: _addConceptDialog,
          ),
        ),
        const SizedBox(height: 8),

        // Lista de menús + submenús
        ..._menus.map((m) {
          final menuKey = 'menu:${m.id}';
          final menuValue = _selected.contains(menuKey);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: menuValue,
                    onChanged: (v) => _toggleMenu(m.id, v ?? false),
                    title: Text(m.title),
                  ),
                  ...m.items.map((s) {
                    final subKey = 'submenu:${m.id}/$s';
                    final subValue = _selected.contains(subKey);
                    return Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: CheckboxListTile(
                        value: subValue,
                        onChanged: (v) => _toggleSubmenu(m.id, s, v ?? false),
                        title: Text('• $s'),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _AddConceptResult {
  final String menuId;
  final String text;
  _AddConceptResult({required this.menuId, required this.text});
}