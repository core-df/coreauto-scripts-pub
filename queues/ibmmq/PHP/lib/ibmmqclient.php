<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
require_once __DIR__ . '/result.php';
require_once __DIR__ . '/IbmmqRest.php';

final class Ibmmqclient {
    public static function Init(): array {
        if (!getenv('MQ_HOST') || !getenv('MQ_QUEUE_MANAGER')) return CoreautoResult::missingEnv('MQ_HOST and MQ_QUEUE_MANAGER');
        if (!getenv('MQ_QUEUE')) return CoreautoResult::missingEnv('MQ_QUEUE (or pass queue per call)');
        return ['status_code' => 200];
    }
    public static function Put(mixed $value, ?string $queue = null): array {
        $q = $queue ?: getenv('MQ_QUEUE') ?: '';
        if ($q === '') return CoreautoResult::missingEnv('MQ_QUEUE');
        return IbmmqRest::putMessage($q, is_string($value) ? $value : (is_array($value) ? $value : (string)$value));
    }
    public static function Get(?string $queue = null, float $timeout_sec = 30, int $max_messages = 1): array {
        $q = $queue ?: getenv('MQ_QUEUE') ?: '';
        if ($q === '') return CoreautoResult::missingEnv('MQ_QUEUE');
        return IbmmqRest::getMessages($q, $max_messages);
    }
}
