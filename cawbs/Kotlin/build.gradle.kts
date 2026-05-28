plugins {
    kotlin("jvm") version "2.0.21"
}

group = "com.coredf"
version = "1.0.0"

repositories {
    mavenCentral()
}

kotlin {
    jvmToolchain(11)
}
