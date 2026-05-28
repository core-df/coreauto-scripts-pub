<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 * Generic HTTP client helpers for Core Auto step scripts.
 */
require_once __DIR__ . '/result.php';

final class Httpclient
{
    private static function parseBody(string $raw): mixed
    {
        if ($raw === '') {
            return null;
        }
        $parsed = json_decode($raw, true);
        return json_last_error() === JSON_ERROR_NONE ? $parsed : $raw;
    }

    /** @param array<string,string>|null $headers */
    private static function request(string $method, string $url, ?array $headers = null, ?string $body = null, ?array $params = null): array
    {
        if ($params) {
            $sep = str_contains($url, '?') ? '&' : '?';
            $url .= $sep . http_build_query($params);
        }
        $ch = curl_init($url);
        if ($ch === false) {
            return CoreautoResult::transportError();
        }
        $hdrs = [];
        foreach ($headers ?? [] as $k => $v) {
            $hdrs[] = "{$k}: {$v}";
        }
        curl_setopt_array($ch, [
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $hdrs,
            CURLOPT_TIMEOUT => 60,
        ]);
        if ($body !== null) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
        }
        $raw = curl_exec($ch);
        $code = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        $err = curl_error($ch);
        curl_close($ch);
        if ($raw === false) {
            return CoreautoResult::transportError($err ?: 'inaccessible');
        }
        $parsed = self::parseBody($raw);
        if ($code >= 400) {
            return ['status_code' => $code, 'error' => $parsed ?? 'inaccessible'];
        }
        return ['status_code' => $code, 'body' => $parsed];
    }

    public static function Get(string $url, ?array $headers = null, ?array $params = null): array
    {
        return self::request('GET', $url, $headers, null, $params);
    }

    public static function Post(string $url, mixed $json_body = null, ?string $data = null, ?array $headers = null): array
    {
        $hdrs = $headers ?? [];
        $body = null;
        if ($json_body !== null) {
            $hdrs['Content-Type'] ??= 'application/json';
            $body = json_encode($json_body, JSON_THROW_ON_ERROR);
        } elseif ($data !== null) {
            $body = $data;
        }
        return self::request('POST', $url, $hdrs, $body);
    }

    public static function Put(string $url, mixed $json_body = null, ?array $headers = null): array
    {
        $hdrs = $headers ?? [];
        $body = null;
        if ($json_body !== null) {
            $hdrs['Content-Type'] ??= 'application/json';
            $body = json_encode($json_body, JSON_THROW_ON_ERROR);
        }
        return self::request('PUT', $url, $hdrs, $body);
    }

    public static function Delete(string $url, ?array $headers = null): array
    {
        return self::request('DELETE', $url, $headers);
    }
}
