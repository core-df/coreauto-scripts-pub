plugins { kotlin("jvm") version "2.0.21" }
group = "com.coredf"; version = "1.0.0"
repositories { mavenCentral() }
dependencies {
    implementation("com.sun.mail:jakarta.mail:2.0.1")
}
kotlin { jvmToolchain(11) }
