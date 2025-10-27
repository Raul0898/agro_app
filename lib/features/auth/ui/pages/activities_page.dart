// lib/features/auth/ui/pages/activities_page.dart
import 'package:flutter/material.dart';

// ========= Shell / Layout con sub-rail =========
import 'package:agro_app/widgets/mini_icon_rail_scaffold.dart'; // AppBlock, RailItem

// ========= Páginas existentes (ejemplos) =========
import 'package:agro_app/features/auth/ui/pages/registro_terrenos_page.dart';
import 'package:agro_app/features/auth/ui/pages/analisis_suelo_page.dart';
import 'package:agro_app/features/auth/ui/pages/preparacion_suelos_page.dart';
import 'package:agro_app/features/auth/ui/pages/verificacion_compactacion_page.dart';

// ========= FERTILIZACIÓN ESPECIALIZADA =========
import 'package:agro_app/features/auth/ui/pages/control_malezas_page.dart';
import 'package:agro_app/features/auth/ui/pages/aplicaciones_foliares_plagas_page.dart';
import 'package:agro_app/features/auth/ui/pages/fertilizaciones_granulares_dron_page.dart';
import 'package:agro_app/features/auth/ui/pages/verificacion_germinacion_dron_page.dart';
import 'package:agro_app/features/auth/ui/pages/analisis_ndvi_page.dart';

// ========= Versiones NO-DRON para PEI/CEI =========
import 'package:agro_app/features/auth/ui/pages/fertilizaciones_granulares_page.dart';
import 'package:agro_app/features/auth/ui/pages/verificacion_germinacion_page.dart';

// ✅ Import para ir a Registro de Unidades de Siembra desde el sub-rail
import 'package:agro_app/features/auth/ui/pages/registro_unidades_siembra_page.dart' as reg_unidades;

class ActivitiesPage extends StatelessWidget {
  final String title;

  /// 'pei' | 'cei' | 'fe'  (Producción e Investigación, Calidad e Inocuidad, Fertilización Especializada)
  final String? sectionKey;

  const ActivitiesPage({super.key, required this.title, this.sectionKey});

  // ==== Dashboards (sin sub-rail) ====
  bool _isDashboardTitle(String t) =>
      t == 'Dashboard General' || t == 'Dashboard P.e.I' || t == 'Dashboard C.e.I';

  // ==== BLOQUE Fertilización Especializada ====
  static const List<String> _fertiTitles = <String>[
    'Control de Malezas',
    'Fertilizaciones Granulares',
    'Aplicaciones Foliares - Plagas - Enfermedades',
    'Verificación de Germinación',
    'Análisis NDVI',
  ];
  bool _isFertiTitle(String t) => _fertiTitles.contains(t);

  AppBlock _detectBlock(String s) {
    if (s == 'fe' || s == 'pei') return AppBlock.produccion;
    if (s == 'cei') return AppBlock.calidad;
    return AppBlock.servicios;
  }

  List<String> _titlesFor(String s) {
    if (s == 'pei') {
      return const <String>[
        'Registro de Terrenos agrícolas',
        'Preparación de Suelos',
        'Siembra y Fertilización',
        'Fertilizaciones Granulares', // NO-DRON aquí
        'Cosecha',
      ];
    }
    if (s == 'cei') {
      return const <String>[
        'Análisis de Suelo',
        'Verificación de Compactación',
        'Verificación de Germinación', // NO-DRON aquí
        'Instalación de Equipos de Medición',
        'Análisis de Malezas',
        'Análisis de Nutrientes',
        'Seguimiento de Humedad',
      ];
    }
    // 'fe'
    return _fertiTitles;
  }

  List<IconData> _iconsFor(String s) {
    if (s == 'pei') {
      return const <IconData>[
        Icons.map_outlined,
        Icons.landscape_outlined,
        Icons.grass_outlined,
        Icons.inventory_outlined,
        Icons.agriculture,
      ];
    }
    if (s == 'cei') {
      return const <IconData>[
        Icons.analytics_outlined,
        Icons.speed_outlined,
        Icons.grass,
        Icons.podcasts_outlined,
        Icons.eco_outlined,
        Icons.science_outlined,
        Icons.water_drop_outlined,
      ];
    }
    // 'fe'
    return const <IconData>[
      Icons.local_florist_outlined,  // Control de Malezas
      Icons.inventory_outlined,      // Fertilizaciones Granulares
      Icons.bug_report_outlined,     // Aplicaciones Foliares - Plagas - Enfermedades
      Icons.grass,                   // Verificación de Germinación
      Icons.satellite_alt_outlined,  // Análisis NDVI
    ];
  }

  /// Determina la sección efectiva:
  /// 1) `sectionKey` recibido
  /// 2) argumentos de ruta: ModalRoute.settings.arguments = {'section': 'pei'|'cei'|'fe'}
  /// 3) inferencia por título (si pertenece a FE, 'fe'; si no, 'pei'/'cei')
  String _resolveSectionKey(BuildContext context) {
    if (sectionKey != null && sectionKey!.isNotEmpty) return sectionKey!;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['section'] is String) {
      return (args['section'] as String);
    }

    if (_isFertiTitle(title)) return 'fe';

