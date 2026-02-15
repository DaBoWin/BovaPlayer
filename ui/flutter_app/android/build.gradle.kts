allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 解决依赖冲突
configurations.all {
    resolutionStrategy {
        force("org.checkerframework:checker-qual:3.42.0")
        force("com.google.guava:guava:32.1.3-android")
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
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
