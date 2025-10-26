// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Soporte web explícito
    if (kIsWeb) {
      // Si más adelante añades Web con `flutterfire configure --platforms=web`,
      // crea aquí un getter `web` y retorna `web`.
      throw UnsupportedError('DefaultFirebaseOptions no configuradas para Web.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
    // Si en el futuro agregas macOS o Linux, crea getters similares y añádelos aquí.
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no configuradas para esta plataforma.',
        );
    }
  }

  // ===== iOS (desde ios/Runner/GoogleService-Info.plist) =====
  static const FirebaseOptions ios = FirebaseOptions(
    appId: '1:10436733844:ios:598eede0f95c01bc9abd81',
    apiKey: 'AIzaSyDr1fZiCQ4XlFt199C8QCPybIve0St0HYA',
    projectId: 'agro-app-demo',
    messagingSenderId: '10436733844',
    storageBucket: 'agro-app-demo.firebasestorage.app',
    iosBundleId: 'com.rmac.agroapp',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDfBhFXhiEzd-MA6r1N2x3H7UOKNme-sTc',
    appId: '1:10436733844:android:53b67c1260c969989abd81',
    messagingSenderId: '10436733844',
    projectId: 'agro-app-demo',
    storageBucket: 'agro-app-demo.firebasestorage.app',
  );

  // ===== Android (google-services.json) =====

  // ===== Windows (TEMPORAL: usa los mismos valores que Android para poder ejecutar) =====
  //
  // ⚠️ Importante: Lo ideal es generar estos valores con:
  //   flutter pub global run flutterfire_cli:flutterfire configure --platforms=android,windows --out=lib/firebase_options.dart

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAB1iKZ_2QS--24bb1LR_jYYzVEKtPMx5k',
    appId: '1:10436733844:web:3fb689f917fcbb769abd81',
    messagingSenderId: '10436733844',
    projectId: 'agro-app-demo',
    authDomain: 'agro-app-demo.firebaseapp.com',
    storageBucket: 'agro-app-demo.firebasestorage.app',
  );

  // y reemplazar este bloque con el que te produzca la herramienta.
}