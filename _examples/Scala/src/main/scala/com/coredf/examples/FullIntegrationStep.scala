// Copyright Core DF — Apache License 2.0
package com.coredf.examples

import com.coredf.cawbs.Cawbs
import com.coredf.files.FileClient
import com.coredf.kafka.KafkaClient
import com.coredf.transform.TransformClient

@main def fullIntegrationStep(): Unit =
  require(Cawbs.Init().statusCode == 200, "cawbs.Init failed")
  val event = Cawbs.GetEventPayload()
  require(event.statusCode == 200, "GetEventPayload failed")

  val orderId = event.payload match
    case m: Map[?, ?] =>
      val keys = m.map { case (k, v) => k.toString -> v }
      keys.get("orderId").orElse(keys.get("id")).map(_.toString).getOrElse("unknown")
    case _ => "unknown"

  val ackDir = sys.env.getOrElse("EXAMPLE_ACK_DIR", "/tmp/coreauto-example")
  val ackPath = s"$ackDir/$orderId.json"
  val order = Map("orderId" -> orderId, "details" -> event.payload)
  val text = TransformClient.JsonStringify(order)
  require(text.statusCode == 200)
  require(FileClient.LocalWrite(ackPath, text.get("text").toString).statusCode == 200)

  val topic = sys.env.getOrElse("EXAMPLE_KAFKA_TOPIC", "orders.enriched")
  var published = List.empty[String]
  if KafkaClient.Produce(topic, order).statusCode == 200 then published = "kafka" :: published

  val out = Map("orderId" -> orderId, "queuesPublished" -> published.reverse, "ackPath" -> ackPath)
  require(Cawbs.PutStepPayload(out).statusCode == 200)
  println(s"""{"status_code":200,"result":$out}""")
