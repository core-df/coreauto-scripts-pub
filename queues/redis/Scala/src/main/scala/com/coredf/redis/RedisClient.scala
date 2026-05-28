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

object RedisClient:

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
    val u = env("REDIS_URL")
    if u.nonEmpty then u
    else
      val host = env("REDIS_HOST")
      if host.isEmpty then ""
      else
        val pw = env("REDIS_PASSWORD"); val db = envOr("REDIS_DB", "0")
        if pw.nonEmpty then s"redis://:$pw@$host:${envOr("REDIS_PORT", "6379")}/$db"
        else s"redis://$host:${envOr("REDIS_PORT", "6379")}/$db"

  def Init(): Result = if url().isEmpty then Result.missingEnv("REDIS_URL or REDIS_HOST") else Result.ok()

  def Push(queue: String, value: Any): Result =
    if url().isEmpty then Result.missingEnv("REDIS_URL or REDIS_HOST")
    else
      try val j = new Jedis(url()); try j.lpush(queue.getBytes, encode(value)) finally j.close(); Result.ok()
      catch case e: Exception => Result.transportError(e.getMessage)

  def Pop(queue: String, timeoutSec: Double = 30.0, maxMessages: Int = 1): Result =
    if url().isEmpty then Result.missingEnv("REDIS_URL or REDIS_HOST")
    else
      try
        val messages = scala.collection.mutable.ListBuffer[Map[String, Any]]()
        val j = new Jedis(url())
        try
          var remaining = math.max(1, maxMessages); var deadline = timeoutSec
          while remaining > 0 && deadline > 0 do
            val wait = if remaining == maxMessages then math.max(1, timeoutSec.toInt) else 1
            val item = j.brpop(wait, queue)
            if item == null || item.size() < 2 then ()
            else
              messages += Map("queue" -> queue, "value" -> decode(item.get(1)))
              remaining -= 1; deadline -= wait
        finally j.close()
        Result.ok(Map("messages" -> messages.toList))
      catch case e: Exception => Result.transportError(e.getMessage)
