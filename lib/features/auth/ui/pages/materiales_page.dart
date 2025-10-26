import 'package:flutter/material.dart';
import '../../../../widgets/mini_icon_rail_scaffold.dart';
import 'equipos_pequenos_page.dart';
import 'equipos_grandes_page.dart';
import 'registro_implementos_page.dart';

// Alias SOLO para estas dos páginas para evitar colisiones
import 'package:agro_app/features/auth/ui/pages/registro_usuario_page.dart' as reg_user;
import 'package:agro_app/features/auth/ui/pages/registro_unidades_siembra_page.dart' as reg_unidades;

class MaterialesPage extends StatelessWidget {
  const MaterialesPage({super.key});

  List<RailItem> _items(BuildContext context) => [
    RailItem(
      icon: Icons.build_outlined,
      tooltip: 'Equipos Pequeños',
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EquiposPequenosPage()),
      ),
    ),
    RailItem(
      icon: Icons.agriculture_outlined,
      tooltip: 'Equipos Grandes',
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EquiposGrandesPage()),
      ),
    ),
    RailItem(
      icon: Icons.widgets_outlined,
      tooltip: 'Materiales',
      onTap: () {}, // aquí
    ),
    RailItem(
      icon: Icons.person_add_alt_1_outlined,
      tooltip: 'Registro de usuario',
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const reg_user.RegistroUsuarioPage()),
      ),
    ),
    RailItem(
      icon: Icons.yard_outlined,
      tooltip: 'Registro de Unidades de Siembra',
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const reg_unidades.RegistroUnidadesSiembraPage()),
      ),
    ),
    RailItem(
      icon: Icons.precision_manufacturing_outlined,
      tooltip: 'Registro de Implementos',
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegistroImplementosPage()),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MiniIconRailScaffold(
      title: 'Materiales',
      items: _items(context),
      currentIndex: 2,
      block: AppBlock.servicios,
      body: const Center(
        child: Text('Pantalla de Materiales', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
