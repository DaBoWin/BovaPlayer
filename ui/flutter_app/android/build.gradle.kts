allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 全局依赖解析策略
subprojects {
    afterEvaluate {
        configurations.all {
            resolutionStrategy {
                force("org.checkerframework:checker-qual:3.42.0")
                force("com.google.guava:guava:32.1.3-android")
                force("com.google.code.findbugs:jsr305:3.0.2")
                
                // 处理依赖冲突时优先使用最新版本
                preferProjectModules()
                
                // 缓存动态版本1小时
                cacheDynamicVersionsFor(1, "hours")
                cacheChangingModulesFor(0, "seconds")
            }
        }
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
    
    // 解决依赖冲突
    configurations.all {
        resolutionStrategy {
            force("org.checkerframework:checker-qual:3.42.0")
            force("com.google.guava:guava:32.1.3-android")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
