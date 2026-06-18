allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Flutter plugins (e.g. path_provider_android 2.2.19) declare AGP 8.12.1 in
    // their own buildscript, which exceeds Flutter 3.29.2 support (max AGP 8.7.x).
    // Force the app-level AGP so all subprojects resolve a single compatible version.
    buildscript {
        configurations.configureEach {
            if (name == "classpath") {
                resolutionStrategy.force("com.android.tools.build:gradle:8.7.0")
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
