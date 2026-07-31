import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    fun Project.applyAndroidConfig() {
        extensions.findByType(BaseExtension::class.java)?.apply {
            compileSdkVersion(35)
        }
    }
    if (state.executed) {
        applyAndroidConfig()
    } else {
        afterEvaluate {
            applyAndroidConfig()
        }
    }
}
