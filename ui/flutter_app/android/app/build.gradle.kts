plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.bova_player_flutter"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.bova_player_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    // 排除重复的依赖
    packagingOptions {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0",
                "META-INF/*.kotlin_module"
            )
        }
        // 允许重复的类文件（选择第一个）
        jniLibs {
            pickFirsts += setOf("**/*.so")
        }
        dex {
            useLegacyPackaging = false
        }
    }
}

dependencies {
    // SMB 支持所需依赖
    implementation("eu.agno3.jcifs:jcifs-ng:2.1.10")
    
    // MPV Android 播放器（包含完整的 FFmpeg）
    implementation("is.xyz.mpv:libmpv:latest.release")

    // 强制使用统一版本的依赖，避免冲突
    constraints {
        implementation("org.checkerframework:checker-qual:3.42.0") {
            because("解决多个版本冲突")
        }
        implementation("com.google.guava:guava:32.1.3-android") {
            because("解决多个版本冲突")
        }
    }
}

flutter {
    source = "../.."
}

// 强制所有配置使用统一版本
configurations.all {
    resolutionStrategy {
        force("org.checkerframework:checker-qual:3.42.0")
        force("com.google.guava:guava:32.1.3-android")
        force("com.google.code.findbugs:jsr305:3.0.2")
    }
}
