plugins { kotlin("jvm") version "2.0.21" }
group = "com.coredf"; version = "1.0.0"
repositories { mavenCentral() }
dependencies {
    implementation("com.google.cloud:google-cloud-pubsub:1.129.6")
}
kotlin { jvmToolchain(11) }
