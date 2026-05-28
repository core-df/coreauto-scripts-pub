<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
require_once __DIR__ . '/result.php';
require_once __DIR__ . '/ServiceBusRest.php';

final class Servicebusclient {
    public static function Init(): array {
        if (!getenv('SERVICE_BUS_CONNECTION_STRING')) return CoreautoResult::missingEnv('SERVICE_BUS_CONNECTION_STRING');
        if (!getenv('SERVICE_BUS_QUEUE_NAME')) return CoreautoResult::missingEnv('SERVICE_BUS_QUEUE_NAME (or pass queue per call)');
        return ['status_code' => 200];
    }
    public static function Send(mixed $value, ?string $queue = null): array {
        $conn = getenv('SERVICE_BUS_CONNECTION_STRING') ?: '';
        $q = $queue ?: getenv('SERVICE_BUS_QUEUE_NAME') ?: '';
        if ($conn === '') return CoreautoResult::missingEnv('SERVICE_BUS_CONNECTION_STRING');
        if ($q === '') return CoreautoResult::missingEnv('SERVICE_BUS_QUEUE_NAME');
        return ServiceBusRest::sendMessage($conn, $q, is_string($value) ? $value : (is_array($value) ? $value : (string)$value));
    }
    public static function Receive(?string $queue = null, float $timeout_sec = 30, int $max_messages = 1, bool $complete = true): array {
        $conn = getenv('SERVICE_BUS_CONNECTION_STRING') ?: '';
        $q = $queue ?: getenv('SERVICE_BUS_QUEUE_NAME') ?: '';
        if ($conn === '') return CoreautoResult::missingEnv('SERVICE_BUS_CONNECTION_STRING');
        if ($q === '') return CoreautoResult::missingEnv('SERVICE_BUS_QUEUE_NAME');
        return ServiceBusRest::receiveMessages($conn, $q, $timeout_sec, $max_messages, $complete);
    }
}
