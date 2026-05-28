<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
final class IbmmqRest
{
    private static function baseUrl(): string
    {
        $explicit = getenv('MQ_REST_BASE_URL') ?: '';
        if ($explicit !== '') {
            return rtrim($explicit, '/');
        }
        $host = getenv('MQ_HOST') ?: '';
        $port = getenv('MQ_REST_PORT') ?: '9443';
        return "https://{$host}:{$port}/ibmmq/rest/v2";
    }

    private static function authHeader(): array
    {
        $user = getenv('MQ_USER') ?: '';
        $password = getenv('MQ_PASSWORD') ?: '';
        if ($user === '') {
            return [];
        }
        return ['Authorization: Basic ' . base64_encode("{$user}:{$password}")];
    }

    public static function putMessage(string $queue, mixed $body): array
    {
        $qmgr = getenv('MQ_QUEUE_MANAGER') ?: '';
        $payload = is_string($body) ? $body : json_encode($body);
        $url = self::baseUrl() . "/messaging/qmgr/{$qmgr}/queue/{$queue}/message";
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_HTTPHEADER => array_merge(self::authHeader(), ['Content-Type: application/json']),
            CURLOPT_POSTFIELDS => json_encode(['type' => 'string', 'content' => $payload]),
        ]);
        $resp = curl_exec($ch);
        $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if ($code >= 400) {
            return ['status_code' => $code, 'error' => $resp ?: 'put failed'];
        }
        return ['status_code' => 200];
    }

    public static function getMessages(string $queue, int $maxMessages): array
    {
        $qmgr = getenv('MQ_QUEUE_MANAGER') ?: '';
        $messages = [];
        for ($i = 0; $i < max(1, $maxMessages); $i++) {
            $url = self::baseUrl() . "/messaging/qmgr/{$qmgr}/queue/{$queue}/message";
            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_CUSTOMREQUEST => 'DELETE',
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_SSL_VERIFYPEER => false,
                CURLOPT_HTTPHEADER => self::authHeader(),
            ]);
            $resp = curl_exec($ch);
            $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            if ($code === 204 || $resp === false || $resp === '') {
                break;
            }
            if ($code >= 400) {
                return ['status_code' => $code, 'error' => $resp];
            }
            $parsed = json_decode($resp, true);
            $value = is_array($parsed) ? ($parsed['content'] ?? $parsed) : $resp;
            if (is_string($value)) {
                $decoded = json_decode($value, true);
                if ($decoded !== null) {
                    $value = $decoded;
                }
            }
            $messages[] = ['queue' => $queue, 'value' => $value];
        }
        return ['status_code' => 200, 'messages' => $messages];
    }
}
