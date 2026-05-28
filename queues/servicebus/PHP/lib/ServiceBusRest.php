<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 * Azure Service Bus REST (SharedAccessSignature).
 */
final class ServiceBusRest
{
    private static function parseConnString(string $conn): array
    {
        $parts = [];
        foreach (explode(';', $conn) as $piece) {
            [$k, $v] = array_pad(explode('=', $piece, 2), 2, '');
            $parts[$k] = $v;
        }
        $endpoint = str_replace('sb://', 'https://', $parts['Endpoint'] ?? '');
        return [
            'endpoint' => rtrim($endpoint, '/'),
            'key_name' => $parts['SharedAccessKeyName'] ?? '',
            'key' => $parts['SharedAccessKey'] ?? '',
        ];
    }

    private static function sasToken(string $resourceUri, string $keyName, string $key): string
    {
        $expiry = (string)(time() + 3600);
        $encoded = rawurlencode($resourceUri);
        $stringToSign = $encoded . "\n" . $expiry;
        $signature = base64_encode(hash_hmac('sha256', $stringToSign, $key, true));
        return 'SharedAccessSignature sr=' . $encoded
            . '&sig=' . rawurlencode($signature)
            . '&se=' . $expiry
            . '&skn=' . rawurlencode($keyName);
    }

    public static function sendMessage(string $conn, string $queue, mixed $body): array
    {
        $cfg = self::parseConnString($conn);
        $resource = $cfg['endpoint'] . '/' . $queue;
        $url = $resource . '/messages';
        $payload = is_string($body) ? $body : json_encode($body);
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => [
                'Authorization: ' . self::sasToken($resource, $cfg['key_name'], $cfg['key']),
                'Content-Type: application/json',
            ],
            CURLOPT_POSTFIELDS => $payload,
        ]);
        $resp = curl_exec($ch);
        $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if ($code >= 400) {
            return ['status_code' => $code, 'error' => $resp ?: 'send failed'];
        }
        return ['status_code' => 200];
    }

    public static function receiveMessages(string $conn, string $queue, float $timeoutSec, int $maxMessages, bool $complete): array
    {
        $cfg = self::parseConnString($conn);
        $resource = $cfg['endpoint'] . '/' . $queue;
        $messages = [];
        for ($i = 0; $i < max(1, $maxMessages); $i++) {
            $url = $resource . '/messages/head?timeout=' . (int)$timeoutSec;
            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_POST => true,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_HEADER => true,
                CURLOPT_HTTPHEADER => [
                    'Authorization: ' . self::sasToken($resource, $cfg['key_name'], $cfg['key']),
                ],
            ]);
            $raw = curl_exec($ch);
            $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            if ($code === 204 || $raw === false || $raw === '') {
                break;
            }
            if ($code >= 400) {
                return ['status_code' => $code, 'error' => $raw];
            }
            [$headers, $body] = explode("\r\n\r\n", $raw, 2);
            $lock = null;
            if (preg_match('/BrokerProperties:\s*(.+)/i', $headers, $m)) {
                $props = json_decode(trim($m[1]), true);
                $lock = $props['LockToken'] ?? null;
            }
            $value = json_decode($body, true);
            if ($value === null) {
                $value = $body;
            }
            $messages[] = ['queue' => $queue, 'value' => $value];
            if ($complete && $lock) {
                $delUrl = $resource . '/messages/' . $lock;
                $del = curl_init($delUrl);
                curl_setopt_array($del, [
                    CURLOPT_CUSTOMREQUEST => 'DELETE',
                    CURLOPT_RETURNTRANSFER => true,
                    CURLOPT_HTTPHEADER => [
                        'Authorization: ' . self::sasToken($resource, $cfg['key_name'], $cfg['key']),
                    ],
                ]);
                curl_exec($del);
                curl_close($del);
            }
        }
        return ['status_code' => 200, 'messages' => $messages];
    }
}
