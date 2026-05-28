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

object RabbitClient:

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

  private def url(): String =
    val u = env("RABBITMQ_URL")
    if u.nonEmpty then u
    else
      val host = env("RABBITMQ_HOST")
      if host.isEmpty then ""
      else s"amqp://${enc(envOr("RABBITMQ_USER", "guest"))}:${enc(envOr("RABBITMQ_PASSWORD", "guest"))}@$host:${envOr("RABBITMQ_PORT", "5672")}/${enc(envOr("RABBITMQ_VHOST", "/"))}"

  private def enc(s: String): String =
    try URLEncoder.encode(s, StandardCharsets.UTF_8)
    catch case _: Exception => s

  private def factory(): ConnectionFactory =
    val f = new ConnectionFactory(); f.setUri(url()); f

  def Init(): Result = if url().isEmpty then Result.missingEnv("RABBITMQ_URL or RABBITMQ_HOST") else Result.ok()

  def Publish(queue: String, value: Any, durable: Boolean = true): Result =
    if url().isEmpty then Result.missingEnv("RABBITMQ_URL or RABBITMQ_HOST")
    else
      try
        val conn = factory().newConnection()
        try
          val ch = conn.createChannel()
          try
            ch.queueDeclare(queue, durable, false, false, null)
            ch.basicPublish("", queue, null, encode(value))
          finally ch.close()
        finally conn.close()
        Result.ok()
      catch case e: Exception => Result.transportError(e.getMessage)

  def Consume(queue: String, timeoutSec: Double = 30.0, maxMessages: Int = 1, autoAck: Boolean = true, durable: Boolean = true): Result =
    if url().isEmpty then Result.missingEnv("RABBITMQ_URL or RABBITMQ_HOST")
    else
      try
        val messages = scala.collection.mutable.ListBuffer[Map[String, Any]]()
        val conn = factory().newConnection()
        try
          val ch = conn.createChannel()
          try
            ch.queueDeclare(queue, durable, false, false, null)
            var deadline = (timeoutSec * 1000).toLong
            while messages.size < maxMessages && deadline > 0 do
              val resp = ch.basicGet(queue, autoAck)
              if resp == null then Thread.sleep(1000); deadline -= 1000
              else
                messages += Map("queue" -> queue, "delivery_tag" -> resp.getEnvelope.getDeliveryTag, "value" -> decode(resp.getBody))
          finally ch.close()
        finally conn.close()
        Result.ok(Map("messages" -> messages.toList))
      catch case e: Exception => Result.transportError(e.getMessage)
