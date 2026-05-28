<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 * Kafka ingress bridge — PHP port.
 */
require_once __DIR__ . '/../../queues/ingress/PHP/ingress.php';
require_once __DIR__ . '/../../queues/kafka/PHP/lib/Kafkaclient.php';

$topic = $argv[1] ?? getenv('EXAMPLE_KAFKA_TOPIC') ?: 'orders.inbound';
fwrite(STDERR, "Bridging Kafka topic $topic\n");
while (true) {
    $result = Ingress::RunBridge(fn() => Kafkaclient::Consume($topic, max_messages: 10));
    $code = $result['status_code'] ?? 0;
    if ($code >= 400 || $code === 0) {
        fwrite(STDERR, json_encode($result) . "\n");
        sleep(5);
        continue;
    }
    if (!empty($result['forwarded'])) {
        echo json_encode(['forwarded' => $result['forwarded']]) . "\n";
    }
}
