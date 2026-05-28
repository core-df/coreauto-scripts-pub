<?php
/*
 * Copyright (c) Core DF. All rights reserved.
 *
 * Batch-oriented cawbs client for the Core Auto Collector.
 *
 * Documentation: https://coreauto.coredf.com/resources
 */

declare(strict_types=1);

require_once __DIR__ . '/lib/wbs.php';

final class Cawbsbatch
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
        $accessCode = getenv('CA_ACCESS_CODE') ?: '';
        $baseUrl = getenv('CA_WBS_URL') ?: '';
        if ($env === '' || $accessCode === '' || $baseUrl === '') {
            return WbsSession::missingEnv('ENV, CA_ACCESS_CODE, CA_WBS_URL');
        }
        return self::sess()->authenticate($env, $accessCode, $baseUrl);
    }

    public static function GetKeystore(string $keylist): WbsResult
    {
        return self::sess()->getKeystore($keylist);
    }
}
