// lib/widgets/mini_icon_rail_scaffold.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import './user_actions_menu.dart';

enum AppBlock { produccion, calidad, servicios }

class RailItem {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const RailItem({required this.icon, required this.tooltip, required this.onTap});
}

class AlphaShadowLogo extends StatelessWidget {
  // ... (sin cambios)
  // (dejo igual todo lo que ya tenías aquí)

  const AlphaShadowLogo({super.key});

  @override
  Widget build(BuildContext context) {
    // Implementación mínima para cumplir con StatelessWidget.
    // Si este widget tenía contenido antes, sustitúyelo aquí.
    return const SizedBox.shrink();
  }
}

class MiniIconRailScaffold extends StatefulWidget {
  final String title;
  final List<RailItem> items;
  final int currentIndex;
  final ValueChanged<int>? onSelect;
  final AppBlock block;
  final Widget body;

  // NUEVO: etiqueta opcional para el chip de bloque
  final String? sectionLabel;

  const MiniIconRailScaffold({
    super.key,
    required this.title,
    required this.items,
    required this.currentIndex,
    required this.block,
    required this.body,
    this.onSelect,
    this.sectionLabel, // NEW
  });

  @override
  State<MiniIconRailScaffold> createState() => _MiniIconRailScaffoldState();
}

class _MiniIconRailScaffoldState extends State<MiniIconRailScaffold> {
  static const double _railExpandedWidth = 96;
  static const double _handleWidth = 18;
  static const double _handleHeight = 64;
  bool _collapsed = false;

  Color get _accent => const Color(0xFFF2AE2E);

  // Usa override si viene, si no la etiqueta por bloque
  String get _blockTitle {
    if (widget.sectionLabel != null && widget.sectionLabel!.isNotEmpty) {
      return widget.sectionLabel!;
    }
    switch (widget.block) {
      case AppBlock.produccion:
        return 'Producción';
      case AppBlock.calidad:
        return 'Calidad';
      case AppBlock.servicios:
        return 'Servicios';
    }
  }

  Color get _blockColor => const Color(0xFFFFFFFF);

  void _toggleCollapsed() => setState(() => _collapsed = !_collapsed);

  @override
  Widget build(BuildContext context) {
    final railPanel = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: _collapsed ? 0 : _railExpandedWidth,
      decoration: _collapsed
          ? null
          : BoxDecoration(
        color: const Color(0xFF151f28),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF151f28).withOpacity(0.55),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _collapsed
          ? const SizedBox.shrink()
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                _blockTitle, // ← ahora puede decir "F. Especializada"
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: _blockColor,
                ),
              ),
            ),
          ),
          Container(height: 1, color: Colors.grey.withOpacity(0.25)),
          Expanded(
            child: Column(
              children: [
                for (int i = 0; i < widget.items.length; i++) ...[
                  Expanded(
                    child: Tooltip(
                      message: widget.items[i].tooltip,
                      waitDuration: const Duration(milliseconds: 350),
                      child: InkWell(
                        onTap: () {
                          widget.onSelect?.call(i);
                          widget.items[i].onTap();
                        },
                        child: Center(
                          child: _CircleIcon(
                            widget.items[i].icon,
                            selected: i == widget.currentIndex,
                            accent: _accent,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );

    final handle = Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleCollapsed,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: _handleWidth,
            height: _handleHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF151f28).withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 220),
              turns: _collapsed ? 0.0 : 0.5,
              child: const Icon(Icons.chevron_left, size: 18),
            ),
          ),
        ),
      ),
    );

    final railWithHandle = SizedBox(
      width: _collapsed ? _handleWidth : (_railExpandedWidth + _handleWidth / 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(alignment: Alignment.centerLeft, child: railPanel),
          Positioned(
            left: _collapsed ? 0 : (_railExpandedWidth - _handleWidth / 2),
            top: 0,
            bottom: 0,
            child: handle,
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
            Image.asset('IMG/Logo1.png', height: 60, fit: BoxFit.contain),
          ],
        ),
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('IMG/7.jpg', fit: BoxFit.cover),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x99000000)],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          railWithHandle,
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut,
              child: widget.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final Color? accent;
  final double size;
  const _CircleIcon(this.icon, {this.selected = false, this.accent, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2C2C2C) : Colors.white;
    final bg = selected ? (accent ?? const Color(0xFFF2AE2E)) : Colors.transparent;
    final boxShadow = selected
        ? [
      BoxShadow(
        color: (accent ?? const Color(0xFFF2AE2E)).withOpacity(0.20),
        blurRadius: 8,
        spreadRadius: 0.4,
        offset: const Offset(0, 2),
      ),
    ]
        : null;

    return AnimatedScale(
      scale: selected ? 1.14 : 1.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: boxShadow,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}
