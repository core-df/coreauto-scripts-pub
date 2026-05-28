plugins {
    kotlin("jvm") version "1.9.24"
}

dependencies {
    implementation(project(":cawbs"))
    implementation(project(":transform"))
    implementation(project(":files"))
    implementation(project(":kafka"))
    implementation(project(":ingress"))
}

application {
    mainClass.set("com.coredf.examples.FullIntegrationStepKt")
}
