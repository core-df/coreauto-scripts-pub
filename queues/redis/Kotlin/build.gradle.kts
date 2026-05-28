plugins { kotlin("jvm") version "2.0.21" }
group = "com.coredf"; version = "1.0.0"
repositories { mavenCentral() }
dependencies {
    implementation("redis.clients:jedis:5.1.2")
}
kotlin { jvmToolchain(11) }
