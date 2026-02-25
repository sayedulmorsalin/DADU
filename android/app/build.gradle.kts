import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException

// Load properties at the top level
val keystoreProperties = Properties()
val keystorePropertiesFile = project.file("key.properties")

if (!keystorePropertiesFile.exists()) {
    throw GradleException("Signing properties file not found at: ${keystorePropertiesFile.absolutePath}. Please ensure 'key.properties' is located in the 'android/app' directory and contains the required signing information.")
}
keystoreProperties.load(FileInputStream(keystorePropertiesFile))

// Validate properties
val keyAliasValue = keystoreProperties.getProperty("keyAlias")
val keyPasswordValue = keystoreProperties.getProperty("keyPassword")
val storeFileValue = keystoreProperties.getProperty("storeFile")
val storePasswordValue = keystoreProperties.getProperty("storePassword")

if (keyAliasValue == null || keyPasswordValue == null || storeFileValue == null || storePasswordValue == null) {
    throw GradleException("One or more signing properties are missing from key.properties. Make sure keyAlias, keyPassword, storeFile, and storePassword are all present in android/app/key.properties.")
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.sayedulmarsalin.dadu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    signingConfigs {
        create("release") {
            keyAlias = keyAliasValue
            keyPassword = keyPasswordValue
            storeFile = file(storeFileValue)
            storePassword = storePasswordValue
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.sayedulmarsalin.dadu"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.15.0"))
}
