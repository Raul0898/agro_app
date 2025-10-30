import 'package:flutter/material.dart';

/// Botón de acciones de usuario (avatar + menú blanco con 2 opciones).
/// Opciones:
/// 0 = Información personal
/// 1 = Ayuda
class UserActionsButton extends StatefulWidget {
  final ValueChanged<int>? onSelected;
  final String title;

  const UserActionsButton({super.key, this.onSelected, this.title = 'Usuario'});

  @override
  State<UserActionsButton> createState() => _UserActionsButtonState();
}

class _UserActionsButtonState extends State<UserActionsButton> {
  final GlobalKey _btnKey = GlobalKey();
  OverlayEntry? _entry;

  void _openMenu() {
    if (_entry != null) return;
    final overlay = Overlay.of(context);

    final renderBox = _btnKey.currentContext!.findRenderObject() as RenderBox;
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final btnSize = renderBox.size;
    final btnPos = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final screen = overlayBox.size;

    const double minW = 240, maxW = 320, pad = 8;
    const double estH = 6 + 2 * 48 + 6; // barras + 2 items + barra

    double left = btnPos.dx;
    double top = btnPos.dy + btnSize.height + pad;

    final menuW = maxW.toDouble();
    if (left + menuW > screen.width - pad) {
      left = (screen.width - pad - menuW).clamp(pad, screen.width - menuW);
    }
    if (top + estH > screen.height - pad) {
      top = (btnPos.dy - pad - estH).clamp(pad, screen.height - estH - pad);
    }

    _entry = OverlayEntry(builder: (_) {
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeMenu,
            child: const SizedBox.shrink(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: _MenuBox(
            minWidth: minW,
            maxWidth: maxW,
            onSelect: (v) {
              _closeMenu();
              widget.onSelected?.call(v);
            },
          ),
        ),
      ]);
    });

    overlay.insert(_entry!);
  }

  void _closeMenu() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      key: _btnKey,
      onTap: _openMenu,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar naranja con ícono negro (siempre visible)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withOpacity(0.15), width: 1),
              ),
              child: const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFF2AE2E),
                child: Icon(Icons.person, size: 16, color: Colors.black),
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.title,
                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
            const Icon(Icons.arrow_drop_down, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

class _MenuBox extends StatelessWidget {
  final ValueChanged<int> onSelect;
  final double minWidth;
  final double maxWidth;

  const _MenuBox({
    required this.onSelect,
    required this.minWidth,
    required this.maxWidth,
  });

  static const _bg = Colors.white;           // BLANCO
  static const _text = Colors.black;         // NEGRO
  static const _divider = Color(0xFFC9C9C9); // gris medio
  static const _bar = Color(0xFFE5E5E5);     // gris claro (barras)
  static const _hover = Color(0x33E5E5E5);   // hover gris claro ~20%

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: maxWidth,
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _bar, width: 4),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 6, color: _bar),
              _MenuItem(icon: Icons.person_outline, label: 'Información personal', onTap: () => onSelect(0)),
              const Divider(height: 1, thickness: 1, color: _divider),
              _MenuItem(icon: Icons.help_outline, label: 'Ayuda', onTap: () => onSelect(1)),
              Container(height: 6, color: _bar),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.label, required this.onTap});

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered ? _MenuBox._hover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const SizedBox(width: 2),
              Icon(widget.icon, color: _MenuBox._text),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.label,
                    style: const TextStyle(color: _MenuBox._text, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
