<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
require_once __DIR__ . '/lib/result.php';
require_once __DIR__ . '/../../../cawbs/PHP/cawbsingress.php';

final class Ingress
{
    public static function TriggerEvent(mixed $payload, ?string $eventName = null, ?string $eventSource = null): array
    {
        $name = $eventName ?? getenv('CA_EVENT_NAME') ?: '';
        if ($name === '') {
            return CoreautoResult::missingEnv('CA_EVENT_NAME (or pass event_name)');
        }
        $source = $eventSource ?? getenv('CA_EVENT_SOURCE') ?: '';
        $init = CawbsIngress::Init();
        if (($init['status_code'] ?? 0) >= 400) {
            return $init;
        }
        return $source !== ''
            ? CawbsIngress::PostEvent($name, $payload, $source)
            : CawbsIngress::PostEvent($name, $payload);
    }

    public static function ForwardMessages(array $consumeResult): array
    {
        if (($consumeResult['status_code'] ?? 0) !== 200) {
            return $consumeResult;
        }
        $forwarded = [];
        foreach ($consumeResult['messages'] ?? [] as $msg) {
            $value = array_key_exists('value', $msg) ? $msg['value'] : $msg;
            $result = self::TriggerEvent($value);
            if (($result['status_code'] ?? 0) >= 400) {
                return $result;
            }
            $forwarded[] = ['actionId' => $result['actionId'] ?? null, 'eventId' => $result['eventId'] ?? null];
        }
        return ['status_code' => 200, 'forwarded' => $forwarded];
    }

    public static function RunBridge(callable $consumeFn, mixed ...$args): array
    {
        return self::ForwardMessages($consumeFn(...$args));
    }
}
