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
package com.coredf.pubsub

import com.google.cloud.pubsub.v1.Publisher
import com.google.cloud.pubsub.v1.SubscriberClient
import com.google.protobuf.ByteString
import com.google.pubsub.v1.*
import java.util.concurrent.TimeUnit

object PubSubClient {

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

    private fun project(): String = envOr("PUBSUB_PROJECT_ID", env("GOOGLE_CLOUD_PROJECT"))

    @JvmStatic
    fun Init(): Result =
        if (project().isEmpty()) Result.missingEnv("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT") else Result.ok()

    @JvmStatic
    fun Publish(value: Any?, topic: String? = null): Result {
        val project = project()
        val topicId = topic ?: env("PUBSUB_TOPIC_ID")
        if (project.isEmpty()) return Result.missingEnv("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT")
        if (topicId.isEmpty()) return Result.missingEnv("PUBSUB_TOPIC_ID")
        return try {
            Publisher.newBuilder(TopicName.of(project, topicId)).build().use { publisher ->
                val id = publisher.publish(
                    PubsubMessage.newBuilder().setData(ByteString.copyFrom(encode(value))).build()
                ).get(30, TimeUnit.SECONDS)
                Result.ok(mapOf("message_id" to id))
            }
        } catch (e: Exception) { Result.transportError(e.message) }
    }

    @JvmStatic
    fun Pull(subscription: String? = null, maxMessages: Int = 1, timeoutSec: Double = 30.0, ack: Boolean = true): Result {
        val project = project()
        val subId = subscription ?: env("PUBSUB_SUBSCRIPTION_ID")
        if (project.isEmpty()) return Result.missingEnv("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT")
        if (subId.isEmpty()) return Result.missingEnv("PUBSUB_SUBSCRIPTION_ID")
        val messages = mutableListOf<Map<String, Any?>>()
        val ackIds = mutableListOf<String>()
        return try {
            SubscriberClient.create().use { client ->
                val subPath = ProjectSubscriptionName.format(project, subId)
                val response = client.pull(
                    PullRequest.newBuilder()
                        .setSubscription(subPath)
                        .setMaxMessages(maxOf(1, minOf(maxMessages, 1000)))
                        .build()
                )
                for (rm in response.receivedMessagesList) {
                    messages.add(
                        mapOf(
                            "subscription" to subId,
                            "message_id" to rm.message.messageId,
                            "value" to decode(rm.message.data.toByteArray()),
                        )
                    )
                    ackIds.add(rm.ackId)
                }
                if (ack && ackIds.isNotEmpty()) {
                    client.acknowledge(
                        AcknowledgeRequest.newBuilder().setSubscription(subPath).addAllAckIds(ackIds).build()
                    )
                }
            }
            Result.ok(mapOf("messages" to messages))
        } catch (e: Exception) { Result.transportError(e.message) }
    }
}
