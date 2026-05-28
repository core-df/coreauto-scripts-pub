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
package com.coredf.rabbit

import com.rabbitmq.client.ConnectionFactory
import com.rabbitmq.client.GetResponse
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

object RabbitClient {

    private fun env(key: String, fallback: String = ""): String = (System.getenv(key) ?: "").ifEmpty { fallback }
    private fun envOr(key: String, fallback: String): String = env(key).ifEmpty { fallback }

    private fun encode(value: Any?): ByteArray = when (value) {
        null -> ByteArray(0)
        is ByteArray -> value
        is String -> value.toByteArray(java.nio.charset.StandardCharsets.UTF_8)
        else -> JsonUtil.stringify(value).toByteArray(java.nio.charset.StandardCharsets.UTF_8)
    }

    private fun decode(raw: ByteArray?): Any? {
        if (raw == null) return null
        return try {
            JsonUtil.parse(String(raw, java.nio.charset.StandardCharsets.UTF_8))
        } catch (_: Exception) {
            String(raw, java.nio.charset.StandardCharsets.UTF_8)
        }
    }

    private fun url(): String {
        val u = env("RABBITMQ_URL")
        if (u.isNotEmpty()) return u
        val host = env("RABBITMQ_HOST")
        if (host.isEmpty()) return ""
        return "amqp://${enc(envOr("RABBITMQ_USER", "guest"))}:${enc(envOr("RABBITMQ_PASSWORD", "guest"))}@$host:${envOr("RABBITMQ_PORT", "5672")}/${enc(envOr("RABBITMQ_VHOST", "/"))}"
    }

    private fun enc(s: String): String = try { URLEncoder.encode(s, StandardCharsets.UTF_8) } catch (_: Exception) { s }

    private fun factory(): ConnectionFactory = ConnectionFactory().apply { setUri(url()) }

    @JvmStatic
    fun Init(): Result = if (url().isEmpty()) Result.missingEnv("RABBITMQ_URL or RABBITMQ_HOST") else Result.ok()

    @JvmStatic
    fun Publish(queue: String, value: Any?, durable: Boolean = true): Result {
        if (url().isEmpty()) return Result.missingEnv("RABBITMQ_URL or RABBITMQ_HOST")
        return try {
            factory().newConnection().use { conn ->
                conn.createChannel().use { ch ->
                    ch.queueDeclare(queue, durable, false, false, null)
                    ch.basicPublish("", queue, null, encode(value))
                }
            }
            Result.ok()
        } catch (e: Exception) { Result.transportError(e.message) }
    }

    @JvmStatic
    fun Consume(queue: String, timeoutSec: Double = 30.0, maxMessages: Int = 1, autoAck: Boolean = true, durable: Boolean = true): Result {
        if (url().isEmpty()) return Result.missingEnv("RABBITMQ_URL or RABBITMQ_HOST")
        val messages = mutableListOf<Map<String, Any?>>()
        return try {
            factory().newConnection().use { conn ->
                conn.createChannel().use { ch ->
                    ch.queueDeclare(queue, durable, false, false, null)
                    var deadline = (timeoutSec * 1000).toLong()
                    while (messages.size < maxMessages && deadline > 0) {
                        val resp: GetResponse? = ch.basicGet(queue, autoAck)
                        if (resp == null) { Thread.sleep(1000); deadline -= 1000; continue }
                        messages.add(mapOf("queue" to queue, "delivery_tag" to resp.envelope.deliveryTag, "value" to decode(resp.body)))
                    }
                }
            }
            Result.ok(mapOf("messages" to messages))
        } catch (e: Exception) { Result.transportError(e.message) }
    }
}
