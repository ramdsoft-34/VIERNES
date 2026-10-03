import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Se carga aquí y se aplica abajo solo si existe google-services.json.
    id("com.google.gms.google-services") apply false
}

// Cuentas con Google (Firebase): se activan al poner google-services.json en
// android/app/ (ver docs/CUENTAS.md). Sin ese archivo la app compila y
// funciona sin cuentas.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Firma de publicación: android/key.properties (no se sube a git).
// Ver docs/PUBLICACION.md. Sin ese archivo, release se firma con la clave debug.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.ramdsoft.viernes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Requerido por flutter_local_notifications (APIs de fecha de Java 8+).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ramdsoft.viernes"
        // Android 8.0+: canales de notificación y servicios en primer plano.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Necesario en AGP 9 para definir `app_name` por versión.
    buildFeatures {
        resValues = true
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Viernes Dev")
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "Viernes")
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Reglas para que R8 no elimine las clases nativas de Vosk/JNA.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-ktx:1.13.1")
    // Palabra de activación sin internet (Vosk usa JNA para su núcleo nativo).
    implementation("com.alphacephei:vosk-android:0.3.75") {
        // Se usa el .aar de JNA de abajo, que trae las bibliotecas nativas.
        exclude(group = "net.java.dev.jna")
    }
    implementation("net.java.dev.jna:jna:5.19.1@aar")
}
