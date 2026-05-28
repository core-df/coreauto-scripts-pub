<?php
declare(strict_types=1);
/*
 * Copyright Core DF
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Core Auto real-time step — full integration example (PHP port).
 */
require_once __DIR__ . '/lib.php';

function ok(array|WbsResult $r, string $label): array
{
    if ($r instanceof WbsResult) {
        $r = $r->toArray();
    }
    $code = $r['status_code'] ?? 0;
    if ($code >= 400 || $code === 0) {
        fwrite(STDERR, json_encode(['step' => $label, 'error' => $r], JSON_PRETTY_PRINT) . "\n");
        exit(1);
    }
    return $r;
}

function optional(string $label, callable $fn): ?array
{
    $r = $fn();
    if ($r instanceof WbsResult) {
        $r = $r->toArray();
    }
    $code = $r['status_code'] ?? 0;
    $err = strtolower((string)($r['error'] ?? ''));
    if (in_array($code, [601, 500], true) && str_contains($err, 'missing')) {
        echo "[skip] $label: not configured\n";
        return null;
    }
    if ($code >= 400 || $code === 0) {
        echo "[warn] $label\n";
        return null;
    }
    echo "[ok] $label\n";
    return $r;
}

ok(Cawbs::Init(), 'cawbs.Init');
$event = ok(Cawbs::GetEventPayload(), 'cawbs.GetEventPayload');
$payload = $event['payload'] ?? $event;
$orderId = $payload['orderId'] ?? $payload['id'] ?? 'unknown';
$ackDir = getenv('EXAMPLE_ACK_DIR') ?: '/tmp/coreauto-example';
if (!is_dir($ackDir)) {
    mkdir($ackDir, 0775, true);
}
$ackPath = "$ackDir/$orderId.json";
$order = ['orderId' => $orderId, 'details' => $payload];
$text = ok(Transformclient::JsonStringify($order), 'transform.JsonStringify');
ok(Fileclient::LocalWrite($ackPath, $text['text']), 'files.LocalWrite');

$published = [];
$topic = getenv('EXAMPLE_KAFKA_TOPIC') ?: 'orders.enriched';
$queue = getenv('EXAMPLE_QUEUE_NAME') ?: 'orders';
foreach ([
    ['kafka', fn() => Kafkaclient::Produce($topic, $order)],
    ['rabbit', fn() => Rabbitclient::Publish($queue, $order)],
    ['sqs', fn() => Sqsclient::Send($order)],
] as [$name, $fn]) {
    if (optional("queues.$name", $fn)) {
        $published[] = $name;
    }
}

$output = ['orderId' => $orderId, 'queuesPublished' => $published, 'ackPath' => $ackPath];
ok(Cawbs::PutStepPayload($output), 'cawbs.PutStepPayload');
echo json_encode(['status_code' => 200, 'result' => $output], JSON_PRETTY_PRINT) . "\n";