    const prod = <String>{
      'Registro de Terrenos agrícolas',
      'Preparación de Suelos',
      'Siembra y Fertilización',
      'Fertilizaciones Granulares',
      'Cosecha',
    };
    const cal = <String>{
      'Análisis de Suelo',
      'Verificación de Compactación',
      'Verificación de Germinación',
      'Instalación de Equipos de Medición',
      'Análisis de Malezas',
      'Análisis de Nutrientes',
      'Seguimiento de Humedad',
    };
    if (prod.contains(title)) return 'pei';
    if (cal.contains(title)) return 'cei';
    return 'pei';
  }

  Widget _placeholder(String t, BuildContext context) => Center(
    key: ValueKey(t),
    child: Text('Pantalla "$t" en construcción', style: Theme.of(context).textTheme.titleMedium),
  );

  // Cuerpo según título + sección (resuelve NO-DRON vs DRON)
  Widget _bodyForTitle(BuildContext context, String t, String s) {
    if (_isDashboardTitle(t)) {
      final text = (t == 'Dashboard General')
          ? 'En este Dashboard estará los avances de todas las actividades de forma de diagrama de flujo como se tiene en Canva con porcentajes y gráfica.'
          : 'En este Dashboard ira los avances en forma de concepto por actividad y porcentajes según avances.';
      return Center(
        key: ValueKey(t),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
      );
    }

    // FE (siempre DRON donde aplique)
    if (s == 'fe') {
      if (t == 'Control de Malezas') return const ControlMalezasPage();
      if (t == 'Aplicaciones Foliares - Plagas - Enfermedades') return const AplicacionesFoliaresPlagasPage();
      if (t == 'Fertilizaciones Granulares') return const FertilizacionesGranularesDronPage();
      if (t == 'Verificación de Germinación') return const VerificacionGerminacionDronPage();
      if (t == 'Análisis NDVI') return const AnalisisNdviPage();
    }

    // PEI (NO-DRON donde aplique)
    if (s == 'pei') {
      if (t == 'Fertilizaciones Granulares') return const FertilizacionesGranularesPage();
      if (t == 'Registro de Terrenos agrícolas') return const RegistroTerrenosBody();
      if (t == 'Preparación de Suelos') return const PreparacionSuelosPage();
      if (t == 'Siembra y Fertilización') return _placeholder(t, context);
      if (t == 'Cosecha') return _placeholder(t, context);
    }

    // CEI (NO-DRON donde aplique)
    if (s == 'cei') {
      if (t == 'Verificación de Germinación') return const VerificacionGerminacionPage();
      if (t == 'Análisis de Suelo' || t == 'Análisis de Nutrientes') return const AnalysisSoilPage();
      if (t == 'Verificación de Compactación') return const VerificacionCompactacionPage();
      if (t == 'Instalación de Equipos de Medición') return _placeholder(t, context);
      if (t == 'Análisis de Malezas') return _placeholder(t, context);
      if (t == 'Seguimiento de Humedad') return _placeholder(t, context);
    }

    return _placeholder(t, context);
  }

  @override
  Widget build(BuildContext context) {
    final s = _resolveSectionKey(context);
    final isDashboard = _isDashboardTitle(title);
    final block = _detectBlock(s);

    final titles = isDashboard ? const <String>[] : _titlesFor(s);
    final icons = isDashboard ? const <IconData>[] : _iconsFor(s);
    final currentIndex = isDashboard ? 0 : titles.indexOf(title);
    final body = _bodyForTitle(context, title, s);

    // etiqueta visible en el sub-rail (para FE): "F. Especializada"
    final String? sectionLabel = (s == 'fe') ? 'F. Especializada' : null;

    if (isDashboard) {
      // ✅ Agregamos el acceso directo a "Registro de Unidades de Siembra" en el sub-rail también en dashboards
      final items = <RailItem>[
        RailItem(
          icon: Icons.yard_outlined,
          tooltip: 'Registro de Unidades de Siembra',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const reg_unidades.RegistroUnidadesSiembraPage()),
            );
          },
        ),
      ];

      return MiniIconRailScaffold(
        title: title,
        items: items,
        currentIndex: 0,
        block: block,
        body: body,
        onSelect: (_) {},
        sectionLabel: sectionLabel,
      );
    }

    final items = <RailItem>[];
    for (var i = 0; i < titles.length; i++) {
      final t = titles[i];
      items.add(
        RailItem(
          icon: icons[i],
          tooltip: t,
          onTap: () {
            if (t == title) return;
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 220),
                settings: RouteSettings(arguments: {'section': s}),
                pageBuilder: (_, __, ___) => ActivitiesPage(title: t, sectionKey: s),
              ),
            );
          },
        ),
      );
    }

    // ✅ FIX: Añadimos el ítem extra solo para secciones distintas de PEI/CEI/FE.
    // En estas secciones (Servicios Internos, etc.) sí debe mostrarse el acceso
    // directo al Registro de Unidades de Siembra.
    if (s != 'pei' && s != 'cei' && s != 'fe') {
      items.add(
        RailItem(
          icon: Icons.yard_outlined,
          tooltip: 'Registro de Unidades de Siembra',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const reg_unidades.RegistroUnidadesSiembraPage()),
            );
          },
        ),
      );
    }

    return MiniIconRailScaffold(
      title: title,
      items: items,
      currentIndex: currentIndex < 0 ? 0 : currentIndex,
      block: block,
      body: body,
      onSelect: (i) {
        // Si el usuario toca el ítem extra (último), no hacemos navegación por índice
        if (i >= 0 && i < titles.length) {
          final t = titles[i];
          if (t == title) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 220),
              settings: RouteSettings(arguments: {'section': s}),
              pageBuilder: (_, __, ___) => ActivitiesPage(title: t, sectionKey: s),
            ),
          );
        }
      },
      sectionLabel: sectionLabel,
    );
  }
}
