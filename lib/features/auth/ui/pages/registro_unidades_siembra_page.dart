// lib/features/auth/ui/pages/registro_unidades_siembra_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Rail con estilo “Servicios Internos”
import '../../../../widgets/mini_icon_rail_scaffold.dart';

// Navegación entre pantallas del mismo segmento (ajusta si tus rutas reales difieren)
import 'equipos_pequenos_page.dart' show EquiposPequenosPage;
import 'equipos_grandes_page.dart' show EquiposGrandesPage;
import 'materiales_page.dart' show MaterialesPage;
import 'registro_usuario_page.dart' show RegistroUsuarioPage;
import 'registro_implementos_page.dart' show RegistroImplementosPage;

/// Color corporativo solicitado
const Color colorNaranjaAgro = Color(0xFFF2AE2E);

/// Colores locales para evitar blanco sobre blanco en este DART, independientemente del tema global.
const _kOnBgHigh = Color(0xFF111111);
const _kOnBgMed = Color(0xFF555555);
const _kTileBg = Color(0xFFF6F6F8);
const _kCardBg = Colors.white;

/// ===================================================================
/// =============  LISTA TOMADA DEL RAIL (MISMO ID)  ==================
/// ===================================================================
/// Orden fijo: Producción (pei), Calidad (cei), Fertilización (fe)

const Map<String, String> _kCategoryTitles = {
  'pei': 'Producción e Investigación',
  'cei': 'Calidad e Inocuidad',
  'fe' : 'Fertilización Especializada',
};

// ——— ORDEN PEI EXACTO SOLICITADO ———
const List<_SubItem> _PEI = [
  _SubItem('registro_terrenos', 'Registro de Terrenos agrícolas', Icons.map_outlined),
  _SubItem('preparacion_suelos', 'Preparación de Suelos', Icons.landscape_outlined),
  _SubItem('siembra_fertilizacion', 'Siembra y Fertilización', Icons.grass_outlined),
  _SubItem('fertilizaciones_granulares', 'Fertilizaciones Granulares', Icons.inventory_outlined),
  _SubItem('cosecha', 'Cosecha', Icons.agriculture_outlined),
];

// ——— CEI SIN CAMBIOS ———
const List<_SubItem> _CEI = [
  _SubItem('analisis_suelo', 'Análisis de Suelo', Icons.analytics_outlined),
  _SubItem('verif_compactacion', 'Verificación de Compactación', Icons.speed_outlined),
  _SubItem('verif_germinacion', 'Verificación de Germinación', Icons.grass),
  _SubItem('inst_equipos', 'Instalación de Equipos de Medición', Icons.podcasts_outlined),
  _SubItem('analisis_malezas', 'Análisis de Malezas', Icons.eco_outlined),
  _SubItem('analisis_nutrientes', 'Análisis de Nutrientes', Icons.science_outlined),
  _SubItem('seguimiento_humedad', 'Seguimiento de Humedad', Icons.water_drop_outlined),
];

// ——— ORDEN FE EXACTO SOLICITADO ———
// Importante: IDs únicos con sufijo _Dron para distinguir de PEI/CEI
const List<_SubItem> _FE = [
  _SubItem('control_malezas', 'Control de Malezas', Icons.local_florist_outlined),
  _SubItem('aplicaciones_foliares_plagas_enfermedades', 'Aplicaciones Foliares - Plagas - Enfermedades', Icons.bug_report_outlined),
  _SubItem('fertilizaciones_granulares_Dron', 'Fertilizaciones Granulares', Icons.inventory_outlined),
  _SubItem('verif_germinacion_Dron', 'Verificación de Germinación', Icons.grass),
  _SubItem('analisis_ndvi', 'Análisis NDVI', Icons.satellite_alt_outlined),
];

class RegistroUnidadesSiembraPage extends StatefulWidget {
  const RegistroUnidadesSiembraPage({super.key});

  @override
  State<RegistroUnidadesSiembraPage> createState() => _RegistroUnidadesSiembraPageState();
}

class _RegistroUnidadesSiembraPageState extends State<RegistroUnidadesSiembraPage> {
  int _activeContent = 0; // 0 = Cultivos, 1 = Unidades

