plugins { kotlin("jvm") version "2.0.21" }
group = "com.coredf"; version = "1.0.0"
repositories { mavenCentral() }
dependencies {
    implementation("com.rabbitmq:amqp-client:5.21.0")
}
kotlin { jvmToolchain(11) }
