import com.android.build.gradle.BaseExtension
import com.android.build.gradle.BasePlugin

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    plugins.withType<BasePlugin> {
        configure<BaseExtension> {
            compileSdkVersion(34)
        }
    }
}
