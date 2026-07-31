import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.pluginManager.withPlugin("com.android.library") {
        project.extensions.configure<BaseExtension> {
            compileSdkVersion(34)
        }
    }
    project.pluginManager.withPlugin("com.android.application") {
        project.extensions.configure<BaseExtension> {
            compileSdkVersion(34)
        }
    }
}