  List<RailItem> _railItems(BuildContext context) {
    return [
      RailItem(
        icon: Icons.construction_outlined,
        tooltip: 'Equipos Pequeños',
        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EquiposPequenosPage())),
      ),
      RailItem(
        icon: Icons.precision_manufacturing_outlined,
        tooltip: 'Equipos Grandes',
        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EquiposGrandesPage())),
      ),
      RailItem(
        icon: Icons.widgets_outlined,
        tooltip: 'Materiales',
        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MaterialesPage())),
      ),
      RailItem(
        icon: Icons.person_add_alt_1_outlined,
        tooltip: 'Registro de usuario',
        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegistroUsuarioPage())),
      ),
      RailItem(
        icon: Icons.yard_outlined,
        tooltip: 'Registro de Unidades de Siembra',
        onTap: () {},
      ),
      RailItem(
        icon: Icons.agriculture_outlined,
        tooltip: 'Registro de Implementos',
        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegistroImplementosPage())),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localTheme = theme.copyWith(
      scaffoldBackgroundColor: _kTileBg,
      cardColor: _kCardBg,
      iconTheme: const IconThemeData(color: _kOnBgHigh),
      textTheme: theme.textTheme.apply(
        displayColor: _kOnBgHigh,
        bodyColor: _kOnBgHigh,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorNaranjaAgro;
          return _kOnBgMed;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        floatingLabelStyle: const TextStyle(color: colorNaranjaAgro),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: colorNaranjaAgro, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _kOnBgMed.withOpacity(.4)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        backgroundColor: _kTileBg,
        collapsedBackgroundColor: _kTileBg,
        textColor: _kOnBgHigh,
        collapsedTextColor: _kOnBgHigh,
        iconColor: _kOnBgHigh,
        collapsedIconColor: _kOnBgHigh,
      ),
    );

    return Theme(
      data: localTheme,
      child: MiniIconRailScaffold(
        title: 'Registro de Unidades de Siembra',
        items: _railItems(context),
        currentIndex: 4,
        block: AppBlock.servicios,
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              _TopTabs(
                leftSelected: _activeContent == 0,
                onLeft: () => setState(() => _activeContent = 0),
                onRight: () => setState(() => _activeContent = 1),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _activeContent == 0
                      ? const _RegistroCultivosCard(key: ValueKey('cultivos'))
                      : const _RegistroUnidadesCard(key: ValueKey('unidades')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------------
/// Pestaña: REGISTRO DE CULTIVOS
/// ------------------------------
class _RegistroCultivosCard extends StatefulWidget {
  const _RegistroCultivosCard({super.key});

  @override
  State<_RegistroCultivosCard> createState() => _RegistroCultivosCardState();
}

class _RegistroCultivosCardState extends State<_RegistroCultivosCard> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  /// Selecciones (submenús). Clave: submenu:<pei|cei|fe>/<idSubmenu>
  final Map<String, bool> _sel = <String, bool>{};

  bool _isEditing = false;
  String? _editingCultivoId;

  // Bundles provenientes del “rail” (IDs alineados con home_page.dart/activities)
  late final List<_MenuBundle> _bundles;

  @override
  void initState() {
    super.initState();
    // Inicializar bundles una sola vez
    _bundles = [
      _MenuBundle('pei', _kCategoryTitles['pei']!, _PEI),
      _MenuBundle('cei', _kCategoryTitles['cei']!, _CEI),
      _MenuBundle('fe', _kCategoryTitles['fe']!, _FE), // <-- FE con IDs *_Dron
    ];
    _resetSelections();
  }

  void _resetSelections() {
    _sel.clear();
    for (final b in _bundles) {
      for (final s in b.items) {
        _sel['submenu:${b.key}/${s.id}'] = false;
      }
    }
  }

  // Normaliza claves antiguas -> nuevas *_Dron
  String _normalizeMenuKey(String k) {
    if (k == 'submenu:fe/fertilizaciones_granulares') {
      return 'submenu:fe/fertilizaciones_granulares_Dron';
    }
    if (k == 'submenu:fe/verif_germinacion') {
      return 'submenu:fe/verif_germinacion_Dron';
    }
    return k;
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCultivoParaEditar(String cultivoId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('cultivos_catalog').doc(cultivoId).get();
      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró el cultivo.')));
        return;
      }

      final data = doc.data()!;
      final menusRaw = List<String>.from(data['menus'] ?? const []);

      setState(() {
        _idCtrl.text = doc.id;
        _titleCtrl.text = data['title']?.toString() ?? '';

        _resetSelections();
        for (final raw in menusRaw) {
          final k = _normalizeMenuKey(raw); // <-- compat hacia *_Dron
          _sel[k] = true;
        }
        _isEditing = true;
        _editingCultivoId = doc.id;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar cultivo: $e')));
    }
  }

  Future<void> _guardarCultivo() async {
    if (!_formKey.currentState!.validate()) return;

    final id = _idCtrl.text.trim();
    final title = _titleCtrl.text.trim();

    if (id.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa ID y Título.')));
      return;
    }

    final isNew = !_isEditing;
    if (isNew) {
      final exists = await FirebaseFirestore.instance.collection('cultivos_catalog').doc(id).get();
      if (exists.exists) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('El ID "$id" ya existe.')));
        return;
      }
    }

    // Guardamos SÓLO submenús seleccionados, normalizando FE -> *_Dron y quitando duplicados
    final Set<String> selected = <String>{};
    _sel.forEach((k, v) {
      if (v == true && (k.startsWith('submenu:pei/') || k.startsWith('submenu:cei/') || k.startsWith('submenu:fe/'))) {
        selected.add(_normalizeMenuKey(k));
      }
    });

    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('cultivos_catalog').doc(id).set({
      'title': title,
      'menus': selected.toList(), // sin duplicados
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNew && user != null) 'creatorUid': user.uid,
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isNew ? 'Cultivo guardado.' : 'Cambios guardados.')));
    _limpiarCultivoForm();
  }

  Future<void> _eliminarCultivo(String cultivoId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cultivo'),
        content: Text('¿Eliminar "$cultivoId"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar == true) {
      await FirebaseFirestore.instance.collection('cultivos_catalog').doc(cultivoId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cultivo eliminado.')));
      _limpiarCultivoForm();
    }
  }

  void _limpiarCultivoForm() {
    setState(() {
      _idCtrl.clear();
      _titleCtrl.clear();
      _resetSelections();
      _isEditing = false;
      _editingCultivoId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // *** Una sola columna: Formulario → Menús (pei, cei, fe) → Catálogo ***
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --------- Formulario principal (ID y Título) ---------
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _idCtrl,
                            decoration: const InputDecoration(labelText: 'ID de cultivo'),
                            readOnly: _isEditing,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(labelText: 'Título'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --------- Menús y Submenús (orden fijo: pei, cei, fe) ---------
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Menús y Submenús',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _kOnBgHigh)),
                    ),
                    const SizedBox(height: 8),
                    ..._buildMenus(),

                    const SizedBox(height: 16),
                    // Botonera en Wrap para evitar overflows
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        if (_isEditing)
                          OutlinedButton.icon(
                            onPressed: () => _eliminarCultivo(_editingCultivoId!),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Eliminar'),
                          ),
                        TextButton(onPressed: _limpiarCultivoForm, child: const Text('Limpiar')),
                        FilledButton.icon(
                          onPressed: _guardarCultivo,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_isEditing ? 'Guardar modificación' : 'Guardar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // --------- Catálogo de Cultivos (HASTA ABAJO) ---------
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Catálogo de Cultivos',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const Divider(height: 1),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('cultivos_catalog')
                      .orderBy('title')
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: ${snap.error}'),
                      );
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay cultivos registrados.'),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final d = docs[i];
                        final id = d.id;
                        final title = d.data()['title']?.toString() ?? id;
                        return ListTile(
                          leading: const Icon(Icons.eco_outlined, color: _kOnBgHigh),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: _kOnBgHigh)),
                          subtitle: Text(id, style: const TextStyle(color: _kOnBgMed)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit_outlined, color: _kOnBgHigh),
                                onPressed: () => _cargarCultivoParaEditar(id),
                              ),
                              IconButton(
                                tooltip: 'Borrar',
                                icon: const Icon(Icons.delete_outline, color: _kOnBgHigh),
                                onPressed: () => _eliminarCultivo(id),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenus() {
    return _bundles.map((bundle) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _kTileBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kOnBgMed.withOpacity(.2)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: Icon(
              bundle.key == 'pei'
                  ? Icons.agriculture_outlined
                  : bundle.key == 'cei'
                  ? Icons.verified_outlined
                  : Icons.biotech_outlined,
              color: _kOnBgHigh,
            ),
            title: Text(
              bundle.title,
              style: const TextStyle(fontWeight: FontWeight.w700, color: _kOnBgHigh),
            ),
            children: [
              if (bundle.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Sin submenús configurados.', style: TextStyle(color: _kOnBgMed)),
                ),
              if (bundle.items.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: bundle.items.map((s) {
                    final key = 'submenu:${bundle.key}/${s.id}';
                    final checked = _sel[key] ?? false;
                    return FilterChip(
                      label: Text(s.title, style: const TextStyle(color: _kOnBgHigh)),
                      selected: checked,
                      onSelected: (v) => setState(() => _sel[key] = v),
                      selectedColor: colorNaranjaAgro.withOpacity(.15),
                      side: BorderSide(color: (checked ? colorNaranjaAgro : _kOnBgMed.withOpacity(.3))),
                      avatar: Icon(s.icon, size: 18, color: checked ? colorNaranjaAgro : _kOnBgMed),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    }).toList();
  }
}

/// ------------------------------
/// Pestaña: REGISTRO DE UNIDADES
/// ------------------------------
class _RegistroUnidadesCard extends StatefulWidget {
  const _RegistroUnidadesCard({super.key});

  @override
  State<_RegistroUnidadesCard> createState() => _RegistroUnidadesCardState();
}

class _RegistroUnidadesCardState extends State<_RegistroUnidadesCard> {
  final _formKey = GlobalKey<FormState>();
  final _unidadIdCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  final _hectareasCtrl = TextEditingController();

  /// Secciones dinámicas
  final List<_SeccionData> _secciones = [];

  /// Catálogo de cultivos y selección
  final Map<String, bool> _cultivosSeleccionados = <String, bool>{};
  final List<_CultivoCatalogoItem> _catalogo = [];

  bool _isEditing = false;
  String? _editingUnidadId;

  @override
  void initState() {
    super.initState();
    _cargarCatalogoCultivos();
  }

  Future<void> _cargarCatalogoCultivos() async {
    final snap = await FirebaseFirestore.instance.collection('cultivos_catalog').orderBy('title').get();
    setState(() {
      _catalogo
        ..clear()
        ..addAll(
          snap.docs.map((d) => _CultivoCatalogoItem(id: d.id, title: d.data()['title']?.toString() ?? d.id)).toList(),
        );
      _cultivosSeleccionados
        ..clear()
        ..addEntries(_catalogo.map((e) => MapEntry(e.id, false)));
    });
  }

  @override
  void dispose() {
    _unidadIdCtrl.dispose();
    _nombreCtrl.dispose();
    _dirCtrl.dispose();
    _hectareasCtrl.dispose();
    for (final s in _secciones) {
      s.disposeControllers();
    }
    super.dispose();
  }

  void _agregarSeccion() {
    final nextIndex = _secciones.length + 1;
    setState(() {
      _secciones.add(_SeccionData(name: 'Sección $nextIndex', hectareas: null));
    });
  }

  double _sumaSecciones() {
    return _secciones.fold<double>(0.0, (p, s) => p + (s.hectareas ?? 0));
  }

  Future<void> _guardarUnidad() async {
    if (!_formKey.currentState!.validate()) return;

    final id = _unidadIdCtrl.text.trim();
    final nombre = _nombreCtrl.text.trim();
    final direccion = _dirCtrl.text.trim();

    if (id.isEmpty || nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa ID y Nombre.')));
      return;
    }

    final isNew = !_isEditing;
    if (isNew) {
      final exists = await FirebaseFirestore.instance.collection('unidades_catalog').doc(id).get();
      if (exists.exists) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('El ID "$id" ya existe.')));
        return;
      }
    }

    // Suma de secciones => hectáreas finales
    final suma = _sumaSecciones();
    final seleccionados = _cultivosSeleccionados.entries.where((e) => e.value).map((e) => e.key).toList();

    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('unidades_catalog').doc(id).set({
      'nombre': nombre,
      'direccion': direccion,
      'hectareas': suma, // forzamos coincidir con la suma
      'secciones': _secciones.map((s) => {'name': s.name, 'hectareas': s.hectareas ?? 0}).toList(),
      'cultivos': seleccionados,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNew && user != null) 'creatorUid': user.uid,
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unidad guardada.')));
    _limpiarUnidadForm();
  }

  Future<void> _cargarUnidadParaEditar(String unidadId) async {
    final d = await FirebaseFirestore.instance.collection('unidades_catalog').doc(unidadId).get();
    if (!d.exists) return;

    final data = d.data()!;
    final cultivos = List<String>.from(data['cultivos'] ?? const []);
    final secciones = List<Map<String, dynamic>>.from(data['secciones'] ?? const []);

    setState(() {
      _unidadIdCtrl.text = d.id;
      _nombreCtrl.text = data['nombre']?.toString() ?? '';
      _dirCtrl.text = data['direccion']?.toString() ?? '';
      _hectareasCtrl.text = (data['hectareas'] as num?)?.toString() ?? '';

      for (final s in _secciones) {
        s.disposeControllers();
      }
      _secciones
        ..clear()
        ..addAll(
          secciones
              .map(
                (m) => _SeccionData(
              name: m['name']?.toString() ?? 'Sección',
              hectareas: (m['hectareas'] as num?)?.toDouble(),
            ),
          )
              .toList(),
        );

      _cultivosSeleccionados.updateAll((key, value) => false);
      for (final c in cultivos) {
        if (_cultivosSeleccionados.containsKey(c)) _cultivosSeleccionados[c] = true;
      }

      _isEditing = true;
      _editingUnidadId = d.id;
    });
  }

  void _limpiarUnidadForm() {
    setState(() {
      _unidadIdCtrl.clear();
      _nombreCtrl.clear();
      _dirCtrl.clear();
      _hectareasCtrl.clear();
      for (final s in _secciones) {
        s.disposeControllers();
      }
      _secciones.clear();
      _cultivosSeleccionados.updateAll((key, value) => false);
      _isEditing = false;
      _editingUnidadId = null;
    });
  }

  Future<void> _eliminarUnidad(String unidadId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar unidad'),
        content: Text('¿Eliminar la unidad "$unidadId"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('unidades_catalog').doc(unidadId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unidad eliminada.')));
      if (_isEditing && _editingUnidadId == unidadId) _limpiarUnidadForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sum = _sumaSecciones();
    final topHect = double.tryParse(_hectareasCtrl.text.replaceAll(',', '.')) ?? 0;
    final coincide = (sum - topHect).abs() < 0.0001;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // --------- Formulario Unidad ---------
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _unidadIdCtrl,
                            readOnly: _isEditing,
                            decoration: const InputDecoration(labelText: 'ID de unidad'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _nombreCtrl,
                            decoration: const InputDecoration(labelText: 'Nombre'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dirCtrl,
                      decoration: const InputDecoration(labelText: 'Dirección (opcional)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _hectareasCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cantidad de Hectáreas',
                        suffixIcon: coincide
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.error_outline, color: Colors.orange),
                        helperText: 'Al guardar se ajusta a la suma de Secciones.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // --- Secciones ---
                    Row(
                      children: [
                        const Text('Secciones', style: TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _agregarSeccion,
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('Agregar sección'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_secciones.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kTileBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kOnBgMed.withOpacity(.2)),
                        ),
                        child: const Text('Aún no hay secciones. Agrega la primera.'),
                      ),
                    if (_secciones.isNotEmpty)
                      Column(
                        children: List.generate(_secciones.length, (i) {
                          final s = _secciones[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _kTileBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _kOnBgMed.withOpacity(.2)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Nombre (flexible para evitar overflow)
                                    Expanded(
                                      child: TextFormField(
                                        controller: s.nameCtrl,
                                        decoration: const InputDecoration(labelText: 'Nombre de la sección'),
                                        onChanged: (v) => s.name = v,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Hectáreas (flexible para pantallas chicas)
                                    Flexible(
                                      child: TextFormField(
                                        controller: s.hectCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                                        decoration: const InputDecoration(labelText: 'Hectáreas'),
                                        onChanged: (v) {
                                          s.hectareas = double.tryParse(v.replaceAll(',', '.'));
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          final removed = _secciones.removeAt(i);
                                          removed.disposeControllers();
                                        });
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Eliminar sección',
                                    )
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Suma de secciones: ${sum.toStringAsFixed(2)} ha',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: coincide ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // --- Cultivos Disponibles para las Unidades ---
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Cultivos Disponibles para las Unidades',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kTileBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kOnBgMed.withOpacity(.2)),
                      ),
                      child: _catalogo.isEmpty
                          ? const Text('No hay cultivos en el catálogo.')
                          : Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _catalogo.map((c) {
                          final sel = _cultivosSeleccionados[c.id] ?? false;
                          return ChoiceChip(
                            label: Text(c.title),
                            selected: sel,
                            onSelected: (v) => setState(() => _cultivosSeleccionados[c.id] = v),
                            selectedColor: colorNaranjaAgro.withOpacity(.15),
                            side: BorderSide(color: (sel ? colorNaranjaAgro : _kOnBgMed.withOpacity(.3))),
                            avatar: Icon(Icons.eco_outlined, size: 18, color: sel ? colorNaranjaAgro : _kOnBgMed),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Botonera en Wrap para evitar overflows cuando _isEditing = true
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        if (_isEditing)
                          OutlinedButton.icon(
                            onPressed: () => _eliminarUnidad(_editingUnidadId!),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Eliminar'),
                          ),
                        TextButton(onPressed: _limpiarUnidadForm, child: const Text('Limpiar')),
                        FilledButton.icon(
                          onPressed: _guardarUnidad,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_isEditing ? 'Actualizar' : 'Guardar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // --------- Catálogo de Unidades ---------
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Catálogo de Unidades',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const Divider(height: 1),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('unidades_catalog')
                      .orderBy('nombre')
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: ${snap.error}'),
                      );
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay unidades registradas.'),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final d = docs[i];
                        final data = d.data();
                        final id = d.id;
                        final nombre = data['nombre']?.toString() ?? id;
                        final direccion = data['direccion']?.toString() ?? '';
                        final hect = (data['hectareas'] as num?)?.toDouble() ?? 0;
                        final cultivos = List<String>.from(data['cultivos'] ?? const []);
                        final secciones = List<Map<String, dynamic>>.from(data['secciones'] ?? const []);
                        final detalleSecciones = secciones
                            .map((s) => '${s['name']}: ${(s['hectareas'] as num?)?.toString() ?? '0'} ha')
                            .join(' • ');

                        return ListTile(
                          tileColor: _kCardBg,
                          leading: const Icon(Icons.yard_outlined, color: _kOnBgHigh),
                          title: Text(nombre,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: _kOnBgHigh)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(id, style: const TextStyle(color: _kOnBgMed, fontSize: 12)),
                              if (direccion.isNotEmpty) Text(direccion, style: const TextStyle(color: _kOnBgHigh)),
                              if (hect > 0)
                                Text('${hect.toStringAsFixed(2)} ha',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: _kOnBgHigh)),
                              if (secciones.isNotEmpty)
                                Text('Secciones: $detalleSecciones', style: const TextStyle(color: _kOnBgMed)),
                              if (cultivos.isNotEmpty)
                                Text('Cultivos: ${cultivos.join(', ')}',
                                    style: const TextStyle(color: _kOnBgMed)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit_outlined, color: _kOnBgHigh),
                                onPressed: () => _cargarUnidadParaEditar(id),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(Icons.delete_outline, color: _kOnBgHigh),
                                onPressed: () => _eliminarUnidad(id),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  const _TopTabs({required this.leftSelected, required this.onLeft, required this.onRight});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TopIconTab(
            selected: leftSelected,
            icon: Icons.spa_outlined,
            label: 'Reg. Cultivos',
            onTap: onLeft,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TopIconTab(
            selected: !leftSelected,
            icon: Icons.yard_outlined,
            label: 'Reg. Unidades',
            onTap: onRight,
          ),
        ),
      ],
    );
  }
}

class _TopIconTab extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TopIconTab({required this.selected, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? colorNaranjaAgro.withOpacity(.15) : _kTileBg;
    final border = selected ? colorNaranjaAgro : _kOnBgMed.withOpacity(.3);
    final color = selected ? colorNaranjaAgro : _kOnBgHigh;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuBundle {
  final String key; // pei | cei | fe
  final String title;
  final List<_SubItem> items;
  const _MenuBundle(this.key, this.title, this.items);
}

class _SubItem {
  final String id;
  final String title;
  final IconData icon;
  const _SubItem(this.id, this.title, this.icon);
}

class _CultivoCatalogoItem {
  final String id;
  final String title;
  const _CultivoCatalogoItem({required this.id, required this.title});
}

class _SeccionData {
  String name;
  double? hectareas;

  // Controllers para edición fluida
  final TextEditingController nameCtrl;
  final TextEditingController hectCtrl;

  _SeccionData({required this.name, required this.hectareas})
      : nameCtrl = TextEditingController(text: name),
        hectCtrl = TextEditingController(text: hectareas?.toString());

  void disposeControllers() {
    nameCtrl.dispose();
    hectCtrl.dispose();
  }
}
