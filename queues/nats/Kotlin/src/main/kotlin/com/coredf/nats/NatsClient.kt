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
package com.coredf.nats

import io.nats.client.Nats
import io.nats.client.Connection
import java.time.Duration

object NatsClient {

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

    private fun servers(): String = envOr("NATS_URL", env("NATS_SERVERS"))

    @JvmStatic
    fun Init(): Result = if (servers().isEmpty()) Result.missingEnv("NATS_URL or NATS_SERVERS") else Result.ok()

    @JvmStatic
    fun Publish(subject: String, value: Any?): Result {
        if (servers().isEmpty()) return Result.missingEnv("NATS_URL or NATS_SERVERS")
        return try {
            Nats.connect(servers()).use { nc ->
                nc.publish(subject, encode(value))
                nc.flush(Duration.ofSeconds(5))
            }
            Result.ok()
        } catch (e: Exception) { Result.transportError(e.message) }
    }

    @JvmStatic
    fun Subscribe(subject: String, timeoutSec: Double = 30.0, maxMessages: Int = 1): Result {
        if (servers().isEmpty()) return Result.missingEnv("NATS_URL or NATS_SERVERS")
        val messages = mutableListOf<Map<String, Any?>>()
        return try {
            Nats.connect(servers()).use { nc ->
                val sub = nc.subscribe(subject)
                var deadline = (timeoutSec * 1000).toLong()
                while (messages.size < maxMessages && deadline > 0) {
                    val msg = sub.nextMessage(Duration.ofMillis(minOf(1000, deadline)))
                    deadline -= 1000
                    if (msg == null) continue
                    messages.add(mapOf("subject" to msg.subject, "value" to decode(msg.data)))
                }
            }
            Result.ok(mapOf("messages" to messages))
        } catch (e: Exception) { Result.transportError(e.message) }
    }
}
