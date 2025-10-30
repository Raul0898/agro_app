import 'package:flutter/material.dart';

import '../core/router/app_routes.dart';
import '../features/laboreo/reporte_actividad_laboreo_profundo.dart';
import '../features/laboreo/reporte_actividad_laboreo_superficial.dart';
import '../home_page.dart';
import '../splash_screen.dart';

/// Builds the route factory used throughout the app.
///
/// Keeping the logic here allows `main.dart` to remain lean while preserving
/// the existing Navigator 1.0 flow (Splash -> AuthGate/Home and reporte pages).
RouteFactory appRouter({
  required WidgetBuilder authGateBuilder,
}) {
  return (RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SplashScreen(next: HomePage()),
        );
      case '/home':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomePage(),
        );
      case AppRoutes.reporteLaboreoProfundo:
        final args = settings.arguments;
        if (args is! LaboreoProfundoArgs) {
          throw ArgumentError('LaboreoProfundoArgs requerido');
        }
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => ReporteActividadLaboreoProfundoPage(args: args),
        );
      case AppRoutes.reporteLaboreoSuperficial:
        final args = settings.arguments;
        if (args is! LaboreoSuperficialArgs) {
          throw ArgumentError('LaboreoSuperficialArgs requerido');
        }
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => ReporteActividadLaboreoSuperficialPage(args: args),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: authGateBuilder,
        );
    }
  };
}
