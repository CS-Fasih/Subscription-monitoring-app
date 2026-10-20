plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingEnvironment = mapOf(
    "storeFile" to System.getenv("TALLY_KEYSTORE_PATH"),
    "storePassword" to System.getenv("TALLY_KEYSTORE_PASSWORD"),
    "keyAlias" to System.getenv("TALLY_KEY_ALIAS"),
    "keyPassword" to System.getenv("TALLY_KEY_PASSWORD"),
)
val hasReleaseSigning = signingEnvironment.values.all { !it.isNullOrBlank() }
val requestsRelease = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val missingSigningMessage = "Release signing is required. Set TALLY_KEYSTORE_PATH, TALLY_KEYSTORE_PASSWORD, TALLY_KEY_ALIAS and TALLY_KEY_PASSWORD in your secure build environment. See README.md."
if (requestsRelease && !hasReleaseSigning) {
    throw GradleException(missingSigningMessage)
}

// Aggregate tasks such as assemble/build also select release tasks. Check the
// resolved graph before execution, while leaving debug-only builds available.
gradle.taskGraph.whenReady {
    if (!hasReleaseSigning && allTasks.any {
            it.project == project && it.name.contains("release", ignoreCase = true)
        }) {
        throw GradleException(missingSigningMessage)
    }
}

android {
    namespace = "app.tally.tally"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "app.tally.tally"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("production") {
                storeFile = file(signingEnvironment.getValue("storeFile")!!)
                storePassword = signingEnvironment.getValue("storePassword")
                keyAlias = signingEnvironment.getValue("keyAlias")
                keyPassword = signingEnvironment.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("production")
            }
        }
    }
}

flutter {
    source = "../.."
}
