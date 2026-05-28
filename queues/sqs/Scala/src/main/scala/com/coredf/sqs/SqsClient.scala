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

object SqsClient:

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

  private def client(): AwsSqsClient =
    val b = AwsSqsClient.builder().region(Region.of(envOr("AWS_REGION", envOr("AWS_DEFAULT_REGION", "us-east-1"))))
    val ep = env("SQS_ENDPOINT_URL")
    if ep.nonEmpty then b.endpointOverride(URI.create(ep))
    b.build()

  private def queue(explicit: String): String =
    if explicit != null && explicit.nonEmpty then explicit else env("SQS_QUEUE_URL")

  def Init(): Result =
    if env("AWS_ACCESS_KEY_ID").isEmpty && env("AWS_PROFILE").isEmpty then
      Result.missingEnv("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE")
    else if env("SQS_QUEUE_URL").isEmpty then Result.missingEnv("SQS_QUEUE_URL (or pass queue_url per call)")
    else Result.ok()

  def Send(value: Any, queueUrl: String = null): Result =
    val url = queue(queueUrl)
    if url.isEmpty then Result.missingEnv("SQS_QUEUE_URL")
    else
      try
        val c = client()
        try
          val body = value match
            case s: String => s
            case other => JsonUtil.stringify(other)
          val resp = c.sendMessage(SendMessageRequest.builder().queueUrl(url).messageBody(body).build())
          Result.ok(Map("message_id" -> resp.messageId()))
        finally c.close()
      catch case e: Exception => Result.transportError(e.getMessage)

  def Receive(queueUrl: String = null, maxMessages: Int = 1, waitTimeSec: Int = 10, delete: Boolean = true): Result =
    val url = queue(queueUrl)
    if url.isEmpty then Result.missingEnv("SQS_QUEUE_URL")
    else
      try
        val max = math.max(1, math.min(maxMessages, 10))
        val c = client()
        try
          val resp = c.receiveMessage(ReceiveMessageRequest.builder().queueUrl(url).maxNumberOfMessages(max).waitTimeSeconds(waitTimeSec).build())
          val messages = scala.collection.mutable.ListBuffer[Map[String, Any]]()
          resp.messages().forEach { item =>
            val m = scala.collection.mutable.LinkedHashMap[String, Any]("message_id" -> item.messageId(), "receipt_handle" -> item.receiptHandle())
            m("value") = try JsonUtil.parse(item.body()) catch case _: Exception => item.body()
            messages += m.toMap
            if delete then c.deleteMessage(DeleteMessageRequest.builder().queueUrl(url).receiptHandle(item.receiptHandle()).build())
          }
          Result.ok(Map("messages" -> messages.toList))
        finally c.close()
      catch case e: Exception => Result.transportError(e.getMessage)
