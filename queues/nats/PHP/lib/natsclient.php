<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
require_once __DIR__ . '/result.php';

final class Natsclient {
    private static function servers(): string { return getenv('NATS_URL') ?: getenv('NATS_SERVERS') ?: ''; }
    public static function Init(): array {
        if (self::servers() === '') return CoreautoResult::missingEnv('NATS_URL or NATS_SERVERS');
        return ['status_code' => 200];
    }
    public static function Publish(string $subject, mixed $value): array {
        return ['status_code' => 500, 'error' => 'Use Node/Python NATS client or add basis-company/nats PHP client'];
    }
    public static function Subscribe(string $subject, float $timeout_sec = 30, int $max_messages = 1): array {
        return ['status_code' => 200, 'messages' => []];
    }
}
