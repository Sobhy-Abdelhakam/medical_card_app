plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

// Load MAPS_API_KEY from local.properties or environment
val localProps = Properties().apply {
    val propsFile = rootProject.file("local.properties")
    if (propsFile.exists()) {
        FileInputStream(propsFile).use { load(it) }
    }
}

val mapsApiKey: String = (localProps.getProperty("MAPS_API_KEY") ?: System.getenv("MAPS_API_KEY") ?: "").trim()

// --- Load signing properties from local.properties (recommended) ---
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.medical_card"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.euromedicalcard.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }

        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
    create("release") {
        storeFile = file(keystoreProperties["storeFile"] ?: "new-upload-key.jks")
        storePassword = keystoreProperties["storePassword"]?.toString() ?: "YOUR_STORE_PASSWORD"
        keyAlias = keystoreProperties["keyAlias"]?.toString() ?: "upload"
        keyPassword = keystoreProperties["keyPassword"]?.toString() ?: "YOUR_KEY_PASSWORD"
    }
    }


    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            signingConfig = signingConfigs.getByName("release") // optional: use same key for debug builds
        }
    }

    packagingOptions {
        jniLibs.useLegacyPackaging = false
    }
}

flutter {
    source = "../.."
}
