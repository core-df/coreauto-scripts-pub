plugins {
    kotlin("jvm") version "2.0.21"
}

group = "com.coredf"
version = "1.0.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.apache.kafka:kafka-clients:3.7.0")
}

kotlin {
    jvmToolchain(11)
}
