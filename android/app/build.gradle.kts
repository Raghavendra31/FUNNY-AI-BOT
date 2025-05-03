plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.funny_bot"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Set NDK version
    // If you need to update or manage other NDK versions, consider keeping the flutter.ndkVersion reference.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Specify your own unique Application ID
        applicationId = "com.example.funny_bot"
        // Flutter SDK version settings
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Update with your own signing configuration for release
            signingConfig = signingConfigs.getByName("debug") // Change for actual release
        }
    }
}

flutter {
    source = "../.."  // Ensure this points to the correct Flutter source directory
}
