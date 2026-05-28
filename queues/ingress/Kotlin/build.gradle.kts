plugins {
    kotlin("jvm") version "2.0.21"
}

group = "com.coredf"
version = "1.0.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation(files("../../../cawbs/Kotlin/build/libs/cawbs-1.0.0.jar"))
}

kotlin {
    jvmToolchain(11)
}
