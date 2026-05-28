plugins { kotlin("jvm") version "2.0.21" }
group = "com.coredf"; version = "1.0.0"
repositories { mavenCentral() }
dependencies {
    implementation("com.azure:azure-messaging-servicebus:7.15.0")
}
kotlin { jvmToolchain(11) }
