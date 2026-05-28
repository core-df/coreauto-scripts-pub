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
package com.coredf.redis

import redis.clients.jedis.Jedis

object RedisClient {

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
        env("REDIS_URL").takeIf { it.isNotEmpty() }?.let { return it }
        val host = env("REDIS_HOST")
        if (host.isEmpty()) return ""
        val pw = env("REDIS_PASSWORD")
        val db = envOr("REDIS_DB", "0")
        return if (pw.isNotEmpty()) "redis://:$pw@$host:${envOr("REDIS_PORT", "6379")}/$db"
        else "redis://$host:${envOr("REDIS_PORT", "6379")}/$db"
    }

    @JvmStatic
    fun Init(): Result = if (url().isEmpty()) Result.missingEnv("REDIS_URL or REDIS_HOST") else Result.ok()

    @JvmStatic
    fun Push(queue: String, value: Any?): Result {
        if (url().isEmpty()) return Result.missingEnv("REDIS_URL or REDIS_HOST")
        return try {
            Jedis(url()).use { it.lpush(queue.toByteArray(), encode(value)) }
            Result.ok()
        } catch (e: Exception) { Result.transportError(e.message) }
    }

    @JvmStatic
    fun Pop(queue: String, timeoutSec: Double = 30.0, maxMessages: Int = 1): Result {
        if (url().isEmpty()) return Result.missingEnv("REDIS_URL or REDIS_HOST")
        val messages = mutableListOf<Map<String, Any?>>()
        return try {
            Jedis(url()).use { j ->
                var remaining = maxOf(1, maxMessages)
                var deadline = timeoutSec
                while (remaining > 0 && deadline > 0) {
                    val wait = if (remaining == maxMessages) maxOf(1, timeoutSec.toInt()) else 1
                    val item = j.brpop(wait, queue) ?: break
                    if (item.size < 2) break
                    messages.add(mapOf("queue" to queue, "value" to decode(item[1])))
                    remaining--
                    deadline -= wait
                }
            }
            Result.ok(mapOf("messages" to messages))
        } catch (e: Exception) { Result.transportError(e.message) }
    }
}
