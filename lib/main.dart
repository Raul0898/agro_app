// lib/main.dart
import 'dart:io' show Platform;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';

import 'features/auth/ui/login_page.dart';
import 'features/auth/ui/pages/selector_contexto_page.dart';
import 'firebase_options.dart';
import 'home_page.dart';
import 'splash_screen.dart';
import 'routes/app_router.dart';

/// ========= PALETA CORPORATIVA =========
class AppColors {
  static const white = Color(0xFFFFFFFF); // Blanco puro
  static const brandOrange = Color(0xFFF2AE2E); // Naranja corporativo
  static const gray100 = Color(0xFFE5E5E5); // Gris claro (fondos tarjetas)
  static const gray300 = Color(0xFFC9C9C9); // Gris medio (divisores, texto secundario)
  static const gray900 = Color(0xFF2C2C2C); // Gris oscuro (sidebar, menús)
  static const petroBlue = Color(0xFF0F4C75); // Azul petróleo (gráficos, títulos sec.)
  static const steelBlue = Color(0xFF3282B8); // Azul grisáceo (indicadores, métricas)

  static const onBrandOrange = Colors.black;
  static const onDark = Colors.white;
}

/// Transiciones suaves para toda la app
class _SoftTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final slideTween = Tween<Offset>(begin: const Offset(0.015, 0), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOut));

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: animation.drive(slideTween),
        child: child,
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔐 App Check
  try {
    if (kIsWeb) {
      // await FirebaseAppCheck.instance.activate(
      //   webProvider: ReCaptchaV3Provider('TU_SITE_KEY_V3'),
      // );
    } else if (Platform.isAndroid) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      await FirebaseAppCheck.instance.activate(
        appleProvider: AppleProvider.deviceCheck,
      );
    }
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  } catch (_) {}

  runApp(const AgroApp());
}

