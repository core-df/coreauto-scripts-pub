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

package com.coredf.ingress

import com.coredf.cawbs.{CawbsIngress, Result as CawbsResult}

object Ingress:
  def TriggerEvent(payload: Any, eventName: String = null, eventSource: String = null): Result =
    val name = Option(eventName).getOrElse(env("CA_EVENT_NAME"))
    if name.isEmpty then return Result.missingEnv("CA_EVENT_NAME (or pass event_name)")
    val source = Option(eventSource).getOrElse(env("CA_EVENT_SOURCE"))
    val init = CawbsIngress.Init()
    if init.statusCode >= 400 then fromCawbs(init)
    else fromCawbs(CawbsIngress.PostEvent(name, payload, if source.isEmpty then null else source))

  def ForwardMessages(consumeResult: Result): Result =
    if consumeResult.statusCode != 200 then consumeResult
    else
      val msgs = consumeResult.get("messages") match
        case it: Iterable[_] => it.toSeq
        case _ => Seq.empty
      val forwarded = msgs.map { msg =>
        val value = msg match
          case m: Map[_, _] if m.asInstanceOf[Map[String, Any]].contains("value") => m.asInstanceOf[Map[String, Any]]("value")
          case other => other
        val posted = TriggerEvent(value)
        if posted.statusCode >= 400 then return posted
        Map("actionId" -> posted.get("actionId"), "eventId" -> posted.get("eventId")).filter(_._2 != null)
      }
      Result.ok(Map("forwarded" -> forwarded))

  def RunBridge(consumeFn: () => Result): Result = ForwardMessages(consumeFn())

  private def fromCawbs(r: CawbsResult): Result =
    val fields = scala.collection.mutable.Map[String, Any]()
    if r.answer != null then fields ++= r.answer
    if r.error != null then fields("error") = r.error
    if r.payload != null then fields("payload") = r.payload
    Result(r.statusCode, fields.toMap)

  private def env(k: String): String = Option(System.getenv(k)).getOrElse("")
