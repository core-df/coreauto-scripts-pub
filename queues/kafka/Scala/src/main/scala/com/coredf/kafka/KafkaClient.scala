// Copyright Core DF
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
package com.coredf.kafka

import org.apache.kafka.clients.consumer.KafkaConsumer
import org.apache.kafka.clients.producer.KafkaProducer
import org.apache.kafka.clients.producer.ProducerRecord
import org.apache.kafka.common.serialization.*
import java.time.Duration
import java.util.Properties

object KafkaClient:

  private def env(k: String): String = Option(System.getenv(k)).getOrElse("")
  private def env(k: String, d: String): String = val v = env(k); if v.isEmpty then d else v
  private def envOr(k: String, d: String): String = env(k, d)

  private def encode(value: Any): Array[Byte] = value match
    case null => Array.emptyByteArray
    case b: Array[Byte] => b
    case s: String => s.getBytes(java.nio.charset.StandardCharsets.UTF_8)
    case other => JsonUtil.stringify(other).getBytes(java.nio.charset.StandardCharsets.UTF_8)

  private def decode(raw: Array[Byte]): Any =
    if raw == null then null
    else
      try JsonUtil.parse(new String(raw, java.nio.charset.StandardCharsets.UTF_8))
      catch case _: Exception => new String(raw, java.nio.charset.StandardCharsets.UTF_8)

  private def config(extra: Properties = null): Properties =
    val p = new Properties()
    p.put("bootstrap.servers", env("KAFKA_BOOTSTRAP_SERVERS"))
    val sec = env("KAFKA_SECURITY_PROTOCOL"); if sec.nonEmpty then p.put("security.protocol", sec)
    val mech = env("KAFKA_SASL_MECHANISM"); if mech.nonEmpty then p.put("sasl.mechanism", mech)
    val user = env("KAFKA_SASL_USERNAME"); val pw = env("KAFKA_SASL_PASSWORD")
    if user.nonEmpty then p.put("sasl.jaas.config", "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"" + user + "\" password=\"" + pw + "\";")
    if extra != null then extra.forEach((k, v) => p.put(k, v))
    p

  def Init(): Result =
    if env("KAFKA_BOOTSTRAP_SERVERS").isEmpty then Result.missingEnv("KAFKA_BOOTSTRAP_SERVERS") else Result.ok()

  def Produce(topic: String, value: Any, key: String = null): Result =
    if env("KAFKA_BOOTSTRAP_SERVERS").isEmpty then Result.missingEnv("KAFKA_BOOTSTRAP_SERVERS")
    else
      try
        val p = config(); p.put("key.serializer", classOf[StringSerializer].getName); p.put("value.serializer", classOf[ByteArraySerializer].getName)
        val prod = new KafkaProducer[String, Array[Byte]](p)
        try prod.send(new ProducerRecord(topic, key, encode(value))).get() finally prod.close()
        Result.ok()
      catch case e: Exception => Result.transportError(e.getMessage)

  def Consume(topic: String, timeoutSec: Double = 30.0, maxMessages: Int = 1, groupId: String = null): Result =
    if env("KAFKA_BOOTSTRAP_SERVERS").isEmpty then Result.missingEnv("KAFKA_BOOTSTRAP_SERVERS")
    else
      try
        val extra = new Properties()
        extra.put("group.id", if groupId != null then groupId else envOr("KAFKA_GROUP_ID", "coreauto-step"))
        extra.put("key.deserializer", classOf[StringDeserializer].getName)
        extra.put("value.deserializer", classOf[ByteArrayDeserializer].getName)
        extra.put("auto.offset.reset", envOr("KAFKA_AUTO_OFFSET_RESET", "earliest"))
        val p = config(extra)
        val messages = scala.collection.mutable.ListBuffer[Map[String, Any]]()
        val consumer = new KafkaConsumer[String, Array[Byte]](p)
        try
          consumer.subscribe(java.util.List.of(topic))
          var deadline = (timeoutSec * 1000).toLong
          while messages.size < maxMessages && deadline > 0 do
            consumer.poll(Duration.ofMillis(math.min(1000, deadline))).forEach { r =>
              messages += Map("topic" -> r.topic(), "partition" -> r.partition(), "offset" -> r.offset(), "key" -> r.key(), "value" -> decode(r.value()))
            }
            deadline -= 1000
        finally consumer.close()
        Result.ok(Map("messages" -> messages.toList))
      catch case e: Exception => Result.transportError(e.getMessage)