class AgroApp extends StatelessWidget {
  const AgroApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTransitions = const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _SoftTransitionsBuilder(),
        TargetPlatform.iOS: _SoftTransitionsBuilder(),
        TargetPlatform.linux: _SoftTransitionsBuilder(),
        TargetPlatform.macOS: _SoftTransitionsBuilder(),
        TargetPlatform.windows: _SoftTransitionsBuilder(),
      },
    );

    /// ======= COLOR SCHEME CLARO =======
    const lightScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brandOrange,
      onPrimary: AppColors.onBrandOrange,
      secondary: AppColors.petroBlue,
      onSecondary: Colors.white,
      tertiary: AppColors.steelBlue,
      onTertiary: Colors.white,
      error: Color(0xFFB00020),
      onError: Colors.white,
      background: AppColors.white,
      onBackground: AppColors.gray900,
      surface: AppColors.white,
      onSurface: AppColors.gray900,
      surfaceVariant: AppColors.gray100,
      onSurfaceVariant: AppColors.gray900,
      outline: AppColors.gray300,
      shadow: Colors.black,
      scrim: Colors.black87,
      inverseSurface: AppColors.gray900,
      onInverseSurface: Colors.white,
      inversePrimary: AppColors.petroBlue,
    );

    /// ======= COLOR SCHEME OSCURO =======
    const darkScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.brandOrange,
      onPrimary: AppColors.onBrandOrange,
      secondary: AppColors.steelBlue,
      onSecondary: Colors.white,
      tertiary: AppColors.petroBlue,
      onTertiary: Colors.white,
      error: Color(0xFFCF6679),
      onError: Colors.black,
      background: AppColors.gray900,
      onBackground: Colors.white,
      surface: AppColors.gray900,
      onSurface: Colors.white,
      surfaceVariant: Color(0xFF3B3B3B),
      onSurfaceVariant: Colors.white,
      outline: AppColors.gray300,
      shadow: Colors.black,
      scrim: Colors.black87,
      inverseSurface: AppColors.white,
      onInverseSurface: AppColors.gray900,
      inversePrimary: AppColors.steelBlue,
    );

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: lightScheme,
      scaffoldBackgroundColor: lightScheme.background,
      pageTransitionsTheme: baseTransitions,
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF151f28),
        surfaceTintColor: Colors.transparent,
        scrimColor: Colors.white10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightScheme.background,
        foregroundColor: lightScheme.onBackground,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.2,
          color: AppColors.gray900,
        ),
        iconTheme: IconThemeData(color: lightScheme.onBackground),
      ),
      cardTheme: CardThemeData(
        color: lightScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.gray100),
        ),
      ),
      dividerColor: AppColors.gray300,
      iconTheme: IconThemeData(color: lightScheme.onSurface),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStatePropertyAll(lightScheme.primary),
          foregroundColor: MaterialStatePropertyAll(lightScheme.onPrimary),
          elevation: const MaterialStatePropertyAll(0),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          textStyle: const MaterialStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStatePropertyAll(lightScheme.secondary),
          side: MaterialStatePropertyAll(BorderSide(color: lightScheme.secondary)),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          textStyle: const MaterialStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStatePropertyAll(lightScheme.secondary),
          textStyle: const MaterialStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightScheme.surfaceVariant,
        hintStyle: const TextStyle(color: AppColors.gray300),
        labelStyle: TextStyle(color: lightScheme.onSurface),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: lightScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: lightScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: lightScheme.secondary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightScheme.surfaceVariant,
        labelStyle: TextStyle(color: lightScheme.onSurface),
        selectedColor: lightScheme.tertiary.withOpacity(0.15),
        side: BorderSide(color: lightScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.gray900),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.gray900),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.gray900),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gray900),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.gray900),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.gray900),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFFFFFFFF),
        textColor: Colors.white,
        selectedColor: Color(0xFFF2AE2E),
        selectedTileColor: Color(0xFFF2AE2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        textColor: Colors.white,
        collapsedTextColor: Colors.white,
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: lightScheme.secondary,
        linearTrackColor: lightScheme.tertiary.withOpacity(0.25),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: lightScheme.secondary,
        inactiveTrackColor: lightScheme.tertiary.withOpacity(0.25),
        thumbColor: lightScheme.secondary,
      ),
      hoverColor: const Color(0x1FF2AE2E),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFFFFFFF),
        thickness: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        textStyle: const TextStyle(color: Colors.black),
        iconColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF767B83), width: 1),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const MaterialStatePropertyAll(Colors.white),
          surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
          elevation: const MaterialStatePropertyAll(4),
          shadowColor: const MaterialStatePropertyAll(Colors.transparent),
          side: const MaterialStatePropertyAll(
            BorderSide(color: Color(0xFFE5E5E5), width: 1),
          ),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );

    final darkTheme = ThemeData(
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.gray900,
        surfaceTintColor: Colors.transparent,
        scrimColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: darkScheme,
      scaffoldBackgroundColor: darkScheme.background,
      pageTransitionsTheme: baseTransitions,
      appBarTheme: AppBarTheme(
        backgroundColor: darkScheme.surface,
        foregroundColor: darkScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.2,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: darkScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: darkScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: darkScheme.surfaceVariant),
        ),
      ),
      dividerColor: AppColors.gray300.withOpacity(0.25),
      iconTheme: IconThemeData(color: darkScheme.onSurface),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStatePropertyAll(darkScheme.primary),
          foregroundColor: MaterialStatePropertyAll(darkScheme.onPrimary),
          elevation: const MaterialStatePropertyAll(0),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          textStyle: const MaterialStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStatePropertyAll(darkScheme.tertiary),
          side: MaterialStatePropertyAll(BorderSide(color: darkScheme.tertiary)),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          textStyle: const MaterialStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStatePropertyAll(darkScheme.tertiary),
          textStyle: const MaterialStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkScheme.surfaceVariant,
        hintStyle: const TextStyle(color: AppColors.gray300),
        labelStyle: TextStyle(color: darkScheme.onSurface),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: darkScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: darkScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: darkScheme.tertiary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkScheme.surfaceVariant,
        labelStyle: TextStyle(color: darkScheme.onSurface),
        selectedColor: darkScheme.secondary.withOpacity(0.25),
        side: BorderSide(color: darkScheme.outline.withOpacity(0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white,
        textColor: Colors.white,
        selectedColor: AppColors.brandOrange,
        selectedTileColor: Color(0x1FF2AE2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        textColor: Colors.white,
        collapsedTextColor: Colors.white,
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: darkScheme.tertiary,
        linearTrackColor: darkScheme.secondary.withOpacity(0.25),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: darkScheme.tertiary,
        inactiveTrackColor: darkScheme.secondary.withOpacity(0.25),
        thumbColor: darkScheme.tertiary,
      ),
      hoverColor: const Color(0xFFF2AE2E),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF2AE2E),
        thickness: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFFF2AE2E),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: const TextStyle(color: Colors.black),
        iconColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFF2AE2E), width: 4),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const MaterialStatePropertyAll(Color(0xFFF2AE2E)),
          surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
          elevation: const MaterialStatePropertyAll(0),
          shadowColor: const MaterialStatePropertyAll(Colors.transparent),
          side: const MaterialStatePropertyAll(
            BorderSide(color: Color(0xFFF2AE2E), width: 4),
          ),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );

    return MaterialApp(
      title: 'Agro App',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: lightTheme,
      darkTheme: darkTheme,
      initialRoute: '/',
      onGenerateRoute: appRouter(
        authGateBuilder: (_) => const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnap.data;

        if (user == null) {
          return const LoginPage();
        }

        return const SelectorContextoPage();
      },
    );
  }
}
