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




tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


        }
    }
}
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.BaseExtension> {
            compileSdkVersion(34)
        }
    }
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.gradle.BaseExtension> {
            compileSdkVersion(34)
        }
    }
}
