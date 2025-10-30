import java.io.File
import org.gradle.api.tasks.compile.JavaCompile

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.agro_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.agro_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

flutter {
    source = "../.."
}

tasks.withType<JavaCompile>().configureEach {
    val buildDirPath = layout.buildDirectory.get().asFile.toPath()
    val flutterGeneratedMarker = "${File.separator}io${File.separator}flutter${File.separator}plugins${File.separator}GeneratedPluginRegistrant"

    doFirst {
        val sourceFiles = source.files
        // The Flutter tooling generates Java registrant stubs that may invoke deprecated
        // plugin APIs. Keep lint checks active for our own sources while silencing the
        // warning noise from those generated files (which we cannot edit).
        val onlyGeneratedSources = sourceFiles.isNotEmpty() && sourceFiles.all { file ->
            val normalizedPath = file.toPath().toAbsolutePath().normalize()
            normalizedPath.startsWith(buildDirPath) ||
                normalizedPath.toString().contains(flutterGeneratedMarker)
        }

        options.compilerArgs.removeAll(listOf("-Xlint:deprecation", "-Xlint:unchecked", "-Xlint:-deprecation"))

        if (onlyGeneratedSources) {
            options.compilerArgs.add("-Xlint:-deprecation")
        } else {
            options.compilerArgs.addAll(listOf("-Xlint:deprecation", "-Xlint:unchecked"))
        }
    }
}
