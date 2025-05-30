plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.funny_bot"  // Your app's namespace
    compileSdk = 35  // Set to your desired compile SDK version (e.g., 33 for Android 13)
    ndkVersion = "27.2.12479018"  // Set NDK version if required

    defaultConfig {
        applicationId = "com.example.funny_bot"
        minSdk = 21  // Set your minimum SDK version
        targetSdk = 35  // Set your target SDK version
        versionCode = 1  // Increment with each release
        versionName = "1.0.0"  // Your version name
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")  // Update signing configuration for release
        }
    }
}

flutter {
    source = "../.."  // Ensure this points to your Flutter source directory
}
