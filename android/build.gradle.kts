import com.android.build.api.dsl.CommonExtension
import org.gradle.api.plugins.JavaPluginExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile

plugins {
    java
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    extensions.findByName("android")?.let { extension ->
        if (extension is CommonExtension<*, *, *, *, *>) {
            extension.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    tasks.withType<KotlinJvmCompile>().configureEach {
        compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
    }

    extensions.findByType(JavaPluginExtension::class.java)?.toolchain?.languageVersion?.set(
        JavaLanguageVersion.of(17)
    )
}
subprojects {
    project.evaluationDependsOn(":app")
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
