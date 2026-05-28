plugins { kotlin("jvm") version "2.0.21" }
group = "com.coredf"; version = "1.0.0"
repositories { mavenCentral() }
dependencies {
    implementation("com.ibm.mq:com.ibm.mq.allclient:9.3.5.0")
}
kotlin { jvmToolchain(11) }
