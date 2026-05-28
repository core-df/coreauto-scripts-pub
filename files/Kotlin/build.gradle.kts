plugins { kotlin("jvm") version "2.0.21" }
group = "com.coredf"; version = "1.0.0"
repositories { mavenCentral() }
dependencies {
    implementation("com.github.mwiede:jsch:0.2.21")
}
kotlin { jvmToolchain(11) }
