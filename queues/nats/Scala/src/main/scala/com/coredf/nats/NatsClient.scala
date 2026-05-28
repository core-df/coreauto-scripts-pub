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
import java.time.Duration

object NatsClient:

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

  private def servers(): String = envOr("NATS_URL", env("NATS_SERVERS"))

  def Init(): Result = if servers().isEmpty then Result.missingEnv("NATS_URL or NATS_SERVERS") else Result.ok()

  def Publish(subject: String, value: Any): Result =
    if servers().isEmpty then Result.missingEnv("NATS_URL or NATS_SERVERS")
    else
      try
        val nc = Nats.connect(servers())
        try nc.publish(subject, encode(value)); nc.flush(Duration.ofSeconds(5)) finally nc.close()
        Result.ok()
      catch case e: Exception => Result.transportError(e.getMessage)

  def Subscribe(subject: String, timeoutSec: Double = 30.0, maxMessages: Int = 1): Result =
    if servers().isEmpty then Result.missingEnv("NATS_URL or NATS_SERVERS")
    else
      try
        val messages = scala.collection.mutable.ListBuffer[Map[String, Any]]()
        val nc = Nats.connect(servers())
        try
          val sub = nc.subscribe(subject)
          var deadline = (timeoutSec * 1000).toLong
          while messages.size < maxMessages && deadline > 0 do
            val msg = sub.nextMessage(Duration.ofMillis(math.min(1000, deadline)))
            deadline -= 1000
            if msg != null then messages += Map("subject" -> msg.getSubject, "value" -> decode(msg.getData))
        finally nc.close()
        Result.ok(Map("messages" -> messages.toList))
      catch case e: Exception => Result.transportError(e.getMessage)
