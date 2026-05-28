plugins { kotlin("jvm") version "2.0.21" }
group = "com.coredf"; version = "1.0.0"
repositories { mavenCentral() }
dependencies {
    implementation("io.nats:jnats:2.17.2")
}
kotlin { jvmToolchain(11) }
