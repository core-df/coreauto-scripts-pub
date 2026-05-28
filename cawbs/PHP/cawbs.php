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
 * Core Auto Web Services library (cawbs) — PHP client for the Core Auto Collector.
 *
 * Documentation: https://coreauto.coredf.com/resources
 */

declare(strict_types=1);

require_once __DIR__ . '/lib/wbs.php';

final class Cawbs
{
    private static function sess(): WbsSession
    {
        static $sess = null;
        $sess ??= new WbsSession();
        return $sess;
    }

    public static function Init(): WbsResult
    {
        $env = getenv('ENV') ?: '';
        $actionId = getenv('ACTIONID') ?: '';
        $accessCode = getenv('CA_ACCESS_CODE') ?: '';
        $baseUrl = getenv('CA_WBS_URL') ?: '';
        $stepName = getenv('STEPNAME') ?: '';
        if ($env === '' || $actionId === '' || $accessCode === '' || $baseUrl === '' || $stepName === '') {
            return WbsSession::missingEnv('ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME');
        }
        return self::sess()->authenticate($env, $accessCode, $baseUrl);
    }

    public static function GetEventPayload(): WbsResult
    {
        return self::sess()->getEventPayload(getenv('ACTIONID') ?: '');
    }

    public static function PutStepPayload(mixed $payload): WbsResult
    {
        return self::sess()->putStepPayload(getenv('ACTIONID') ?: '', getenv('STEPNAME') ?: '', $payload);
    }

    public static function GetStepPayload(string $stepname): WbsResult
    {
        return self::sess()->getStepPayload(getenv('ACTIONID') ?: '', $stepname);
    }

    public static function GetKeystore(string $keylist): WbsResult
    {
        return self::sess()->getKeystore($keylist);
    }
}
