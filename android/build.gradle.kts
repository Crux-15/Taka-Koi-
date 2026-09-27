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
}

// FIX: Force all plugins to use compileSdk 36 (needed for sqflite Android 16 BAKLAVA)
// Must be BEFORE evaluationDependsOn
subprojects {
    afterEvaluate {
        project.extensions.findByType<com.android.build.gradle.BaseExtension>()?.let { ext ->
            ext.compileSdkVersion(36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
