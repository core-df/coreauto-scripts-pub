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

import jakarta.mail.Message
import jakarta.mail.Session
import jakarta.mail.Transport
import jakarta.mail.internet.InternetAddress
import jakarta.mail.internet.MimeMessage
import java.net.URI
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration
import java.util.Properties

object NotifyClient {
    private val http = java.net.http.HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(30)).build()

    @JvmStatic
    fun Slack(text: String, webhookUrl: String? = null): Result {
        val url = webhookUrl ?: env("SLACK_WEBHOOK_URL")
        if (url.isEmpty()) return Result.missingEnv("SLACK_WEBHOOK_URL")
        return postJson(url, mapOf("text" to text))
    }

    @JvmStatic
    fun Teams(text: String, webhookUrl: String? = null): Result {
        val url = webhookUrl ?: env("TEAMS_WEBHOOK_URL")
        if (url.isEmpty()) return Result.missingEnv("TEAMS_WEBHOOK_URL")
        return postJson(
            url,
            mapOf(
                "@type" to "MessageCard",
                "@context" to "http://schema.org/extensions",
                "text" to text,
            ),
        )
    }

    @JvmStatic
    fun Email(subject: String, body: String, toAddrs: String, fromAddr: String? = null): Result {
        val host = env("SMTP_HOST")
        val port = env("SMTP_PORT", "587").toInt()
        val user = env("SMTP_USER")
        val password = env("SMTP_PASSWORD")
        val sender = fromAddr ?: env("SMTP_FROM", user)
        if (host.isEmpty() || sender.isEmpty()) return Result.missingEnv("SMTP_HOST and SMTP_FROM (or from_addr)")
        return try {
            val props = Properties().apply {
                put("mail.smtp.host", host)
                put("mail.smtp.port", port.toString())
                put("mail.smtp.starttls.enable", "true")
            }
            val session = Session.getInstance(props)
            val msg = MimeMessage(session).apply {
                setFrom(InternetAddress(sender))
                toAddrs.split(",").forEach { addRecipient(Message.RecipientType.TO, InternetAddress(it.trim())) }
                setSubject(subject)
                setText(body)
            }
            val transport = session.getTransport("smtp")
            transport.connect(host, port, user, password)
            Transport.send(msg)
            transport.close()
            Result.ok()
        } catch (e: Exception) {
            Result.transportError(e.message)
        }
    }

    @JvmStatic
    fun PagerDuty(summary: String, routingKey: String? = null, severity: String = "error"): Result {
        val key = routingKey ?: env("PAGERDUTY_ROUTING_KEY")
        if (key.isEmpty()) return Result.missingEnv("PAGERDUTY_ROUTING_KEY")
        val payload = mapOf(
            "routing_key" to key,
            "event_action" to "trigger",
            "payload" to mapOf(
                "summary" to summary,
                "severity" to severity,
                "source" to "coreauto-step",
            ),
        )
        val r = postJson("https://events.pagerduty.com/v2/enqueue", payload)
        return if (r.statusCode == 200 && r.get("body") == null) Result.ok(mapOf("body" to emptyMap<String, Any>())) else r
    }

    private fun postJson(url: String, body: Any): Result = try {
        val req = HttpRequest.newBuilder(URI.create(url))
            .timeout(Duration.ofSeconds(30))
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(JsonUtil.stringify(body)))
            .build()
        val resp = http.send(req, HttpResponse.BodyHandlers.ofString())
        if (resp.statusCode() >= 400) return Result.error(resp.statusCode(), resp.body())
        val parsed = JsonUtil.parse(resp.body())
        val fields = linkedMapOf<String, Any?>()
        if (parsed != null) fields["body"] = parsed
        Result.ok(fields)
    } catch (e: Exception) {
        Result.transportError(e.message)
    }

    private fun env(k: String): String = System.getenv(k) ?: ""
    private fun env(k: String, d: String): String = env(k).ifEmpty { d }
}
