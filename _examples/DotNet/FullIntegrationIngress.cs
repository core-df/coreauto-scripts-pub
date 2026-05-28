// Copyright Core DF — Apache License 2.0
using CoreAuto.Ingress;
using CoreAuto.Kafka;

namespace CoreAuto.Examples;

public static class FullIntegrationIngress
{
    public static async Task Main(string[] args)
    {
        var topic = Environment.GetEnvironmentVariable("EXAMPLE_KAFKA_TOPIC") ?? "orders.inbound";
        Console.Error.WriteLine($"Bridging Kafka topic {topic}");

        while (true)
        {
            var r = await Ingress.RunBridgeAsync(() => Task.FromResult(KafkaClient.Consume(topic, 30, 10)));
            if (r.StatusCode >= 400 || r.StatusCode == 0)
            {
                Console.Error.WriteLine(r.Extra?["error"]);
                await Task.Delay(5000);
                continue;
            }
            if (r.Extra?.ContainsKey("forwarded") == true)
                Console.WriteLine(System.Text.Json.JsonSerializer.Serialize(r.Extra));
        }
    }
}
