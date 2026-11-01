import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningFile = file(System.getenv("FCOURT_SIGNING_PROPERTIES_FILE") ?: "${rootProject.projectDir}/key.properties")
val releaseSigningProperties = Properties().apply {
    if (releaseSigningFile.exists()) releaseSigningFile.reader(Charsets.UTF_8).use { load(it) }
}

val validateFcourtReleaseSigning by tasks.registering {
    doLast {
        check(releaseSigningFile.isFile) { "FCOURT release signing requires an external signing properties file" }
        for (key in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
            check(!releaseSigningProperties.getProperty(key).isNullOrEmpty()) { "FCOURT release signing requires $key" }
        }
        check(file(releaseSigningProperties.getProperty("storeFile")).isFile) { "FCOURT release keystore file is missing" }
    }
}

tasks.matching { it.name == "preReleaseBuild" || it.name == "assembleRelease" || it.name == "bundleRelease" || it.name == "validateSigningRelease" }
    .configureEach { dependsOn(validateFcourtReleaseSigning) }

android {
    namespace = "com.bro73.fcourt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bro73.fcourt"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = releaseSigningProperties.getProperty("keyAlias")
            keyPassword = releaseSigningProperties.getProperty("keyPassword")
            storePassword = releaseSigningProperties.getProperty("storePassword")
            storeFile = releaseSigningProperties.getProperty("storeFile")?.let { file(it) }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
