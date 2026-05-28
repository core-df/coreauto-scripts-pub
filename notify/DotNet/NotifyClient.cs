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

using System.Net.Http.Json;
using System.Net.Mail;
using System.Text.Json;

namespace CoreAuto.Notify;

public static class NotifyClient
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(30) };

    public static async Task<Result> SlackAsync(string text, string? webhookUrl = null)
    {
        var url = webhookUrl ?? Env("SLACK_WEBHOOK_URL");
        if (string.IsNullOrEmpty(url)) return Result.MissingEnv("SLACK_WEBHOOK_URL");
        return await PostJsonAsync(url, new { text });
    }

    public static async Task<Result> TeamsAsync(string text, string? webhookUrl = null)
    {
        var url = webhookUrl ?? Env("TEAMS_WEBHOOK_URL");
        if (string.IsNullOrEmpty(url)) return Result.MissingEnv("TEAMS_WEBHOOK_URL");
        return await PostJsonAsync(url, new { type = "MessageCard", context = "http://schema.org/extensions", text });
    }

    public static Result Email(string subject, string body, string toAddrs, string? fromAddr = null)
    {
        var host = Env("SMTP_HOST"); var port = int.Parse(Env("SMTP_PORT", "587"));
        var user = Env("SMTP_USER"); var password = Env("SMTP_PASSWORD");
        var sender = fromAddr ?? Env("SMTP_FROM", user);
        if (string.IsNullOrEmpty(host) || string.IsNullOrEmpty(sender)) return Result.MissingEnv("SMTP_HOST and SMTP_FROM (or from_addr)");
        try {
            using var client = new SmtpClient(host, port) { EnableSsl = true, Credentials = string.IsNullOrEmpty(user) ? null : new System.Net.NetworkCredential(user, password) };
            using var msg = new MailMessage(sender, toAddrs.Split(',')[0].Trim(), subject, body);
            foreach (var a in toAddrs.Split(',').Skip(1)) msg.To.Add(a.Trim());
            client.Send(msg); return Result.Ok();
        } catch (Exception ex) { return Result.TransportError(ex.Message); }
    }

    public static async Task<Result> PagerDutyAsync(string summary, string? routingKey = null, string severity = "error")
    {
        var key = routingKey ?? Env("PAGERDUTY_ROUTING_KEY");
        if (string.IsNullOrEmpty(key)) return Result.MissingEnv("PAGERDUTY_ROUTING_KEY");
        var payload = new { routing_key = key, event_action = "trigger", payload = new { summary, severity, source = "coreauto-step" } };
        return await PostJsonAsync("https://events.pagerduty.com/v2/enqueue", payload);
    }

    private static async Task<Result> PostJsonAsync(string url, object body)
    {
        try {
            using var resp = await Http.PostAsJsonAsync(url, body);
            var text = await resp.Content.ReadAsStringAsync();
            if ((int)resp.StatusCode >= 400) return Result.Error((int)resp.StatusCode, text);
            var extra = new Dictionary<string, object?>();
            if (!string.IsNullOrWhiteSpace(text)) extra["body"] = JsonSerializer.Deserialize<JsonElement>(text);
            return Result.Ok(extra.Count > 0 ? extra : null);
        } catch (Exception ex) { return Result.TransportError(ex.Message); }
    }

    private static string Env(string k, string d = "") => Environment.GetEnvironmentVariable(k) ?? d;
}
