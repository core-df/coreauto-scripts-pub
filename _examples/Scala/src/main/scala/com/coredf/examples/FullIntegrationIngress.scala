// Copyright Core DF — Apache License 2.0
package com.coredf.examples

import com.coredf.ingress.Ingress
import com.coredf.kafka.KafkaClient

@main def fullIntegrationIngress(): Unit =
  val topic = sys.env.getOrElse("EXAMPLE_KAFKA_TOPIC", "orders.inbound")
  System.err.println(s"Bridging Kafka topic $topic")
  while true do
    val r = Ingress.RunBridge(() => KafkaClient.Consume(topic, 30, 10, null))
    if r.statusCode >= 400 || r.statusCode == 0 then
      System.err.println(r.get("error"))
      Thread.sleep(5000)
    else if r.get("forwarded") != null then
      println(r.toMap)
