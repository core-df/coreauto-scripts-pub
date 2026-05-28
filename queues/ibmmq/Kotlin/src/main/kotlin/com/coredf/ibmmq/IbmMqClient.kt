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
package com.coredf.ibmmq

import com.ibm.msg.client.jms.MQConnectionFactory
import com.ibm.msg.client.wmq.WMQConstants
import javax.jms.*

object IbmMqClient {

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
        if (env("MQ_HOST").isEmpty() || env("MQ_QUEUE_MANAGER").isEmpty()) return Result.missingEnv("MQ_HOST and MQ_QUEUE_MANAGER")
        if (env("MQ_QUEUE").isEmpty()) return Result.missingEnv("MQ_QUEUE (or pass queue per call)")
        return Result.ok()
    }

    @JvmStatic
    fun Put(value: Any?, queue: String? = null): Result {
        val q = queue ?: env("MQ_QUEUE")
        if (q.isEmpty()) return Result.missingEnv("MQ_QUEUE")
        return try { send(q, encode(value)); Result.ok() } catch (e: Exception) { Result.transportError(e.message) }
    }

    @JvmStatic
    fun Get(queue: String? = null, timeoutSec: Double = 30.0, maxMessages: Int = 1): Result {
        val q = queue ?: env("MQ_QUEUE")
        if (q.isEmpty()) return Result.missingEnv("MQ_QUEUE")
        val messages = mutableListOf<Map<String, Any?>>()
        return try {
            repeat(maxOf(1, maxMessages)) {
                val body = receive(q, (timeoutSec * 1000).toLong()) ?: return@repeat
                messages.add(mapOf("queue" to q, "value" to decode(body)))
            }
            Result.ok(mapOf("messages" to messages))
        } catch (e: Exception) { Result.transportError(e.message) }
    }

    private fun connect(): Connection {
        val f = MQConnectionFactory()
        f.hostName = env("MQ_HOST")
        f.port = envOr("MQ_PORT", "1414").toInt()
        f.queueManager = env("MQ_QUEUE_MANAGER")
        f.channel = envOr("MQ_CHANNEL", "SYSTEM.DEF.SVRCONN")
        f.transportType = WMQConstants.WMQ_CM_CLIENT
        val user = env("MQ_USER")
        return if (user.isEmpty()) f.createConnection() else f.createConnection(user, env("MQ_PASSWORD"))
    }

    private fun send(queue: String, body: ByteArray) {
        val conn = connect()
        conn.start()
        try {
            conn.createSession(false, Session.AUTO_ACKNOWLEDGE).use { s ->
                val q = s.createQueue(queue)
                s.createProducer(q).use { p ->
                    val m = s.createBytesMessage()
                    m.writeBytes(body)
                    p.send(m)
                }
            }
        } finally { conn.close() }
    }

    private fun receive(queue: String, waitMs: Long): ByteArray? {
        val conn = connect()
        conn.start()
        try {
            conn.createSession(false, Session.AUTO_ACKNOWLEDGE).use { s ->
                val q = s.createQueue(queue)
                s.createConsumer(q).use { c ->
                    val msg = c.receive(waitMs) ?: return null
                    return when (msg) {
                        is BytesMessage -> {
                            val b = ByteArray(msg.bodyLength.toInt())
                            msg.readBytes(b)
                            b
                        }
                        else -> msg.toString().toByteArray()
                    }
                }
            }
        } finally { conn.close() }
    }
}
