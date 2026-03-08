allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    tasks.withType<JavaCompile> {
        sourceCompatibility = "11"
        targetCompatibility = "11"
        options.compilerArgs.add("-Xlint:-options")
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Ensures the app module is evaluated before the subprojects
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

buildscript {
    val kotlinVersion = "2.1.0"  // Kotlin version
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle plugin version
        classpath("com.android.tools.build:gradle:8.7.0")  // Ensure compatibility with your Gradle version
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
        // Flutter Gradle plugin, add if missing:
    }
}

tasks.withType<JavaCompile> {
    sourceCompatibility = "11"
    targetCompatibility = "11"
    options.compilerArgs.add("-Xlint:-options")
}
