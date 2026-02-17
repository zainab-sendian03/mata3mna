buildscript {
    repositories {
        // Try mirrors first since Google's servers are having connection issues
        maven {
            url = uri("https://maven.aliyun.com/repository/google")
            isAllowInsecureProtocol = false
        }
        maven {
            url = uri("https://maven.aliyun.com/repository/central")
            isAllowInsecureProtocol = false
        }
        // Additional Chinese mirrors as fallback
        maven {
            url = uri("https://mirrors.cloud.tencent.com/nexus/repository/maven-public/")
            isAllowInsecureProtocol = false
        }
        // Try Google repositories (may timeout, but needed for some plugins)
        maven {
            url = uri("https://dl.google.com/dl/android/maven2/")
            isAllowInsecureProtocol = false
        }
        google()
        mavenCentral()
    }
}

allprojects {
    repositories {
        // Prioritize mirror repositories first (for regions with connection issues)
        maven {
            url = uri("https://maven.aliyun.com/repository/google")
            isAllowInsecureProtocol = false
        }
        maven {
            url = uri("https://maven.aliyun.com/repository/central")
            isAllowInsecureProtocol = false
        }
        // Fallback to official repositories
        google()
        mavenCentral()
    }
}

// تغيير مكان مجلد build (اختياري)
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
    