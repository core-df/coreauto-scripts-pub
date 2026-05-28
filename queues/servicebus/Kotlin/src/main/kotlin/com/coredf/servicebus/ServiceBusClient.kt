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
package com.coredf.servicebus

import com.azure.messaging.servicebus.*
import java.time.Duration

object ServiceBusClient {

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

    @JvmStatic
    fun Init(): Result {
        if (env("SERVICE_BUS_CONNECTION_STRING").isEmpty()) return Result.missingEnv("SERVICE_BUS_CONNECTION_STRING")
        if (env("SERVICE_BUS_QUEUE_NAME").isEmpty()) return Result.missingEnv("SERVICE_BUS_QUEUE_NAME (or pass queue per call)")
        return Result.ok()
    }

    @JvmStatic
    fun Send(value: Any?, queue: String? = null): Result {
        val conn = env("SERVICE_BUS_CONNECTION_STRING")
        val q = queue ?: env("SERVICE_BUS_QUEUE_NAME")
        if (conn.isEmpty()) return Result.missingEnv("SERVICE_BUS_CONNECTION_STRING")
        if (q.isEmpty()) return Result.missingEnv("SERVICE_BUS_QUEUE_NAME")
        return try {
            ServiceBusClientBuilder().connectionString(conn).sender().queueName(q).buildClient().use { sender ->
                sender.sendMessage(ServiceBusMessage(encode(value)))
            }
            Result.ok()
        } catch (e: Exception) { Result.transportError(e.message) }
    }

    @JvmStatic
    fun Receive(queue: String? = null, timeoutSec: Double = 30.0, maxMessages: Int = 1, complete: Boolean = true): Result {
        val conn = env("SERVICE_BUS_CONNECTION_STRING")
        val q = queue ?: env("SERVICE_BUS_QUEUE_NAME")
        if (conn.isEmpty()) return Result.missingEnv("SERVICE_BUS_CONNECTION_STRING")
        if (q.isEmpty()) return Result.missingEnv("SERVICE_BUS_QUEUE_NAME")
        val messages = mutableListOf<Map<String, Any?>>()
        return try {
            ServiceBusClientBuilder().connectionString(conn).receiver().queueName(q).buildClient().use { receiver ->
                for (msg in receiver.receiveMessages(maxMessages, Duration.ofSeconds(timeoutSec.toLong()))) {
                    messages.add(mapOf("queue" to q, "message_id" to msg.messageId, "value" to decode(msg.body.toBytes())))
                    if (complete) receiver.complete(msg)
                }
            }
            Result.ok(mapOf("messages" to messages))
        } catch (e: Exception) { Result.transportError(e.message) }
    }
}
