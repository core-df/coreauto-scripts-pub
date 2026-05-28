<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
final class CoreautoResult
{
    public static function missingEnv(string $vars): array
    {
        return ['status_code' => 601, 'error' => "Environment variables {$vars} should be defined"];
    }
    public static function transportError(string $message = 'inaccessible'): array
    {
        return ['status_code' => 0, 'error' => $message];
    }
}
