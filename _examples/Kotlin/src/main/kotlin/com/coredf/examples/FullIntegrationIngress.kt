// Copyright Core DF — Apache License 2.0
package com.coredf.examples

import com.coredf.ingress.Ingress
import com.coredf.kafka.KafkaClient

fun main() {
    val topic = System.getenv("EXAMPLE_KAFKA_TOPIC") ?: "orders.inbound"
    System.err.println("Bridging Kafka topic $topic")
    while (true) {
        val r = Ingress.RunBridge { KafkaClient.Consume(topic, 30.0, 10, null) }
        if (r.statusCode >= 400 || r.statusCode == 0) {
            System.err.println(r.get("error"))
            Thread.sleep(5000)
            continue
        }
        if (r.get("forwarded") != null) println(r.toMap())
    }
}
