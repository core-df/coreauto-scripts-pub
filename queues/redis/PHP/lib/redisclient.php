<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
require_once __DIR__ . '/result.php';

final class Redisclient {
    private static function url(): string {
        $u = getenv('REDIS_URL') ?: '';
        if ($u !== '') return $u;
        $host = getenv('REDIS_HOST') ?: '';
        if ($host === '') return '';
        $port = getenv('REDIS_PORT') ?: '6379';
        $db = getenv('REDIS_DB') ?: '0';
        $pass = getenv('REDIS_PASSWORD') ?: '';
        return $pass !== '' ? "redis://:{$pass}@{$host}:{$port}/{$db}" : "redis://{$host}:{$port}/{$db}";
    }
    public static function Init(): array {
        if (self::url() === '') return CoreautoResult::missingEnv('REDIS_URL or REDIS_HOST');
        return ['status_code' => 200];
    }
    public static function Push(string $queue, mixed $value): array {
        if (self::url() === '') return CoreautoResult::missingEnv('REDIS_URL or REDIS_HOST');
        if (!extension_loaded('redis')) return ['status_code' => 500, 'error' => 'phpredis extension required'];
        try {
            $r = new Redis(); $r->connect(parse_url(self::url(), PHP_URL_HOST), (int)(parse_url(self::url(), PHP_URL_PORT) ?: 6379));
            $payload = is_string($value) ? $value : json_encode($value);
            $r->lPush($queue, $payload);
            return ['status_code' => 200];
        } catch (Throwable $e) { return CoreautoResult::transportError($e->getMessage()); }
    }
    private static function decode(string $raw): mixed {
        $decoded = json_decode($raw, true);
        return json_last_error() === JSON_ERROR_NONE ? $decoded : $raw;
    }
    private static function client(): Redis {
        $url = self::url();
        $r = new Redis();
        $host = parse_url($url, PHP_URL_HOST) ?: '127.0.0.1';
        $port = (int) (parse_url($url, PHP_URL_PORT) ?: 6379);
        $r->connect($host, $port);
        $pass = parse_url($url, PHP_URL_PASS);
        if ($pass !== null && $pass !== '') {
            $r->auth($pass);
        }
        $path = parse_url($url, PHP_URL_PATH);
        if ($path !== null && $path !== '' && $path !== '/') {
            $r->select((int) ltrim($path, '/'));
        }
        return $r;
    }
    public static function Pop(string $queue, float $timeout_sec = 30, int $max_messages = 1): array {
        if (self::url() === '') return CoreautoResult::missingEnv('REDIS_URL or REDIS_HOST');
        if (!extension_loaded('redis')) return ['status_code' => 500, 'error' => 'phpredis extension required'];
        try {
            $r = self::client();
            $messages = [];
            $remaining = max(1, $max_messages);
            $deadline = (int) $timeout_sec;
            while ($remaining > 0) {
                $wait = $remaining === $max_messages ? max(1, $deadline) : 1;
                $item = $r->brPop([$queue], $wait);
                if ($item === false || $item === null) {
                    break;
                }
                $body = is_array($item) ? end($item) : $item;
                $messages[] = ['queue' => $queue, 'value' => self::decode((string) $body)];
                $remaining--;
                $deadline -= $wait;
                if ($deadline <= 0) {
                    break;
                }
            }
            return ['status_code' => 200, 'messages' => $messages];
        } catch (Throwable $e) {
            return CoreautoResult::transportError($e->getMessage());
        }
    }
}
