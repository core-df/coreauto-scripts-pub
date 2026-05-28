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
package com.coredf.sqs

import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.sqs.SqsClient as AwsSqsClient
import software.amazon.awssdk.services.sqs.model.*
import java.net.URI

object SqsClient {

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

    private fun client(): AwsSqsClient {
        val b = AwsSqsClient.builder().region(Region.of(envOr("AWS_REGION", envOr("AWS_DEFAULT_REGION", "us-east-1"))))
        env("SQS_ENDPOINT_URL").takeIf { it.isNotEmpty() }?.let { b.endpointOverride(URI.create(it)) }
        return b.build()
    }

    private fun queue(explicit: String?): String =
        if (!explicit.isNullOrEmpty()) explicit else env("SQS_QUEUE_URL")

    @JvmStatic
    fun Init(): Result {
        if (env("AWS_ACCESS_KEY_ID").isEmpty() && env("AWS_PROFILE").isEmpty())
            return Result.missingEnv("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE")
        if (env("SQS_QUEUE_URL").isEmpty()) return Result.missingEnv("SQS_QUEUE_URL (or pass queue_url per call)")
        return Result.ok()
    }

    @JvmStatic
    fun Send(value: Any?, queueUrl: String? = null): Result {
        val url = queue(queueUrl)
        if (url.isEmpty()) return Result.missingEnv("SQS_QUEUE_URL")
        return try {
            client().use { c ->
                val body = if (value is String) value else JsonUtil.stringify(value)
                val resp = c.sendMessage(SendMessageRequest.builder().queueUrl(url).messageBody(body).build())
                Result.ok(mapOf("message_id" to resp.messageId()))
            }
        } catch (e: Exception) { Result.transportError(e.message) }
    }

    @JvmStatic
    fun Receive(queueUrl: String? = null, maxMessages: Int = 1, waitTimeSec: Int = 10, delete: Boolean = true): Result {
        val url = queue(queueUrl)
        if (url.isEmpty()) return Result.missingEnv("SQS_QUEUE_URL")
        val max = maxOf(1, minOf(maxMessages, 10))
        return try {
            client().use { c ->
                val resp = c.receiveMessage(
                    ReceiveMessageRequest.builder().queueUrl(url).maxNumberOfMessages(max).waitTimeSeconds(waitTimeSec).build()
                )
                val messages = mutableListOf<Map<String, Any?>>()
                for (item in resp.messages()) {
                    val m = linkedMapOf<String, Any?>("message_id" to item.messageId(), "receipt_handle" to item.receiptHandle())
                    m["value"] = try { JsonUtil.parse(item.body()) } catch (_: Exception) { item.body() }
                    messages.add(m)
                    if (delete) c.deleteMessage(DeleteMessageRequest.builder().queueUrl(url).receiptHandle(item.receiptHandle()).build())
                }
                Result.ok(mapOf("messages" to messages))
            }
        } catch (e: Exception) { Result.transportError(e.message) }
    }
}
