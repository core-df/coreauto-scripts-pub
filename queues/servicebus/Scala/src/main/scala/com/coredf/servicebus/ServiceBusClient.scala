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

object ServiceBusClient:

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

  def Init(): Result =
    if env("SERVICE_BUS_CONNECTION_STRING").isEmpty then Result.missingEnv("SERVICE_BUS_CONNECTION_STRING")
    else if env("SERVICE_BUS_QUEUE_NAME").isEmpty then Result.missingEnv("SERVICE_BUS_QUEUE_NAME (or pass queue per call)")
    else Result.ok()

  def Send(value: Any, queue: String = null): Result =
    val conn = env("SERVICE_BUS_CONNECTION_STRING"); val q = Option(queue).getOrElse(env("SERVICE_BUS_QUEUE_NAME"))
    if conn.isEmpty then Result.missingEnv("SERVICE_BUS_CONNECTION_STRING")
    else if q.isEmpty then Result.missingEnv("SERVICE_BUS_QUEUE_NAME")
    else
      try
        val sender = new ServiceBusClientBuilder().connectionString(conn).sender().queueName(q).buildClient()
        try sender.sendMessage(new ServiceBusMessage(encode(value))) finally sender.close()
        Result.ok()
      catch case e: Exception => Result.transportError(e.getMessage)

  def Receive(queue: String = null, timeoutSec: Double = 30.0, maxMessages: Int = 1, complete: Boolean = true): Result =
    val conn = env("SERVICE_BUS_CONNECTION_STRING"); val q = Option(queue).getOrElse(env("SERVICE_BUS_QUEUE_NAME"))
    if conn.isEmpty then Result.missingEnv("SERVICE_BUS_CONNECTION_STRING")
    else if q.isEmpty then Result.missingEnv("SERVICE_BUS_QUEUE_NAME")
    else
      try
        val messages = scala.collection.mutable.ListBuffer[Map[String, Any]]()
        val receiver = new ServiceBusClientBuilder().connectionString(conn).receiver().queueName(q).buildClient()
        try
          receiver.receiveMessages(maxMessages, Duration.ofSeconds(timeoutSec.toLong)).forEach { msg =>
            messages += Map("queue" -> q, "message_id" -> msg.getMessageId, "value" -> decode(msg.getBody.toBytes))
            if complete then receiver.complete(msg)
          }
        finally receiver.close()
        Result.ok(Map("messages" -> messages.toList))
      catch case e: Exception => Result.transportError(e.getMessage)
