import 'package:go_router/go_router.dart';
import 'package:agro_app/splash_screen.dart' as legacy_splash;
import 'package:agro_app/home_page.dart' as legacy_home;

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
  ],
);
