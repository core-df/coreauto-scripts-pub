plugins { kotlin("jvm") version "2.0.21" }
group = "com.coredf"; version = "1.0.0"
repositories { mavenCentral() }
dependencies {
    implementation("software.amazon.awssdk:s3:2.25.27")
}
kotlin { jvmToolchain(11) }
