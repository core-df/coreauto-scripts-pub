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

object IbmMqClient:

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
    if env("MQ_HOST").isEmpty || env("MQ_QUEUE_MANAGER").isEmpty then Result.missingEnv("MQ_HOST and MQ_QUEUE_MANAGER")
    else if env("MQ_QUEUE").isEmpty then Result.missingEnv("MQ_QUEUE (or pass queue per call)")
    else Result.ok()

  def Put(value: Any, queue: String = null): Result =
    val q = Option(queue).getOrElse(env("MQ_QUEUE"))
    if q.isEmpty then Result.missingEnv("MQ_QUEUE")
    else try send(q, encode(value)); Result.ok() catch case e: Exception => Result.transportError(e.getMessage)

  def Get(queue: String = null, timeoutSec: Double = 30.0, maxMessages: Int = 1): Result =
    val q = Option(queue).getOrElse(env("MQ_QUEUE"))
    if q.isEmpty then Result.missingEnv("MQ_QUEUE")
    else
      try
        val messages = scala.collection.mutable.ListBuffer[Map[String, Any]]()
        var i = 0
        while i < math.max(1, maxMessages) do
          val body = receive(q, (timeoutSec * 1000).toLong)
          if body == null then i = maxMessages
          else messages += Map("queue" -> q, "value" -> decode(body)); i += 1
        Result.ok(Map("messages" -> messages.toList))
      catch case e: Exception => Result.transportError(e.getMessage)

  private def connect(): Connection =
    val f = new MQConnectionFactory()
    f.setHostName(env("MQ_HOST"))
    f.setPort(envOr("MQ_PORT", "1414").toInt)
    f.setQueueManager(env("MQ_QUEUE_MANAGER"))
    f.setChannel(envOr("MQ_CHANNEL", "SYSTEM.DEF.SVRCONN"))
    f.setTransportType(WMQConstants.WMQ_CM_CLIENT)
    val user = env("MQ_USER")
    if user.isEmpty then f.createConnection() else f.createConnection(user, env("MQ_PASSWORD"))

  private def send(queue: String, body: Array[Byte]): Unit =
    val conn = connect(); conn.start()
    try
      val s = conn.createSession(false, Session.AUTO_ACKNOWLEDGE)
      try
        val q = s.createQueue(queue); val p = s.createProducer(q)
        val m = s.createBytesMessage(); m.writeBytes(body); p.send(m)
      finally s.close()
    finally conn.close()

  private def receive(queue: String, waitMs: Long): Array[Byte] =
    val conn = connect(); conn.start()
    try
      val s = conn.createSession(false, Session.AUTO_ACKNOWLEDGE)
      try
        val q = s.createQueue(queue); val c = s.createConsumer(q)
        val msg = c.receive(waitMs)
        if msg == null then null
        else msg match
          case bm: BytesMessage =>
            val b = new Array[Byte](bm.getBodyLength.toInt); bm.readBytes(b); b
          case other => other.toString.getBytes
      finally s.close()
    finally conn.close()
