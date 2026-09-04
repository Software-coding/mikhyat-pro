import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // Flutter Gradle Plugin يجب أن يجي بعد Android و Kotlin
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()

if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    val requiredKeys = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
    val missing = requiredKeys.filter { keystoreProperties[it]?.toString().isNullOrBlank() }
    if (missing.isNotEmpty()) {
        throw GradleException("Missing release signing properties: ${missing.joinToString()}")
    }
}

val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

android {
    namespace = "com.mikhyat.mikhyat_pro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mikhyat.mikhyat_pro"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else if (releaseRequested) {
                throw GradleException(
                    "Release signing is not configured. Copy android/key.properties.example " +
                        "to android/key.properties and configure your private keystore."
                )
            }
        }
    }
}

kotlin {
    jvmToolchain(17)
}

flutter {
    source = "../.."
}
