// lib/widgets/custom_app_bar.dart
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Título y logo
      title: Row(
        children: [
          Expanded(
            child: Text(title),
          ),
          // Usamos el logo pequeño que ya tienes
          Image.asset('IMG/Copia de Don Raul-2.png', height: 28, fit: BoxFit.contain),
        ],
      ),
      // Forzamos el color del texto y los iconos a blanco para que contraste
      foregroundColor: Colors.white,
      // Fondo con imagen y overlay oscuro
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          // Tu imagen de fondo
          Image.asset(
            'IMG/7.jpg',
            fit: BoxFit.cover,
          ),
          // Overlay oscuro para mejorar la legibilidad del texto
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.40), // Puedes ajustar la opacidad (0.0 a 1.0)
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}