import 'package:go_router/go_router.dart';
import 'package:agro_app/splash_screen.dart' as legacy_splash;
import 'package:agro_app/home_page.dart' as legacy_home;

import '../core/router/app_routes.dart';
import '../features/laboreo/reporte_actividad_laboreo_profundo.dart';
import '../features/laboreo/reporte_actividad_laboreo_superficial.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const legacy_splash.SplashScreen(
        next: legacy_home.HomePage(),
      ),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const legacy_home.HomePage(),
    ),
    GoRoute(
      path: AppRoutes.reporteLaboreoProfundo,
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! LaboreoProfundoArgs) {
          throw ArgumentError('LaboreoProfundoArgs requerido');
        }
        return ReporteActividadLaboreoProfundoPage(args: extra);
      },
    ),
    GoRoute(
      path: AppRoutes.reporteLaboreoSuperficial,
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! LaboreoSuperficialArgs) {
          throw ArgumentError('LaboreoSuperficialArgs requerido');
        }
        return ReporteActividadLaboreoSuperficialPage(args: extra);
      },
    ),
  ],
);
