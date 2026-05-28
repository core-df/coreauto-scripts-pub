// Copyright Core DF — Apache License 2.0
using System.Text.Json;
using CoreAuto.Cawbs;
using CoreAuto.Files;
using CoreAuto.Kafka;
using CoreAuto.Transform;

var init = await Cawbs.InitAsync();
if (init.StatusCode != 200) Environment.Exit(1);

var ev = await Cawbs.GetEventPayloadAsync();
if (ev.StatusCode != 200) Environment.Exit(1);

var orderId = "unknown";
if (ev.Payload is Dictionary<string, object?> payload)
{
    if (payload.TryGetValue("orderId", out var id) && id != null) orderId = id.ToString()!;
    else if (payload.TryGetValue("id", out id) && id != null) orderId = id.ToString()!;
}

var ackDir = Environment.GetEnvironmentVariable("EXAMPLE_ACK_DIR") ?? "/tmp/coreauto-example";
var ackPath = $"{ackDir}/{orderId}.json";
var order = new Dictionary<string, object?> { ["orderId"] = orderId, ["details"] = ev.Payload };

var text = TransformClient.JsonStringify(order);
if (text.StatusCode != 200) Environment.Exit(1);
var ackText = text.Extra?["text"]?.ToString() ?? "";
if ((await FileClient.LocalWrite(ackPath, ackText)).StatusCode != 200) Environment.Exit(1);

var topic = Environment.GetEnvironmentVariable("EXAMPLE_KAFKA_TOPIC") ?? "orders.enriched";
var published = new List<string>();
if (KafkaClient.Produce(topic, order).StatusCode == 200) published.Add("kafka");

var output = new Dictionary<string, object?>
{
    ["orderId"] = orderId,
    ["queuesPublished"] = published,
    ["ackPath"] = ackPath,
};
if ((await Cawbs.PutStepPayloadAsync(output)).StatusCode != 200) Environment.Exit(1);

Console.WriteLine(JsonSerializer.Serialize(new { status_code = 200, result = output }));
