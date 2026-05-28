// Copyright Core DF — Apache License 2.0
package com.coredf.examples

import com.coredf.cawbs.Cawbs
import com.coredf.files.FileClient
import com.coredf.kafka.KafkaClient
import com.coredf.transform.TransformClient

fun main() {
    check(Cawbs.init().statusCode == 200) { "cawbs.init failed" }
    val event = Cawbs.getEventPayload()
    check(event.statusCode == 200) { "getEventPayload failed" }

    val orderId = when (val p = event.payload) {
        is Map<*, *> -> (p["orderId"] ?: p["id"])?.toString() ?: "unknown"
        else -> "unknown"
    }
    val ackDir = System.getenv("EXAMPLE_ACK_DIR") ?: "/tmp/coreauto-example"
    val ackPath = "$ackDir/$orderId.json"
    val order = mapOf("orderId" to orderId, "details" to event.payload)
    val text = TransformClient.JsonStringify(order)
    check(text.statusCode == 200)
    check(FileClient.LocalWrite(ackPath, text.get("text").toString()).statusCode == 200)

    val topic = System.getenv("EXAMPLE_KAFKA_TOPIC") ?: "orders.enriched"
    val published = mutableListOf<String>()
    if (KafkaClient.Produce(topic, order).statusCode == 200) published.add("kafka")

    val out = mapOf("orderId" to orderId, "queuesPublished" to published, "ackPath" to ackPath)
    check(Cawbs.putStepPayload(out).statusCode == 200)
    println("""{"status_code":200,"result":$out}""")
}
