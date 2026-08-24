import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// ------------------------------------------------------------
// Load release keystore properties
// ------------------------------------------------------------

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.abirdev.playbits"

    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.abirdev.playbits"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --------------------------------------------------------
    // Release signing
    // --------------------------------------------------------

//    signingConfigs {
//        create("release") {
//            keyAlias = keystoreProperties["keyAlias"] as String
//            keyPassword = keystoreProperties["keyPassword"] as String
//            storePassword = keystoreProperties["storePassword"] as String
//
//            storeFile = keystoreProperties["storeFile"]?.let {
//                file(it)
//            }
//        }
//    }

    // --------------------------------------------------------
    // Build types
    // --------------------------------------------------------

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// ------------------------------------------------------------
// Kotlin
// ------------------------------------------------------------

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// ------------------------------------------------------------
// Flutter
// ------------------------------------------------------------

flutter {
    source = "../.."
}