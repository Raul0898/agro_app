import org.gradle.api.tasks.Delete
import org.gradle.api.tasks.compile.JavaCompile

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
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (name != "app") {
        tasks.withType<JavaCompile>().configureEach {
            options.compilerArgs.removeAll(listOf("-Xlint:-options"))
        }
    }
}

tasks.named<Delete>("clean").configure {
    delete(rootProject.layout.buildDirectory)
}
