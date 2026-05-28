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

using Confluent.Kafka;
using System.Text.Json;

namespace CoreAuto.Kafka;

public static class KafkaClient
{
    public static Result Init() =>
        string.IsNullOrEmpty(Env("KAFKA_BOOTSTRAP_SERVERS"))
            ? Result.MissingEnv("KAFKA_BOOTSTRAP_SERVERS")
            : Result.Ok();

    public static Result Produce(string topic, object? value, string? key = null)
    {
        if (string.IsNullOrEmpty(Env("KAFKA_BOOTSTRAP_SERVERS"))) return Result.MissingEnv("KAFKA_BOOTSTRAP_SERVERS");
        var cfg = new ProducerConfig { BootstrapServers = Env("KAFKA_BOOTSTRAP_SERVERS") };
        using var producer = new ProducerBuilder<string, byte[]>(cfg).Build();
        try
        {
            producer.Produce(topic, new Message<string, byte[]> { Key = key, Value = Encode(value) })
                .Wait(TimeSpan.FromSeconds(30));
            return Result.Ok();
        }
        catch (Exception ex) { return Result.TransportError(ex.Message); }
    }

    public static Result Consume(string topic, double timeoutSec = 30, int maxMessages = 1, string? groupId = null)
    {
        if (string.IsNullOrEmpty(Env("KAFKA_BOOTSTRAP_SERVERS"))) return Result.MissingEnv("KAFKA_BOOTSTRAP_SERVERS");
        var cfg = new ConsumerConfig
        {
            BootstrapServers = Env("KAFKA_BOOTSTRAP_SERVERS"),
            GroupId = groupId ?? Env("KAFKA_GROUP_ID", "coreauto-step"),
            AutoOffsetReset = AutoOffsetReset.Earliest,
        };
        using var consumer = new ConsumerBuilder<string, byte[]>(cfg).Build();
        consumer.Subscribe(topic);
        var messages = new List<Dictionary<string, object?>>();
        var deadline = timeoutSec;
        while (messages.Count < maxMessages && deadline > 0)
        {
            var cr = consumer.Consume(TimeSpan.FromSeconds(Math.Min(1, deadline)));
            deadline -= 1;
            if (cr == null) continue;
            messages.Add(new()
            {
                ["topic"] = cr.Topic,
                ["partition"] = cr.Partition.Value,
                ["offset"] = cr.Offset.Value,
                ["key"] = cr.Message.Key,
                ["value"] = Decode(cr.Message.Value),
            });
        }
        return Result.Ok(new Dictionary<string, object?> { ["messages"] = messages });
    }

    private static byte[] Encode(object? value) => value switch
    {
        null => Array.Empty<byte>(),
        byte[] b => b,
        string s => System.Text.Encoding.UTF8.GetBytes(s),
        _ => JsonSerializer.SerializeToUtf8Bytes(value),
    };

    private static object? Decode(byte[] raw)
    {
        try { return JsonSerializer.Deserialize<JsonElement>(raw); }
        catch { return System.Text.Encoding.UTF8.GetString(raw); }
    }

    private static string Env(string key, string fallback = "") => Environment.GetEnvironmentVariable(key) ?? fallback;
}
