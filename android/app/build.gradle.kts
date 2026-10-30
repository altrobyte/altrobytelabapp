import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing for the APK handed to the team (android/key.properties, never committed). Without it a release build
// is signed with the debug key, which is fine on one test phone and wrong for the team: see docs/altrobyte_caller.md.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.example.altrobytelab"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.altrobytelab"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keyProps.isNotEmpty()) {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    // Two apps from one Flutter project. "lab" is the app this project always built. "caller" is Altrobyte Caller, the
    // telecallers' app (entry point lib/caller/caller_main.dart, native code and permissions in src/caller), installed
    // from a signed APK, never the Play Store.
    flavorDimensions += "app"
    productFlavors {
        create("lab") {
            dimension = "app"
        }
        create("caller") {
            dimension = "app"
            applicationId = "com.altrobyte.caller"
            minSdk = 26
        }
        // Altron, the founder's voice assistant: lib/founder_main.dart, manifest in src/altron.
        create("altron") {
            dimension = "app"
            applicationId = "com.altrobyte.altron"
            minSdk = 26
        }
        // Altrobyte Industrial on a plant's tablet: lib/industrial/industrial_main.dart, manifest in src/industrial.
        create("industrial") {
            dimension = "app"
            applicationId = "com.altrobyte.industrial"
            minSdk = 26
        }
    }

    buildTypes {
        release {
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = if (keyProps.isNotEmpty()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Altron listens for its name offline (WakeService): Vosk, only in the altron app.
    "altronImplementation"("net.java.dev.jna:jna:5.13.0@aar")
    "altronImplementation"("com.alphacephei:vosk-android:0.3.47@aar")
}
