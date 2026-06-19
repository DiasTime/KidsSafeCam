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
subprojects {
    project.evaluationDependsOn(":app")
}

// flutter_webrtc 0.12.x hard-codes compileSdkVersion 31, but its AndroidX
// transitive dependencies now require compiling against 34+. Force every Android
// subproject (the plugins) up to the app's compileSdk. Reflection keeps this
// resilient across Android Gradle Plugin DSL changes.
fun Project.forceCompileSdk36() {
    val androidExt = extensions.findByName("android") ?: return
    val methods = androidExt.javaClass.methods
    val current = methods
        .firstOrNull { it.name == "getCompileSdk" && it.parameterTypes.isEmpty() }
        ?.invoke(androidExt) as? Int
    if (current == null || current < 36) {
        methods
            .firstOrNull { it.name == "setCompileSdk" && it.parameterTypes.size == 1 }
            ?.invoke(androidExt, 36)
    }
}

subprojects {
    // The sibling evaluationDependsOn(":app") above can evaluate some projects
    // eagerly, so guard against registering afterEvaluate on an evaluated one.
    if (state.executed) forceCompileSdk36() else afterEvaluate { forceCompileSdk36() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
