import 'package:flutter/material.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 240,
      color: const Color(0xFF2C2C2C), // Gris oscuro (sidebar)
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo + nombre
              Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: cs.primary, // Naranja corporativo
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AGROAPP',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _NavItem(
                label: 'Dashboard',
                icon: Icons.dashboard_rounded,
                index: 0,
                selectedIndex: selectedIndex,
                onTap: () => onSelect(0),
              ),
              _NavItem(
                label: 'Overview',
                icon: Icons.home_rounded,
                index: 1,
                selectedIndex: selectedIndex,
                onTap: () => onSelect(1),
              ),
              _NavItem(
                label: 'Analytics',
                icon: Icons.analytics_outlined,
                index: 2,
                selectedIndex: selectedIndex,
                onTap: () => onSelect(2),
              ),
              _NavItem(
                label: 'Alerts',
                icon: Icons.notifications_none_rounded,
                index: 3,
                selectedIndex: selectedIndex,
                onTap: () => onSelect(3),
              ),
              _NavItem(
                label: 'Settings',
                icon: Icons.settings_outlined,
                index: 4,
                selectedIndex: selectedIndex,
                onTap: () => onSelect(4),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Conectado', style: TextStyle(color: Colors.white.withOpacity(.85))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final int index;
  final int selectedIndex;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = index == selectedIndex;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: const Color(0xFFE5E5E5).withOpacity(.16), // gris claro al pasar
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? Colors.white.withOpacity(0.08) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(selected ? 1 : .85)),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(selected ? 1 : .85),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}