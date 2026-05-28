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
using System.Text.Json;

namespace CoreAuto.Http;

public static class HttpClient
{
    private static readonly System.Net.Http.HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(60) };

    public static async Task<Result> GetAsync(string url, Dictionary<string, string>? headers = null, Dictionary<string, string>? parameters = null)
    {
        if (parameters is { Count: > 0 })
        {
            var qs = string.Join("&", parameters.Select(kv => $"{Uri.EscapeDataString(kv.Key)}={Uri.EscapeDataString(kv.Value)}"));
            url += url.Contains('?') ? "&" + qs : "?" + qs;
        }
        using var req = new HttpRequestMessage(HttpMethod.Get, url);
        if (headers != null) foreach (var (k, v) in headers) req.Headers.TryAddWithoutValidation(k, v);
        return await SendAsync(req);
    }

    public static async Task<Result> PostAsync(string url, object? jsonBody = null, string? data = null, Dictionary<string, string>? headers = null)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, url);
        if (headers != null) foreach (var (k, v) in headers) req.Headers.TryAddWithoutValidation(k, v);
        if (jsonBody != null) req.Content = JsonContent.Create(jsonBody);
        else if (data != null) req.Content = new StringContent(data, System.Text.Encoding.UTF8);
        return await SendAsync(req);
    }

    public static async Task<Result> PutAsync(string url, object? jsonBody = null, Dictionary<string, string>? headers = null)
    {
        using var req = new HttpRequestMessage(HttpMethod.Put, url);
        if (headers != null) foreach (var (k, v) in headers) req.Headers.TryAddWithoutValidation(k, v);
        if (jsonBody != null) req.Content = JsonContent.Create(jsonBody);
        return await SendAsync(req);
    }

    public static async Task<Result> DeleteAsync(string url, Dictionary<string, string>? headers = null)
    {
        using var req = new HttpRequestMessage(HttpMethod.Delete, url);
        if (headers != null) foreach (var (k, v) in headers) req.Headers.TryAddWithoutValidation(k, v);
        return await SendAsync(req);
    }

    private static async Task<Result> SendAsync(HttpRequestMessage req)
    {
        try
        {
            using var resp = await Http.SendAsync(req);
            var text = await resp.Content.ReadAsStringAsync();
            object? body = ParseBody(text);
            if ((int)resp.StatusCode >= 400) return Result.Error((int)resp.StatusCode, body ?? "inaccessible");
            return Result.Ok(new Dictionary<string, object?> { ["body"] = body });
        }
        catch (Exception ex) { return Result.TransportError(ex.Message); }
    }

    private static object? ParseBody(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;
        var t = text.Trim();
        if ((t.StartsWith('{') && t.EndsWith('}')) || (t.StartsWith('[') && t.EndsWith(']')))
        {
            try { return JsonSerializer.Deserialize<JsonElement>(text); } catch { }
        }
        return text;
    }
}
