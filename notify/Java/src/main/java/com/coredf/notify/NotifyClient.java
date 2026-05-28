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

package com.coredf.notify;
import jakarta.mail.*; import jakarta.mail.internet.*; import java.net.URI; import java.net.http.*; import java.time.Duration; import java.util.*;

public final class NotifyClient {
    private static final java.net.http.HttpClient HTTP = java.net.http.HttpClient.newHttpClient();
    private NotifyClient() {}
    public static Result Slack(String text, String webhookUrl) {
        String url = webhookUrl != null ? webhookUrl : env("SLACK_WEBHOOK_URL");
        if (url.isEmpty()) return Result.missingEnv("SLACK_WEBHOOK_URL");
        return postJson(url, Map.of("text", text));
    }
    public static Result Slack(String text) { return Slack(text, null); }
    public static Result Teams(String text, String webhookUrl) {
        String url = webhookUrl != null ? webhookUrl : env("TEAMS_WEBHOOK_URL");
        if (url.isEmpty()) return Result.missingEnv("TEAMS_WEBHOOK_URL");
        return postJson(url, Map.of("@type", "MessageCard", "@context", "http://schema.org/extensions", "text", text));
    }
    public static Result Teams(String text) { return Teams(text, null); }
    public static Result Email(String subject, String body, String toAddrs, String fromAddr) {
        String host = env("SMTP_HOST"); int port = Integer.parseInt(envOr("SMTP_PORT", "587"));
        String user = env("SMTP_USER"); String password = env("SMTP_PASSWORD");
        String sender = fromAddr != null ? fromAddr : envOr("SMTP_FROM", user);
        if (host.isEmpty() || sender.isEmpty()) return Result.missingEnv("SMTP_HOST and SMTP_FROM (or from_addr)");
        try {
            Properties props = new Properties(); props.put("mail.smtp.host", host); props.put("mail.smtp.port", String.valueOf(port));
            Session session = Session.getInstance(props);
            MimeMessage msg = new MimeMessage(session); msg.setFrom(new InternetAddress(sender));
            for (String a : toAddrs.split(",")) msg.addRecipient(Message.RecipientType.TO, new InternetAddress(a.trim()));
            msg.setSubject(subject); msg.setText(body);
            Transport transport = session.getTransport("smtp"); transport.connect(host, port, user, password);
            if (!user.isEmpty() && !password.isEmpty()) { /* starttls via props */ props.put("mail.smtp.starttls.enable", "true"); }
            Transport.send(msg); return Result.ok();
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    public static Result Email(String subject, String body, String toAddrs) { return Email(subject, body, toAddrs, null); }
    public static Result PagerDuty(String summary, String routingKey, String severity) {
        String key = routingKey != null ? routingKey : env("PAGERDUTY_ROUTING_KEY");
        if (key.isEmpty()) return Result.missingEnv("PAGERDUTY_ROUTING_KEY");
        Map<String, Object> payload = Map.of("routing_key", key, "event_action", "trigger",
            "payload", Map.of("summary", summary, "severity", severity, "source", "coreauto-step"));
        Result r = postJson("https://events.pagerduty.com/v2/enqueue", payload);
        if (r.getStatusCode() == 200 && r.get("body") == null) return Result.ok(Map.of("body", Map.of()));
        return r;
    }
    public static Result PagerDuty(String summary) { return PagerDuty(summary, null, "error"); }
    private static Result postJson(String url, Object body) {
        try {
            HttpRequest req = HttpRequest.newBuilder(URI.create(url)).timeout(Duration.ofSeconds(30))
                .header("Content-Type", "application/json").POST(HttpRequest.BodyPublishers.ofString(JsonUtil.stringify(body))).build();
            HttpResponse<String> resp = HTTP.send(req, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() >= 400) return Result.error(resp.statusCode(), resp.body());
            Object parsed = JsonUtil.parse(resp.body()); Map<String, Object> m = new LinkedHashMap<>();
            if (parsed != null) m.put("body", parsed); return Result.ok(m);
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    private static String env(String k) { String v = System.getenv(k); return v == null ? "" : v; }
    private static String envOr(String k, String d) { String v = System.getenv(k); return v == null || v.isEmpty() ? d : v; }
}
