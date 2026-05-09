plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.focus_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.focus_app"
        // API 23: Permission-Runtime-Dialog, BLUETOOTH_CONNECT ohne Legacy-Workaround
        // API 21 würde für BLE reichen, aber permission_handler + flutter_foreground_task brauchen 23
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: eigene Signing-Config für Release eintragen
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}
