<?php
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
 * Ingress-oriented cawbs client for the Core Auto Collector.
 *
 * Documentation: https://coreauto.coredf.com/resources
 */

declare(strict_types=1);

require_once __DIR__ . '/lib/wbs.php';

final class Cawbsingress
{
    private static function sess(): WbsSession
    {
        static $sess = null;
        $sess ??= new WbsSession();
        return $sess;
    }

    /** @return array<string, mixed> */
    public static function Init(): array
    {
        $env = getenv('ENV') ?: '';
        $accessCode = getenv('CA_ACCESS_CODE') ?: '';
        $baseUrl = getenv('CA_WBS_URL') ?: '';
        if ($env === '' || $accessCode === '' || $baseUrl === '') {
            return WbsSession::missingEnv('ENV, CA_ACCESS_CODE, CA_WBS_URL')->toArray();
        }
        return self::sess()->authenticate($env, $accessCode, $baseUrl)->toArray();
    }

    /** @return array<string, mixed> */
    public static function PostEvent(
        string $eventName,
        mixed $payload,
        ?string $eventSource = null,
    ): array {
        $r = self::sess()->postEvent($eventName, $payload, $eventSource);
        if ($r->error !== null) {
            return $r->toArray();
        }
        $js = $r->payload;
        if (!is_array($js)) {
            return $r->toArray();
        }
        return [
            'status_code' => $r->status_code,
            'eventId' => $js['eventId'] ?? null,
            'actionId' => $js['actionId'] ?? null,
            'createdAt' => $js['createdAt'] ?? null,
        ];
    }

    /** @return array<string, mixed> */
    public static function GetEventStatus(int|string $actionId): array
    {
        $r = self::sess()->getEventStatus((string) $actionId);
        if ($r->error !== null) {
            return $r->toArray();
        }
        return ['status_code' => $r->status_code, 'status' => $r->payload];
    }

    /** @return array<string, mixed> */
    public static function GetEventList(): array
    {
        $r = self::sess()->getEventList();
        if ($r->error !== null) {
            return $r->toArray();
        }
        return ['status_code' => $r->status_code, 'events' => $r->payload];
    }

    /** @return array<string, mixed> */
    public static function SubmitFlag(
        string $name,
        string $systemName,
        string $sourceSystemName,
        string $date,
    ): array {
        $r = self::sess()->submitFlag($name, $systemName, $sourceSystemName, $date);
        if ($r->error !== null) {
            return $r->toArray();
        }
        $js = $r->payload;
        if (!is_array($js)) {
            return $r->toArray();
        }
        return ['status_code' => $r->status_code, 'flagStatus' => $js['status'] ?? null];
    }

    /** @return array<string, mixed> */
    public static function GetKeystore(string $keylist): array
    {
        return self::sess()->getKeystore($keylist)->toArray();
    }
}
