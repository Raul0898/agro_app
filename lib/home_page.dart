// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Dashboards
import 'features/auth/ui/pages/dashboard_general_page.dart';
import 'features/auth/ui/pages/dashboard_pei_page.dart';
import 'features/auth/ui/pages/dashboard_cei_page.dart';
import 'features/auth/ui/pages/dashboard_actividades_especializadas_page.dart'; // NUEVO

// Usuario y notificaciones
import 'features/auth/ui/pages/personal_info_page.dart';
import 'features/auth/ui/pages/help_page.dart';
import 'features/auth/ui/pages/notification_aviso_page.dart';
import 'features/auth/ui/pages/notification_recordatorio_page.dart';
import 'features/auth/ui/pages/notification_tarea_pendiente_page.dart';
import 'features/auth/ui/pages/notification_mensaje_page.dart';

// Otras páginas
import 'features/auth/ui/pages/activities_page.dart';
import 'features/auth/ui/pages/planeacion_page.dart';
import 'features/auth/ui/pages/servicio_dron_page.dart';
import 'features/auth/ui/pages/equipos_pequenos_page.dart';
import 'features/auth/ui/pages/equipos_grandes_page.dart';
import 'features/auth/ui/pages/materiales_page.dart';
import 'features/auth/ui/pages/registro_usuario_page.dart';
import 'features/auth/ui/pages/registro_unidades_siembra_page.dart';
import 'features/auth/ui/pages/registro_implementos_page.dart';
import 'features/auth/ui/pages/riego_page.dart'; // Bloque fijo Riego
import 'features/auth/ui/pages/selector_contexto_page.dart'; // Flecha en header del Drawer
import 'features/auth/ui/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Contenido actual
  Widget _currentBody = const DashboardGeneralPage();
  String _currentTitle = 'Dashboard General';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Posibles valores: dashboard_general, dashboard_pei, dashboard_cei, dashboard_ae,
  /// prod_inv, cal_inoc, act_esp, riego, servicios
  String _selectedTopKey = 'dashboard_general';

  // Colores
  static const Color _orange = Color(0xFFF2AE2E);
  static const Color _unselected = Colors.white;

  Map<String, dynamic> _permisos = {};
  Map<String, List<String>> _menusPermitidosPorCategoria = {};
  String _unidadSeleccionada = 'Cargando...';
  String _cultivoSeleccionado = 'Cargando...';
  bool _isLoadingMenu = true;

  // Expansión de bloques principales
  bool _expProdInv = false;
  bool _expCalInoc = false;
  bool _expActEsp = false; // Actividades Especializadas
  bool _expRiego = false;
  bool _expServicios = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingMenu = false);
      return;
    }
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!userDoc.exists || !mounted) {
      setState(() => _isLoadingMenu = false);
      return;
    }

    final data = userDoc.data()!;
    final cultivoId = data['cultivoSeleccionado'] as String?;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _permisos = data['permisos'] as Map<String, dynamic>? ?? {};
          _unidadSeleccionada = data['unidadSeleccionada'] as String? ?? 'No asignada';
          _cultivoSeleccionado = cultivoId ?? 'No asignado';
        });
      }
    });

    await _cargarMenusDelCultivo(cultivoId);
    if (mounted) {
      setState(() => _isLoadingMenu = false);
    }
  }

  bool _permisoValido(String permisoId) {
    final permiso = _permisos[permisoId];
    return permiso != null && permiso != 'ninguno';
  }

  Future<void> _cargarMenusDelCultivo(String? cultivoId) async {
    if (cultivoId == null || cultivoId == 'Ninguno') {
      if (mounted) setState(() => _menusPermitidosPorCategoria = {});
      return;
    }

    // Acepta 'fe' y 'ae' y los pinta como “Actividades Especializadas”
    const categoryMap = {
      'pei': 'Producción e Investigación',
      'cei': 'Calidad e Inocuidad',
      'fe' : 'Actividades Especializadas',
      'ae' : 'Actividades Especializadas',
    };

    try {
      final cultivoDoc = await FirebaseFirestore.instance.collection('cultivos_catalog').doc(cultivoId).get();
      if (cultivoDoc.exists && cultivoDoc.data()!.containsKey('menus')) {
        final menuItems = List<String>.from(cultivoDoc.data()!['menus'] as List);
        final Map<String, List<String>> menusAgrupados = {};
        for (final item in menuItems) {
          final parts = item.split(':');
          if (parts.length != 2) continue;
          final categoryAndSubmenu = parts[1].split('/');
          if (categoryAndSubmenu.length != 2) continue;
          final categoryCode = categoryAndSubmenu[0].trim();
          final submenuId = categoryAndSubmenu[1].trim();
          final fullCategoryName = categoryMap[categoryCode];
          if (fullCategoryName != null) {
            menusAgrupados.putIfAbsent(fullCategoryName, () => []).add(submenuId);
          }
        }

        if (mounted) setState(() => _menusPermitidosPorCategoria = menusAgrupados);
      } else {
        if (mounted) setState(() => _menusPermitidosPorCategoria = {});
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error al cargar menús del cultivo: $e');
      if (mounted) setState(() => _menusPermitidosPorCategoria = {});
    }
  }

  // ===== Helpers de UI (top-level “sólo color”) =====

  Widget _topItem({
    required String keyId,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final bool selected = _selectedTopKey == keyId;
    final Color c = selected ? _orange : _unselected;

    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(title, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
      onTap: () {
        setState(() => _selectedTopKey = keyId);
        onTap();
      },
    );
  }

  ExpansionTile _topExpansion({
    required String keyId,
    required bool expanded,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final bool selected = _selectedTopKey == keyId || expanded;
    final Color c = selected ? _orange : _unselected;

    return ExpansionTile(
      initiallyExpanded: expanded,
      onExpansionChanged: (v) {
        setState(() {
          onChanged(v);
          if (v) _selectedTopKey = keyId;
          if (!v && _selectedTopKey == keyId) _selectedTopKey = _computeDashboardKey();
        });
      },
      leading: Icon(icon, color: c),
      title: Text(title, style: TextStyle(color: c, fontWeight: FontWeight.w700)),
      children: children,
    );
  }

  // ===== Submenús (no se pintan en naranja) =====
  Map<String, Widget> _buildAllMenuItems() {
    final Widget afpeTile = ListTile(
      leading: const Icon(Icons.bug_report_outlined, color: Colors.white),
      title: const Text('Aplicaciones Foliares - Plagas - Enfermedades', style: TextStyle(color: Colors.white)),
      onTap: () => _openPage(const ActivitiesPage(title: 'Aplicaciones Foliares - Plagas - Enfermedades'), args: {'section':'ae'}),
    );

    return {
      // ====== P.e.I ======
      'registro_terrenos': ListTile(
        leading: const Icon(Icons.map_outlined, color: Colors.white),
        title: const Text('Registro de Terrenos agrícolas', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Registro de Terrenos agrícolas')),
      ),
      'preparacion_suelos': ListTile(
        leading: const Icon(Icons.landscape_outlined, color: Colors.white),
        title: const Text('Preparación de Suelos', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Preparación de Suelos')),
      ),
      'siembra_fertilizacion': ListTile(
        leading: const Icon(Icons.grass_outlined, color: Colors.white),
        title: const Text('Siembra y Fertilización', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Siembra y Fertilización')),
      ),
      'fertilizaciones_granulares': ListTile(
        leading: const Icon(Icons.inventory_outlined, color: Colors.white),
        title: const Text('Fertilizaciones Granulares', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Fertilizaciones Granulares'), args: {'section':'pei'}),
      ),
      'cosecha': ListTile(
        leading: const Icon(Icons.agriculture, color: Colors.white),
        title: const Text('Cosecha', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Cosecha')),
      ),

      // ====== C.e.I ======
      'analisis_suelo': ListTile(
        leading: const Icon(Icons.analytics_outlined, color: Colors.white),
        title: const Text('Análisis de Suelo', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Análisis de Suelo')),
      ),
      'verif_compactacion': ListTile(
        leading: const Icon(Icons.speed_outlined, color: Colors.white),
        title: const Text('Verificación de Compactación', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Verificación de Compactación')),
      ),
      'verif_germinacion': ListTile(
        leading: const Icon(Icons.grass, color: Colors.white),
        title: const Text('Verificación de Germinación', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Verificación de Germinación'), args: {'section':'cei'}),
      ),
      'inst_equipos': ListTile(
        leading: const Icon(Icons.podcasts_outlined, color: Colors.white),
        title: const Text('Instalación de Equipos de Medición', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Instalación de Equipos de Medición')),
      ),
      'analisis_malezas': ListTile(
        leading: const Icon(Icons.eco_outlined, color: Colors.white),
        title: const Text('Análisis de Malezas', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Análisis de Malezas')),
      ),
      'analisis_nutrientes': ListTile(
        leading: const Icon(Icons.science_outlined, color: Colors.white),
        title: const Text('Análisis de Nutrientes', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Análisis de Nutrientes')),
      ),
      'seguimiento_humedad': ListTile(
        leading: const Icon(Icons.water_drop_outlined, color: Colors.white),
        title: const Text('Seguimiento de Humedad', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Seguimiento de Humedad')),
      ),

      // ====== A.E (Actividades Especializadas) ======
      'control_malezas': ListTile(
        leading: const Icon(Icons.local_florist_outlined, color: Colors.white),
        title: const Text('Control de Malezas', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Control de Malezas'), args: {'section':'ae'}),
      ),
      'aplicaciones_foliares_plagas_enfermedades': afpeTile,
      'aplicaciones_foliares_plagas': afpeTile, // compatibilidad si viniera corto

      // “Dron” (copias especializadas dentro de A.E)
      'fertilizaciones_granulares_Dron': ListTile(
        leading: const Icon(Icons.inventory_outlined, color: Colors.white),
        title: const Text('Fertilizaciones Granulares', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Fertilizaciones Granulares'), args: {'section':'ae'}),
      ),
      'verif_germinacion_Dron': ListTile(
        leading: const Icon(Icons.grass, color: Colors.white),
        title: const Text('Verificación de Germinación', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Verificación de Germinación'), args: {'section':'ae'}),
      ),
      'analisis_ndvi': ListTile(
        leading: const Icon(Icons.satellite_alt_outlined, color: Colors.white),
        title: const Text('Análisis NDVI', style: TextStyle(color: Colors.white)),
        onTap: () => _openPage(const ActivitiesPage(title: 'Análisis NDVI'), args: {'section':'ae'}),
      ),
    };
  }

  List<Widget> _buildDynamicMenuItems() {
    if (_isLoadingMenu) {
      return [const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))];
    }
    if (_menusPermitidosPorCategoria.isEmpty) return [];

    final allMenusMap = _buildAllMenuItems();
    final List<Widget> menuWidgets = [];

    // Orden fijo: PEI -> CEI -> AE
    final orden = <String>[
      'Producción e Investigación',
      'Calidad e Inocuidad',
      'Actividades Especializadas',
    ];
    final categoriasOrdenadas = <String>[
      ...orden,
      ..._menusPermitidosPorCategoria.keys.where((k) => !orden.contains(k)),
    ];

    for (final categoria in categoriasOrdenadas) {
      if (!_menusPermitidosPorCategoria.containsKey(categoria)) continue;
      final menus = _menusPermitidosPorCategoria[categoria]!;
      if (menus.isEmpty) continue;

      late final String keyId;
      late final IconData icon;
      late bool expanded;
      late void Function(bool) setExpanded;

      if (categoria == 'Producción e Investigación') {
        keyId = 'prod_inv';
        icon = Icons.agriculture_outlined;
        expanded = _expProdInv;
        setExpanded = (v) => _expProdInv = v;
      } else if (categoria == 'Calidad e Inocuidad') {
        keyId = 'cal_inoc';
        icon = Icons.verified_outlined;
        expanded = _expCalInoc;
        setExpanded = (v) => _expCalInoc = v;
      } else if (categoria == 'Actividades Especializadas') {
        keyId = 'act_esp';
        icon = Icons.biotech_outlined;
        expanded = _expActEsp;
        setExpanded = (v) => _expActEsp = v;
      } else {
        keyId = categoria.toLowerCase().replaceAll(' ', '_');
        icon = Icons.category_outlined;
        expanded = false;
        setExpanded = (_) {};
      }

      final children = menus.map((menuId) {
        return allMenusMap[menuId] ?? const SizedBox.shrink();
      }).toList();

      if (children.whereType<ListTile>().isEmpty) continue;

      menuWidgets.add(
        _topExpansion(
          keyId: keyId,
          expanded: expanded,
          onChanged: (v) => setExpanded(v),
          icon: icon,
          title: categoria,
          children: children,
        ),
      );
    }

    // === Bloque fijo: Riego (debajo de A.E.) ===
    if (_permisoValido('riego')) {
      menuWidgets.add(
        _topExpansion(
          keyId: 'riego',
          expanded: _expRiego,
          onChanged: (v) => _expRiego = v,
          icon: Icons.water_drop,
          title: 'Riego',
          children: [
            ListTile(
              leading: const Icon(Icons.opacity, color: Colors.white),
              title: const Text('Riego', style: TextStyle(color: Colors.white)),
              onTap: () {
                if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                  Navigator.of(context).pop();
                }
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RiegoPage()),
                ).then((_) => _resetRailToDashboard());
              },
            ),
          ],
        ),
      );
    }

    return menuWidgets;
  }

  // ===== Lógica de reset al volver de submenús =====

  String _computeDashboardKey() {
    if (_currentTitle == 'Dashboard General' && _permisoValido('dashboard_general')) {
      return 'dashboard_general';
    }
    if (_currentTitle == 'Dashboard P.e.I' && _permisoValido('dashboard_pei')) {
      return 'dashboard_pei';
    }
    if (_currentTitle == 'Dashboard C.e.I' && _permisoValido('dashboard_cei')) {
      return 'dashboard_cei';
    }
    if (_currentTitle == 'Dashboard A.E' && _permisoValido('dashboard_ae')) {
      return 'dashboard_ae';
    }
    if (_permisoValido('dashboard_general')) return 'dashboard_general';
    if (_permisoValido('dashboard_pei')) return 'dashboard_pei';
    if (_permisoValido('dashboard_cei')) return 'dashboard_cei';
    if (_permisoValido('dashboard_ae')) return 'dashboard_ae';
    return '';
  }

  void _resetRailToDashboard() {
    setState(() {
      _expProdInv = false;
      _expCalInoc = false;
      _expActEsp = false;
      _expRiego = false;
      _expServicios = false;
      _selectedTopKey = _computeDashboardKey();
    });
  }

  void _setBody(Widget body, String title) {
    if (!mounted) return;
    setState(() {
      _currentBody = body;
      _currentTitle = title;
      if (title == 'Dashboard General') _selectedTopKey = 'dashboard_general';
      if (title == 'Dashboard P.e.I')   _selectedTopKey = 'dashboard_pei';
      if (title == 'Dashboard C.e.I')   _selectedTopKey = 'dashboard_cei';
      if (title == 'Dashboard A.E')     _selectedTopKey = 'dashboard_ae';
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _openPage(Widget page, {Map<String, dynamic>? args}) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    Navigator.of(context)
        .push(MaterialPageRoute(
      settings: RouteSettings(arguments: args),
      builder: (_) => page,
    ))
        .then((_) => _resetRailToDashboard());
  }

  void _openEndDrawer() => _scaffoldKey.currentState?.openEndDrawer();

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _permisos.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        Map<String, dynamic>? userData;
        if (snapshot.hasData && snapshot.data!.exists) {
          userData = snapshot.data!.data()!;
          _permisos = userData['permisos'] as Map<String, dynamic>? ?? {};
          _unidadSeleccionada = userData['unidadSeleccionada'] as String? ?? 'No asignada';
          _cultivoSeleccionado = userData['cultivoSeleccionado'] as String? ?? 'No asignado';
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            backgroundColor: const Color(0xFF151f28),
            elevation: 0,
            centerTitle: false,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              _currentTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            actions: [
              // (Se removió la flecha del AppBar; ahora vive en el header del Drawer)
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.orange),
                onPressed: _openEndDrawer,
                tooltip: 'Notificaciones',
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.account_circle_outlined, color: Colors.orange),
                onSelected: (value) {
                  if (value == 'personal') {
                    _openPage(const PersonalInfoPage());
                  } else if (value == 'ayuda') {
                    _openPage(const HelpPage());
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'personal', child: Text('Información Personal')),
                  PopupMenuItem(value: 'ayuda', child: Text('Ayuda')),
                ],
              ),
              const SizedBox(width: 12),
            ],
          ),

          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerHeader(userData), // ← flecha está aquí dentro

                  if (_permisoValido('dashboard_general'))
                    _topItem(
                      keyId: 'dashboard_general',
                      icon: Icons.dashboard_outlined,
                      title: 'Dashboard General',
                      onTap: () => _setBody(const DashboardGeneralPage(), 'Dashboard General'),
                    ),
                  if (_permisoValido('dashboard_pei'))
                    _topItem(
                      keyId: 'dashboard_pei',
                      icon: Icons.dashboard_customize_outlined,
                      title: 'Dashboard P.e.I',
                      onTap: () => _setBody(const DashboardPeiPage(), 'Dashboard P.e.I'),
                    ),
                  if (_permisoValido('dashboard_cei'))
                    _topItem(
                      keyId: 'dashboard_cei',
                      icon: Icons.dashboard_customize,
                      title: 'Dashboard C.e.I',
                      onTap: () => _setBody(const DashboardCeiPage(), 'Dashboard C.e.I'),
                    ),
                  if (_permisoValido('dashboard_ae'))
                    _topItem(
                      keyId: 'dashboard_ae',
                      icon: Icons.dashboard_customize_rounded,
                      title: 'Dashboard A.E',
                      onTap: () => _setBody(const DashboardActividadesEspecializadasPage(), 'Dashboard A.E'),
                    ),

                  if (_menusPermitidosPorCategoria.isNotEmpty)
                    ..._buildDynamicMenuItems(),

                  if (_permisoValido('servicios_internos'))
                    _topExpansion(
                      keyId: 'servicios',
                      expanded: _expServicios,
                      onChanged: (v) => _expServicios = v,
                      icon: Icons.home_repair_service_outlined,
                      title: 'Servicios Internos',
                      children: [
                        if (_permisoValido('servicios_internos/equipos_pequenos'))
                          ListTile(
                            leading: const Icon(Icons.build_outlined, color: Colors.white),
                            title: const Text('Equipos Pequeños', style: TextStyle(color: Colors.white)),
                            onTap: () => _openPage(const EquiposPequenosPage()),
                          ),
                        if (_permisoValido('servicios_internos/equipos_grandes'))
                          ListTile(
                            leading: const Icon(Icons.agriculture_outlined, color: Colors.white),
                            title: const Text('Equipos Grandes', style: TextStyle(color: Colors.white)),
                            onTap: () => _openPage(const EquiposGrandesPage()),
                          ),
                        if (_permisoValido('servicios_internos/materiales'))
                          ListTile(
                            leading: const Icon(Icons.widgets_outlined, color: Colors.white),
                            title: const Text('Materiales', style: TextStyle(color: Colors.white)),
                            onTap: () => _openPage(const MaterialesPage()),
                          ),
                        if (_permisoValido('servicios_internos/registro_usuario'))
                          ListTile(
                            leading: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white),
                            title: const Text('Registro de usuario', style: TextStyle(color: Colors.white)),
                            onTap: () => _openPage(const RegistroUsuarioPage()),
                          ),
                        if (_permisoValido('servicios_internos/registro_unidades'))
                          ListTile(
                            leading: const Icon(Icons.yard_outlined, color: Colors.white),
                            title: const Text('Registro de Unidades de Siembra', style: TextStyle(color: Colors.white)),
                            onTap: () => _openPage(const RegistroUnidadesSiembraPage()),
                          ),
                        if (_permisoValido('servicios_internos/registro_implementos'))
                          ListTile(
                            leading: const Icon(Icons.precision_manufacturing_outlined, color: Colors.white),
                            title: const Text('Registro de Implementos', style: TextStyle(color: Colors.white)),
                            onTap: () => _openPage(const RegistroImplementosPage()),
                          ),
                      ],
                    ),

                  if (_permisoValido('planeacion'))
                    ListTile(
                      leading: const Icon(Icons.timeline_outlined, color: Colors.white),
                      title: const Text('Planeación', style: TextStyle(color: Colors.white)),
                      onTap: () => _openPage(const PlaneacionPage()),
                    ),

                  if (_permisoValido('servicio_dron'))
                    ListTile(
                      leading: const Icon(Icons.flight_takeoff, color: Colors.white),
                      title: const Text('Servicio de DRON', style: TextStyle(color: Colors.white)),
                      onTap: () => _openPage(const ServicioDronPage()),
                    ),

                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                    child: Row(
                      children: [
                        Expanded(child: SizedBox(height: 75, child: Image.asset('IMG/Copia de Don Raul-3.png', fit: BoxFit.contain))),
                        Container(width: 1, height: 60, color: Colors.grey.shade400, margin: const EdgeInsets.symmetric(horizontal: 5)),
                        Expanded(child: SizedBox(height: 95, child: Image.asset('IMG/Norca.png', fit: BoxFit.contain))),
                      ],
                    ),
                  ),

                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: Colors.white),
                    title: const Text('Configuración', style: TextStyle(color: Colors.white)),
                    onTap: () => _openPage(const ActivitiesPage(title: 'Configuración')),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white),
                    title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      FirebaseAuth.instance.signOut();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                            (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          endDrawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const ListTile(
                    title: Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.campaign_outlined),
                    title: const Text('Avisos'),
                    onTap: () => _openPage(const NotificationAvisoPage()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.message_outlined),
                    title: const Text('Mensajes'),
                    onTap: () => _openPage(const NotificationMensajePage()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Recordatorios'),
                    onTap: () => _openPage(const NotificationRecordatorioPage()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.task_alt_outlined),
                    title: const Text('Tareas Pendientes'),
                    onTap: () => _openPage(const NotificationTareaPendientePage()),
                  ),
                ],
              ),
            ),
          ),

          body: _currentBody,
          backgroundColor: Colors.white,
        );
      },
    );
  }

  // --- HEADER DEL DRAWER ---
  Widget _buildDrawerHeader(Map<String, dynamic>? data) {
    data ??= {};
    final nombre = data['nombre'] as String? ?? 'Nombre de Usuario';
    final puesto = data['puesto'] as String? ?? 'Puesto no asignado';

    ImageProvider avatarProvider;
    final photoUrl = data['photoUrl'] as String?;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      avatarProvider = NetworkImage(photoUrl);
    } else {
      avatarProvider = const AssetImage('IMG/agronomo-digital-1.jpg');
    }

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2AE2E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 40, backgroundImage: avatarProvider),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(puesto, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Color(0xFF151f28), fontSize: 14),
                    children: [
                      const TextSpan(text: 'Unidad: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: _unidadSeleccionada),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Color(0xFF151f28), fontSize: 13),
                    children: [
                      const TextSpan(text: 'Cultivo: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: _cultivoSeleccionado),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 1),
          // ← Flecha dentro del header (al lado de la foto / datos)
          Material(
            color: Colors.orangeAccent,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF151f28)),
              tooltip: 'Selector de Contexto',
              onPressed: () {
                // Cierra el Drawer y navega
                if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                  Navigator.of(_scaffoldKey.currentContext!).pop();
                }
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SelectorContextoPage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
