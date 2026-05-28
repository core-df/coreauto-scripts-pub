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

using CoreAuto.Cawbs;

namespace CoreAuto.Ingress;

public static class Ingress
{
    public static async Task<Result> TriggerEventAsync(object payload, string? eventName = null, string? eventSource = null)
    {
        var name = eventName ?? Env("CA_EVENT_NAME");
        if (string.IsNullOrEmpty(name)) return Result.MissingEnv("CA_EVENT_NAME (or pass event_name)");
        var source = eventSource ?? Env("CA_EVENT_SOURCE");
        var init = await CawbsIngress.InitAsync();
        if (init.StatusCode >= 400) return FromCawbs(init);
        var posted = await CawbsIngress.PostEventAsync(name, payload, string.IsNullOrEmpty(source) ? null : source);
        return FromCawbs(posted);
    }

    public static async Task<Result> ForwardMessagesAsync(Result consumeResult)
    {
        if (consumeResult.StatusCode != 200) return consumeResult;
        if (consumeResult.Extra == null || !consumeResult.Extra.TryGetValue("messages", out var raw)
            || raw is not IEnumerable<object> msgs)
        {
            return Result.Ok(new Dictionary<string, object?> { ["forwarded"] = Array.Empty<object>() });
        }

        var forwarded = new List<Dictionary<string, object?>>();
        foreach (var msg in msgs)
        {
            object value = msg;
            if (msg is Dictionary<string, object?> map && map.TryGetValue("value", out var v)) value = v!;
            var posted = await TriggerEventAsync(value);
            if (posted.StatusCode >= 400) return posted;
            var entry = new Dictionary<string, object?>();
            if (posted.Extra?.TryGetValue("actionId", out var actionId) == true) entry["actionId"] = actionId;
            if (posted.Extra?.TryGetValue("eventId", out var eventId) == true) entry["eventId"] = eventId;
            forwarded.Add(entry);
        }
        return Result.Ok(new Dictionary<string, object?> { ["forwarded"] = forwarded });
    }

    public static async Task<Result> RunBridgeAsync(Func<Task<Result>> consumeFn) =>
        await ForwardMessagesAsync(await consumeFn());

    private static Result FromCawbs(Cawbs.Result r)
    {
        var extra = new Dictionary<string, object?>();
        if (r.Answer != null)
        {
            foreach (var (k, v) in r.Answer) extra[k] = v;
        }
        if (r.Error != null) extra["error"] = r.Error;
        if (r.Payload != null) extra["payload"] = r.Payload;
        return new Result { StatusCode = r.StatusCode, Extra = extra.Count > 0 ? extra : null };
    }

    private static string Env(string key) => Environment.GetEnvironmentVariable(key) ?? "";
}
