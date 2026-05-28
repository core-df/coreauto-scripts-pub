// Copyright Core DF

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

package com.coredf.cawbs

import java.net.URI
import java.net.http.{HttpClient, HttpRequest, HttpResponse}
import java.time.Duration
import scala.jdk.CollectionConverters.*

final class WbsSession:
  private var initialized = false
  private var baseUrl = ""
  private var env = ""
  private var token = ""
  private val http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(60)).build()

object WbsSession:
  def missingEnv(vars: String): Result =
    Result(601, error = Some(s"Environment variables $vars should be defined"))

  private def trimUrl(url: String): String = url.trim.stripPrefix("/").stripSuffix("/").trim

private case class HttpOutcome(statusCode: Int, body: String, transportError: Boolean)

extension (s: WbsSession)
  private def request(method: String, url: String, body: String | Null = null): HttpOutcome =
    try
      val builder = HttpRequest.newBuilder(URI.create(url))
        .timeout(Duration.ofSeconds(60))
        .header("Content-Type", "application/json")
        .header("Environment", s.env)
      if s.token.nonEmpty then builder.header("Authorization", s"Bearer ${s.token}")
      if body != null then builder.method(method, HttpRequest.BodyPublishers.ofString(body))
      else builder.method(method, HttpRequest.BodyPublishers.noBody())
      val resp = s.http.send(builder.build(), HttpResponse.BodyHandlers.ofString())
      HttpOutcome(resp.statusCode(), resp.body(), false)
    catch
      case _: Exception => HttpOutcome(0, "", true)

  private def apiError(statusCode: Int, body: String): Result =
    Json.parse(body) match
      case Some(v) => Result(statusCode, error = Some(v))
      case None    => Result(statusCode, error = Some("inaccessible"))

  def authenticate(env: String, accessCode: String, baseUrl: String): Result =
    if s.initialized then return Result(602, error = Some("init already called"))
    s.env = env
    s.baseUrl = WbsSession.trimUrl(baseUrl)
    val todo = Json.stringify(Map("apiCode" -> accessCode))
    val out = s.request("POST", s"${s.baseUrl}/v1/auth/apicode", todo)
    if out.transportError then return Result(out.statusCode, error = Some("inaccessible"))
    if out.statusCode >= 400 then return s.apiError(out.statusCode, out.body)
    Json.parse(out.body).flatMap(_.asInstanceOf[Map[String, Any]].get("token")) match
      case Some(t: String) if t.nonEmpty =>
        s.token = t
        s.initialized = true
        Result(out.statusCode)
      case _ => Result(out.statusCode, error = Some("inaccessible"))

  def getEventPayload(actionId: String): Result =
    if !s.initialized then return Result(603, error = Some("Init required"))
    val out = s.request("GET", s"${s.baseUrl}/v1/rtevent/$actionId")
    if out.transportError then return Result(out.statusCode, error = Some("inaccessible"))
    if out.statusCode >= 400 then return s.apiError(out.statusCode, out.body)
    Json.parse(out.body).flatMap(_.asInstanceOf[Map[String, Any]].get("payload")) match
      case Some(p) => Result(out.statusCode, payload = Some(p))
      case None    => Result(out.statusCode, error = Some("inaccessible"))

  def putStepPayload(actionId: String, stepName: String, payload: Any): Result =
    if !s.initialized then return Result(603, error = Some("Init required"))
    val todo = Json.stringify(Map("actionId" -> actionId, "stepname" -> stepName, "payload" -> payload))
    val out = s.request("POST", s"${s.baseUrl}/v1/rtstep/payload", todo)
    if out.transportError then return Result(out.statusCode, error = Some("inaccessible"))
    if out.statusCode >= 400 then return s.apiError(out.statusCode, out.body)
    Result(out.statusCode)

  def getStepPayload(actionId: String, stepName: String): Result =
    if !s.initialized then return Result(603, error = Some("Init required"))
    val out = s.request("GET", s"${s.baseUrl}/v1/rtstep/payload/$actionId/$stepName")
    if out.transportError then return Result(out.statusCode, error = Some("inaccessible"))
    if out.statusCode >= 400 then return s.apiError(out.statusCode, out.body)
    Json.parse(out.body).flatMap(_.asInstanceOf[Map[String, Any]].get("payload")) match
      case Some(p) => Result(out.statusCode, payload = Some(p))
      case None    => Result(out.statusCode, error = Some("inaccessible"))

  def postEvent(eventName: String, payload: Any, eventSource: String | Null = null): Result =
    if !s.initialized then return Result(603, error = Some("Init required"))
    val body = scala.collection.mutable.Map[String, Any]("eventName" -> eventName, "payload" -> payload)
    if eventSource != null then body("eventSource") = eventSource
    val out = s.request("POST", s"${s.baseUrl}/v1/rtevent", Json.stringify(body.toMap))
    if out.transportError then return Result(out.statusCode, error = Some("inaccessible"))
    if out.statusCode >= 400 then return s.apiError(out.statusCode, out.body)
    Json.parse(out.body) match
      case Some(map: Map[?, ?] @unchecked) =>
        val m = map.asInstanceOf[Map[String, Any]]
        val resultPayload = Map.newBuilder[String, Any]
        m.get("eventId").foreach(v => resultPayload += "eventId" -> v)
        m.get("actionId").foreach(v => resultPayload += "actionId" -> v)
        m.get("createdAt").foreach(v => resultPayload += "createdAt" -> v)
        Result(out.statusCode, payload = Some(resultPayload.result()))
      case _ => Result(out.statusCode, error = Some("inaccessible"))

  def getEventStatus(actionId: String): Result =
    if !s.initialized then return Result(603, error = Some("Init required"))
    val out = s.request("GET", s"${s.baseUrl}/v1/rtevent/status/$actionId")
    if out.transportError then return Result(out.statusCode, error = Some("inaccessible"))
    if out.statusCode >= 400 then return s.apiError(out.statusCode, out.body)
    Json.parse(out.body) match
      case Some(v) => Result(out.statusCode, payload = Some(v))
      case None    => Result(out.statusCode, error = Some("inaccessible"))

  def getEventList(): Result =
    if !s.initialized then return Result(603, error = Some("Init required"))
    val out = s.request("GET", s"${s.baseUrl}/v1/rtevent/list")
    if out.transportError then return Result(out.statusCode, error = Some("inaccessible"))
    if out.statusCode >= 400 then return s.apiError(out.statusCode, out.body)
    Json.parse(out.body) match
      case Some(v) => Result(out.statusCode, payload = Some(v))
      case None    => Result(out.statusCode, error = Some("inaccessible"))

  def submitFlag(name: String, systemName: String, sourceSystemName: String, date: String): Result =
    if !s.initialized then return Result(603, error = Some("Init required"))
    val body = Map(
      "name" -> name,
      "systemName" -> systemName,
      "sourceSystemName" -> sourceSystemName,
      "date" -> date
    )
    val out = s.request("POST", s"${s.baseUrl}/v1/flag", Json.stringify(body))
    if out.transportError then return Result(out.statusCode, error = Some("inaccessible"))
    if out.statusCode >= 400 then return s.apiError(out.statusCode, out.body)
    Json.parse(out.body).flatMap(_.asInstanceOf[Map[String, Any]].get("status")) match
      case Some(status) => Result(out.statusCode, payload = Some(Map("flagStatus" -> status)))
      case None         => Result(out.statusCode, error = Some("inaccessible"))

  def getKeystore(keylist: String): Result =
    if !s.initialized then return Result(603, error = Some("Init required"))
    val keys = keylist.replace(" ", "")
    val out = s.request("GET", s"${s.baseUrl}/v1/keystore/$keys")
    if out.transportError then return Result(out.statusCode, error = Some("inaccessible"))
    if out.statusCode >= 400 then return s.apiError(out.statusCode, out.body)
    Json.parse(out.body) match
      case Some(map: Map[?, ?] @unchecked) =>
        val answer = map.asInstanceOf[Map[String, Any]]
        keys.split(",").filter(_.nonEmpty).find(k => !answer.contains(k)) match
          case Some(k) => Result(605, error = Some(s"$k not found"))
          case None    => Result(out.statusCode, answer = Some(answer))
      case _ => Result(out.statusCode, error = Some("inaccessible"))
