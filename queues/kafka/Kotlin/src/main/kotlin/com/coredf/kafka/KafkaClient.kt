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
import org.apache.kafka.common.serialization.ByteArrayDeserializer
import org.apache.kafka.common.serialization.ByteArraySerializer
import org.apache.kafka.common.serialization.StringDeserializer
import org.apache.kafka.common.serialization.StringSerializer
import java.nio.charset.StandardCharsets
import java.time.Duration
import java.util.Properties

object KafkaClient {
    private fun env(key: String, fallback: String = ""): String = (System.getenv(key) ?: "").ifEmpty { fallback }

    private fun config(extra: Properties? = null): Properties {
        val p = Properties()
        p["bootstrap.servers"] = env("KAFKA_BOOTSTRAP_SERVERS")
        env("KAFKA_SECURITY_PROTOCOL").takeIf { it.isNotEmpty() }?.let { p["security.protocol"] = it }
        env("KAFKA_SASL_MECHANISM").takeIf { it.isNotEmpty() }?.let { p["sasl.mechanism"] = it }
        val user = env("KAFKA_SASL_USERNAME")
        val password = env("KAFKA_SASL_PASSWORD")
        if (user.isNotEmpty()) {
            p["sasl.jaas.config"] =
                """org.apache.kafka.common.security.plain.PlainLoginModule required username="$user" password="$password";"""
        }
        extra?.forEach { (k, v) -> p[k] = v }
        return p
    }

    @JvmStatic
    fun Init(): Result =
        if (env("KAFKA_BOOTSTRAP_SERVERS").isEmpty()) Result.missingEnv("KAFKA_BOOTSTRAP_SERVERS") else Result.ok()

    @JvmStatic
    fun Produce(topic: String, value: Any?, key: String? = null): Result {
        if (env("KAFKA_BOOTSTRAP_SERVERS").isEmpty()) return Result.missingEnv("KAFKA_BOOTSTRAP_SERVERS")
        val p = config()
        p["key.serializer"] = StringSerializer::class.java.name
        p["value.serializer"] = ByteArraySerializer::class.java.name
        return try {
            KafkaProducer<String, ByteArray>(p).use {
                it.send(ProducerRecord(topic, key, encode(value))).get()
            }
            Result.ok()
        } catch (e: Exception) {
            Result.transportError(e.message)
        }
    }

    @JvmStatic
    fun Consume(topic: String, timeoutSec: Double = 30.0, maxMessages: Int = 1, groupId: String? = null): Result {
        if (env("KAFKA_BOOTSTRAP_SERVERS").isEmpty()) return Result.missingEnv("KAFKA_BOOTSTRAP_SERVERS")
        val p = config(Properties().apply {
            this["group.id"] = groupId ?: env("KAFKA_GROUP_ID", "coreauto-step")
            this["key.deserializer"] = StringDeserializer::class.java.name
            this["value.deserializer"] = ByteArrayDeserializer::class.java.name
            this["auto.offset.reset"] = env("KAFKA_AUTO_OFFSET_RESET", "earliest")
        })
        val messages = mutableListOf<Map<String, Any?>>()
        return try {
            KafkaConsumer<String, ByteArray>(p).use { consumer ->
                consumer.subscribe(listOf(topic))
                var deadline = (timeoutSec * 1000).toLong()
                while (messages.size < maxMessages && deadline > 0) {
                    consumer.poll(Duration.ofMillis(minOf(1000, deadline))).forEach { record ->
                        messages.add(
                            mapOf(
                                "topic" to record.topic(),
                                "partition" to record.partition(),
                                "offset" to record.offset(),
                                "key" to record.key(),
                                "value" to decode(record.value()),
                            )
                        )
                    }
                    deadline -= 1000
                }
            }
            Result.ok(mapOf("messages" to messages))
        } catch (e: Exception) {
            Result.transportError(e.message)
        }
    }

    private fun encode(value: Any?): ByteArray = when (value) {
        null -> ByteArray(0)
        is ByteArray -> value
        is String -> value.toByteArray(StandardCharsets.UTF_8)
        else -> JsonUtil.stringify(value).toByteArray(StandardCharsets.UTF_8)
    }

    private fun decode(raw: ByteArray?): Any? {
        if (raw == null) return null
        return try {
            JsonUtil.parse(String(raw, StandardCharsets.UTF_8))
        } catch (_: Exception) {
            String(raw, StandardCharsets.UTF_8)
        }
    }
}
