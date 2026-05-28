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

import com.google.cloud.pubsub.v1.{Publisher, SubscriberClient}
import com.google.protobuf.ByteString
import com.google.pubsub.v1.*
import java.util.concurrent.TimeUnit

object PubSubClient:

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

  private def project(): String = envOr("PUBSUB_PROJECT_ID", env("GOOGLE_CLOUD_PROJECT"))

  def Init(): Result =
    if project().isEmpty then Result.missingEnv("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT") else Result.ok()

  def Publish(value: Any, topic: String = null): Result =
    val project = project(); val topicId = Option(topic).getOrElse(env("PUBSUB_TOPIC_ID"))
    if project.isEmpty then Result.missingEnv("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT")
    else if topicId.isEmpty then Result.missingEnv("PUBSUB_TOPIC_ID")
    else
      try
        val publisher = Publisher.newBuilder(TopicName.of(project, topicId)).build()
        try
          val id = publisher.publish(PubsubMessage.newBuilder().setData(ByteString.copyFrom(encode(value))).build()).get(30, TimeUnit.SECONDS)
          Result.ok(Map("message_id" -> id))
        finally publisher.shutdown()
      catch case e: Exception => Result.transportError(e.getMessage)

  def Pull(subscription: String = null, maxMessages: Int = 1, timeoutSec: Double = 30.0, ack: Boolean = true): Result =
    val project = project(); val subId = Option(subscription).getOrElse(env("PUBSUB_SUBSCRIPTION_ID"))
    if project.isEmpty then Result.missingEnv("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT")
    else if subId.isEmpty then Result.missingEnv("PUBSUB_SUBSCRIPTION_ID")
    else
      try
        val messages = scala.collection.mutable.ListBuffer[Map[String, Any]]()
        val ackIds = scala.collection.mutable.ListBuffer[String]()
        val client = SubscriberClient.create()
        try
          val subPath = ProjectSubscriptionName.format(project, subId)
          val response = client.pull(PullRequest.newBuilder().setSubscription(subPath).setMaxMessages(math.max(1, math.min(maxMessages, 1000))).build())
          response.getReceivedMessagesList.forEach { rm =>
            messages += Map("subscription" -> subId, "message_id" -> rm.getMessage.getMessageId, "value" -> decode(rm.getMessage.getData.toByteArray))
            ackIds += rm.getAckId
          }
          if ack && ackIds.nonEmpty then
            val ids = new java.util.ArrayList[String](); ackIds.foreach(ids.add)
            client.acknowledge(AcknowledgeRequest.newBuilder().setSubscription(subPath).addAllAckIds(ids).build())
        finally client.close()
        Result.ok(Map("messages" -> messages.toList))
      catch case e: Exception => Result.transportError(e.getMessage)
