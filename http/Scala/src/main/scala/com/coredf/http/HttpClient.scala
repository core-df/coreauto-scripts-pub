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

package com.coredf.http
import java.net.URI
import java.net.URLEncoder
import java.net.http.{HttpRequest, HttpResponse}
import java.nio.charset.StandardCharsets
import java.time.Duration

object HttpClient:
  private val http = java.net.http.HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(60)).build()

  private def parseBody(body: String): Any =
    if body == null || body.isEmpty then null
    else
      val t = body.trim
      if ((t.startsWith("{") && t.endsWith("}")) || (t.startsWith("[") && t.endsWith("]"))) then
        try JsonUtil.parse(body) catch case _: Exception => body
      else body

  private def request(method: String, url: String, headers: Map[String, String], jsonBody: String, params: Map[String, String]): Result =
    try
      var u = url
      if params.nonEmpty then
        val qs = params.map { case (k, v) => URLEncoder.encode(k, StandardCharsets.UTF_8) + "=" + URLEncoder.encode(v, StandardCharsets.UTF_8) }.mkString("&")
        u = u + (if u.contains("?") then "&" else "?") + qs
      val hdrs = scala.collection.mutable.Map(headers.toSeq*)
      if jsonBody != null then hdrs.putIfAbsent("Content-Type", "application/json")
      val b = HttpRequest.newBuilder(URI.create(u)).timeout(Duration.ofSeconds(60))
      hdrs.foreach { case (k, v) => b.header(k, v) }
      if jsonBody != null then b.method(method, HttpRequest.BodyPublishers.ofString(jsonBody))
      else b.method(method, HttpRequest.BodyPublishers.noBody())
      val resp = http.send(b.build(), HttpResponse.BodyHandlers.ofString())
      val body = parseBody(resp.body())
      if resp.statusCode() >= 400 then Result.error(resp.statusCode(), if body != null then body else "inaccessible")
      else Result.ok(Map("body" -> body))
    catch case e: Exception => Result.transportError(e.getMessage)

  def Get(url: String, headers: Map[String, String] = Map.empty, params: Map[String, String] = Map.empty): Result =
    request("GET", url, headers, null, params)
  def Post(url: String, jsonBody: Any = null, data: String = null, headers: Map[String, String] = Map.empty): Result =
    request("POST", url, headers, if jsonBody != null then JsonUtil.stringify(jsonBody) else data, Map.empty)
  def Put(url: String, jsonBody: Any = null, headers: Map[String, String] = Map.empty): Result =
    request("PUT", url, headers, if jsonBody != null then JsonUtil.stringify(jsonBody) else null, Map.empty)
  def Delete(url: String, headers: Map[String, String] = Map.empty): Result =
    request("DELETE", url, headers, null, Map.empty)
