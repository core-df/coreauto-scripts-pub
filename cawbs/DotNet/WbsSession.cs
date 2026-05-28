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
//
// Shared HTTP helpers for the Core Auto Collector (cawbs) .NET client.

using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace CoreAuto.Cawbs;

public sealed class WbsSession
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(60) };

    private bool _initialized;
    private string _baseUrl = "";
    private string _env = "";
    private string _token = "";

    public static Result MissingEnv(string vars) =>
        new() { StatusCode = 601, Error = $"Environment variables {vars} should be defined" };

    private static string TrimUrl(string url) => url.Trim(' ', '/');

    private async Task<(int StatusCode, string? Body, bool TransportError)> DoRequestAsync(
        HttpMethod method,
        string url,
        string? body)
    {
        try
        {
            using var req = new HttpRequestMessage(method, url);
            req.Headers.TryAddWithoutValidation("Environment", _env);
            if (!string.IsNullOrEmpty(_token))
            {
                req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _token);
            }
            if (body != null)
            {
                req.Content = new StringContent(body, Encoding.UTF8, "application/json");
            }

            using var resp = await Http.SendAsync(req).ConfigureAwait(false);
            var text = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
            return ((int)resp.StatusCode, text, false);
        }
        catch
        {
            return (0, null, true);
        }
    }

    private static Result ApiError(int statusCode, string? body)
    {
        if (string.IsNullOrWhiteSpace(body))
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        try
        {
            using var doc = JsonDocument.Parse(body);
            return new Result { StatusCode = statusCode, Error = doc.RootElement.Clone() };
        }
        catch
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
    }

    public async Task<Result> AuthenticateAsync(string env, string accessCode, string baseUrl)
    {
        if (_initialized)
        {
            return new Result { StatusCode = 602, Error = "init already called" };
        }

        _env = env;
        _baseUrl = TrimUrl(baseUrl);
        var todo = JsonSerializer.Serialize(new { apiCode = accessCode });
        var (statusCode, body, transportError) = await DoRequestAsync(
            HttpMethod.Post,
            $"{_baseUrl}/v1/auth/apicode",
            todo).ConfigureAwait(false);

        if (transportError)
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        if (statusCode >= 400)
        {
            return ApiError(statusCode, body);
        }

        using var doc = JsonDocument.Parse(body!);
        if (!doc.RootElement.TryGetProperty("token", out var tokenEl))
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        _token = tokenEl.GetString() ?? "";
        _initialized = true;
        return new Result { StatusCode = statusCode };
    }

    public async Task<Result> GetEventPayloadAsync(string actionId)
    {
        if (!_initialized)
        {
            return new Result { StatusCode = 603, Error = "Init required" };
        }
        var (statusCode, body, transportError) = await DoRequestAsync(
            HttpMethod.Get,
            $"{_baseUrl}/v1/rtevent/{actionId}",
            null).ConfigureAwait(false);
        if (transportError)
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        if (statusCode >= 400)
        {
            return ApiError(statusCode, body);
        }
        using var doc = JsonDocument.Parse(body!);
        if (!doc.RootElement.TryGetProperty("payload", out var payload))
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        return new Result { StatusCode = statusCode, Payload = payload.Clone() };
    }

    public async Task<Result> PutStepPayloadAsync(string actionId, string stepName, object payload)
    {
        if (!_initialized)
        {
            return new Result { StatusCode = 603, Error = "Init required" };
        }
        var todo = JsonSerializer.Serialize(new { actionId, stepname = stepName, payload });
        var (statusCode, body, transportError) = await DoRequestAsync(
            HttpMethod.Post,
            $"{_baseUrl}/v1/rtstep/payload",
            todo).ConfigureAwait(false);
        if (transportError)
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        if (statusCode >= 400)
        {
            return ApiError(statusCode, body);
        }
        return new Result { StatusCode = statusCode };
    }

    public async Task<Result> GetStepPayloadAsync(string actionId, string stepName)
    {
        if (!_initialized)
        {
            return new Result { StatusCode = 603, Error = "Init required" };
        }
        var (statusCode, body, transportError) = await DoRequestAsync(
            HttpMethod.Get,
            $"{_baseUrl}/v1/rtstep/payload/{actionId}/{stepName}",
            null).ConfigureAwait(false);
        if (transportError)
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        if (statusCode >= 400)
        {
            return ApiError(statusCode, body);
        }
        using var doc = JsonDocument.Parse(body!);
        if (!doc.RootElement.TryGetProperty("payload", out var payload))
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        return new Result { StatusCode = statusCode, Payload = payload.Clone() };
    }

    public async Task<Result> PostEventAsync(string eventName, object payload, string? eventSource = null)
    {
        if (!_initialized)
        {
            return new Result { StatusCode = 603, Error = "Init required" };
        }
        var body = new Dictionary<string, object?> { ["eventName"] = eventName, ["payload"] = payload };
        if (eventSource != null)
        {
            body["eventSource"] = eventSource;
        }
        var (statusCode, responseBody, transportError) = await DoRequestAsync(
            HttpMethod.Post,
            $"{_baseUrl}/v1/rtevent",
            JsonSerializer.Serialize(body)).ConfigureAwait(false);
        if (transportError)
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        if (statusCode >= 400)
        {
            return ApiError(statusCode, responseBody);
        }
        using var doc = JsonDocument.Parse(responseBody!);
        var resultPayload = new Dictionary<string, JsonElement>();
        if (doc.RootElement.TryGetProperty("eventId", out var eventId))
        {
            resultPayload["eventId"] = eventId.Clone();
        }
        if (doc.RootElement.TryGetProperty("actionId", out var actionId))
        {
            resultPayload["actionId"] = actionId.Clone();
        }
        if (doc.RootElement.TryGetProperty("createdAt", out var createdAt))
        {
            resultPayload["createdAt"] = createdAt.Clone();
        }
        return new Result { StatusCode = statusCode, Payload = JsonSerializer.SerializeToElement(resultPayload) };
    }

    public async Task<Result> GetEventStatusAsync(string actionId)
    {
        if (!_initialized)
        {
            return new Result { StatusCode = 603, Error = "Init required" };
        }
        var (statusCode, body, transportError) = await DoRequestAsync(
            HttpMethod.Get,
            $"{_baseUrl}/v1/rtevent/status/{actionId}",
            null).ConfigureAwait(false);
        if (transportError)
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        if (statusCode >= 400)
        {
            return ApiError(statusCode, body);
        }
        using var doc = JsonDocument.Parse(body!);
        return new Result { StatusCode = statusCode, Payload = doc.RootElement.Clone() };
    }

    public async Task<Result> GetEventListAsync()
    {
        if (!_initialized)
        {
            return new Result { StatusCode = 603, Error = "Init required" };
        }
        var (statusCode, body, transportError) = await DoRequestAsync(
            HttpMethod.Get,
            $"{_baseUrl}/v1/rtevent/list",
            null).ConfigureAwait(false);
        if (transportError)
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        if (statusCode >= 400)
        {
            return ApiError(statusCode, body);
        }
        using var doc = JsonDocument.Parse(body!);
        return new Result { StatusCode = statusCode, Payload = doc.RootElement.Clone() };
    }

    public async Task<Result> SubmitFlagAsync(
        string name,
        string systemName,
        string sourceSystemName,
        string date)
    {
        if (!_initialized)
        {
            return new Result { StatusCode = 603, Error = "Init required" };
        }
        var todo = JsonSerializer.Serialize(new
        {
            name,
            systemName,
            sourceSystemName,
            date,
        });
        var (statusCode, body, transportError) = await DoRequestAsync(
            HttpMethod.Post,
            $"{_baseUrl}/v1/flag",
            todo).ConfigureAwait(false);
        if (transportError)
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        if (statusCode >= 400)
        {
            return ApiError(statusCode, body);
        }
        using var doc = JsonDocument.Parse(body!);
        if (!doc.RootElement.TryGetProperty("status", out var status))
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        var resultPayload = JsonSerializer.SerializeToElement(new Dictionary<string, JsonElement>
        {
            ["flagStatus"] = status.Clone(),
        });
        return new Result { StatusCode = statusCode, Payload = resultPayload };
    }

    public async Task<Result> GetKeystoreAsync(string keylist)
    {
        if (!_initialized)
        {
            return new Result { StatusCode = 603, Error = "Init required" };
        }
        var keys = keylist.Replace(" ", "");
        var (statusCode, body, transportError) = await DoRequestAsync(
            HttpMethod.Get,
            $"{_baseUrl}/v1/keystore/{keys}",
            null).ConfigureAwait(false);
        if (transportError)
        {
            return new Result { StatusCode = statusCode, Error = "inaccessible" };
        }
        if (statusCode >= 400)
        {
            return ApiError(statusCode, body);
        }

        using var doc = JsonDocument.Parse(body!);
        var answer = new Dictionary<string, JsonElement>();
        foreach (var prop in doc.RootElement.EnumerateObject())
        {
            answer[prop.Name] = prop.Value.Clone();
        }
        foreach (var key in keys.Split(',', StringSplitOptions.RemoveEmptyEntries))
        {
            if (!answer.ContainsKey(key))
            {
                return new Result { StatusCode = 605, Error = $"{key} not found" };
            }
        }
        return new Result { StatusCode = statusCode, Answer = answer };
    }
}
