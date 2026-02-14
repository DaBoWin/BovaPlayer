allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // 为所有子项目添加 Flutter 配置支持
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            
            // 添加 flutter 扩展属性以兼容旧插件
            android.apply {
                if (!extensions.extraProperties.has("flutter")) {
                    extensions.extraProperties.set("flutter", mapOf(
                        "compileSdkVersion" to 35,
                        "minSdkVersion" to 21,
                        "targetSdkVersion" to 35,
                        "ndkVersion" to "26.1.10909125",
                        "versionCode" to 1,
                        "versionName" to "1.0.0"
                    ))
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
