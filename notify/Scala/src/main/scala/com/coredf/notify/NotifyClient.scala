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

package com.coredf.notify

import jakarta.mail.internet.{InternetAddress, MimeMessage}
import jakarta.mail.{Message, Session, Transport}
import java.net.URI
import java.net.http.{HttpRequest, HttpResponse}
import java.time.Duration
import java.util.Properties

object NotifyClient:
  private val http = java.net.http.HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(30)).build()

  def Slack(text: String, webhookUrl: String = null): Result =
    val url = Option(webhookUrl).filter(_.nonEmpty).getOrElse(env("SLACK_WEBHOOK_URL"))
    if url.isEmpty then Result.missingEnv("SLACK_WEBHOOK_URL")
    else postJson(url, Map("text" -> text))

  def Teams(text: String, webhookUrl: String = null): Result =
    val url = Option(webhookUrl).filter(_.nonEmpty).getOrElse(env("TEAMS_WEBHOOK_URL"))
    if url.isEmpty then Result.missingEnv("TEAMS_WEBHOOK_URL")
    else postJson(url, Map("@type" -> "MessageCard", "@context" -> "http://schema.org/extensions", "text" -> text))

  def Email(subject: String, body: String, toAddrs: String, fromAddr: String = null): Result =
    val host = env("SMTP_HOST")
    val port = env("SMTP_PORT", "587").toInt
    val user = env("SMTP_USER")
    val password = env("SMTP_PASSWORD")
    val sender = Option(fromAddr).filter(_.nonEmpty).getOrElse(env("SMTP_FROM", user))
    if host.isEmpty || sender.isEmpty then Result.missingEnv("SMTP_HOST and SMTP_FROM (or from_addr)")
    else try
      val props = new Properties()
      props.put("mail.smtp.host", host)
      props.put("mail.smtp.port", port.toString)
      props.put("mail.smtp.starttls.enable", "true")
      val session = Session.getInstance(props)
      val msg = new MimeMessage(session)
      msg.setFrom(new InternetAddress(sender))
      toAddrs.split(",").foreach(a => msg.addRecipient(Message.RecipientType.TO, new InternetAddress(a.trim)))
      msg.setSubject(subject)
      msg.setText(body)
      Transport.send(msg)
      Result.ok()
    catch case e: Exception => Result.transportError(e.getMessage)

  def PagerDuty(summary: String, routingKey: String = null, severity: String = "error"): Result =
    val key = Option(routingKey).filter(_.nonEmpty).getOrElse(env("PAGERDUTY_ROUTING_KEY"))
    if key.isEmpty then Result.missingEnv("PAGERDUTY_ROUTING_KEY")
    else
      val payload = Map(
        "routing_key" -> key,
        "event_action" -> "trigger",
        "payload" -> Map("summary" -> summary, "severity" -> severity, "source" -> "coreauto-step"),
      )
      val r = postJson("https://events.pagerduty.com/v2/enqueue", payload)
      if r.statusCode == 200 && r.get("body") == null then Result.ok(Map("body" -> Map.empty[String, Any]))
      else r

  private def postJson(url: String, body: Any): Result =
    try
      val req = HttpRequest.newBuilder(URI.create(url))
        .timeout(Duration.ofSeconds(30))
        .header("Content-Type", "application/json")
        .POST(HttpRequest.BodyPublishers.ofString(JsonUtil.stringify(body)))
        .build()
      val resp = http.send(req, HttpResponse.BodyHandlers.ofString())
      if resp.statusCode() >= 400 then Result.error(resp.statusCode(), resp.body())
      else
        val parsed = JsonUtil.parse(resp.body())
        val fields = scala.collection.mutable.LinkedHashMap[String, Any]()
        if parsed != null then fields("body") = parsed
        Result.ok(fields.toMap)
    catch case e: Exception => Result.transportError(e.getMessage)

  private def env(k: String): String = Option(System.getenv(k)).getOrElse("")
  private def env(k: String, d: String): String = val v = env(k); if v.isEmpty then d else v
