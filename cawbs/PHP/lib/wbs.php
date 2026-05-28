<?php
/*
 * Copyright (c) Core DF. All rights reserved.
 *
 * Shared HTTP helpers for the Core Auto Collector (cawbs) PHP client.
 */

declare(strict_types=1);

final class WbsResult
{
    public function __construct(
        public int $status_code,
        public mixed $error = null,
        public mixed $payload = null,
        public ?array $answer = null,
    ) {
    }

    public function toArray(): array
    {
        $r = ['status_code' => $this->status_code];
        if ($this->error !== null) {
            $r['error'] = $this->error;
        }
        if ($this->payload !== null) {
            $r['payload'] = $this->payload;
        }
        if ($this->answer !== null) {
            $r['answer'] = $this->answer;
        }
        return $r;
    }
}

final class WbsSession
{
    private bool $initialized = false;
    private string $baseUrl = '';
    /** @var array<string, string> */
    private array $headers = [];

    public static function missingEnv(string $vars): WbsResult
    {
        return new WbsResult(601, "Environment variables {$vars} should be defined");
    }

    private static function trimUrl(string $url): string
    {
        return trim($url, "/ \t\n\r\0\x0B");
    }

    /** @return array{0: int, 1: mixed} */
    private static function doRequest(string $method, string $url, array $headers, ?string $body = null): array
    {
        $ch = curl_init($url);
        if ($ch === false) {
            return [0, null];
        }

        $hdrs = [];
        foreach ($headers as $k => $v) {
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
        curl_close($ch);

        if ($raw === false) {
            return [0, null];
        }

        $parsed = json_decode($raw, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            $parsed = null;
        }
        return [$code, $parsed];
    }

    private static function apiError(int $statusCode, mixed $body): WbsResult
    {
        if ($body === null) {
            return new WbsResult($statusCode, 'inaccessible');
        }
        return new WbsResult($statusCode, $body);
    }

    public function authenticate(string $env, string $accessCode, string $baseUrl): WbsResult
    {
        if ($this->initialized) {
            return new WbsResult(602, 'init already called');
        }

        $this->baseUrl = self::trimUrl($baseUrl);
        $headers = [
            'Content-Type' => 'application/json',
            'Environment' => $env,
        ];
        [$statusCode, $body] = self::doRequest(
            'POST',
            "{$this->baseUrl}/v1/auth/apicode",
            $headers,
            json_encode(['apiCode' => $accessCode], JSON_THROW_ON_ERROR),
        );
        if ($statusCode === 0) {
            return new WbsResult(0, 'inaccessible');
        }
        if ($statusCode >= 400) {
            return self::apiError($statusCode, $body);
        }
        if (!is_array($body) || !isset($body['token'])) {
            return new WbsResult($statusCode, 'inaccessible');
        }

        $headers['Authorization'] = 'Bearer ' . $body['token'];
        $this->headers = $headers;
        $this->initialized = true;
        return new WbsResult($statusCode);
    }

    public function getEventPayload(string $actionId): WbsResult
    {
        if (!$this->initialized) {
            return new WbsResult(603, 'Init required');
        }
        [$statusCode, $body] = self::doRequest('GET', "{$this->baseUrl}/v1/rtevent/{$actionId}", $this->headers);
        if ($statusCode === 0) {
            return new WbsResult(0, 'inaccessible');
        }
        if ($statusCode >= 400) {
            return self::apiError($statusCode, $body);
        }
        if (!is_array($body)) {
            return new WbsResult($statusCode, 'inaccessible');
        }
        return new WbsResult($statusCode, null, $body['payload'] ?? null);
    }

    public function putStepPayload(string $actionId, string $stepName, mixed $payload): WbsResult
    {
        if (!$this->initialized) {
            return new WbsResult(603, 'Init required');
        }
        $json = json_encode([
            'actionId' => $actionId,
            'stepname' => $stepName,
            'payload' => $payload,
        ], JSON_THROW_ON_ERROR);
        [$statusCode, $body] = self::doRequest('POST', "{$this->baseUrl}/v1/rtstep/payload", $this->headers, $json);
        if ($statusCode === 0) {
            return new WbsResult(0, 'inaccessible');
        }
        if ($statusCode >= 400) {
            return self::apiError($statusCode, $body);
        }
        return new WbsResult($statusCode);
    }

    public function getStepPayload(string $actionId, string $stepName): WbsResult
    {
        if (!$this->initialized) {
            return new WbsResult(603, 'Init required');
        }
        [$statusCode, $body] = self::doRequest(
            'GET',
            "{$this->baseUrl}/v1/rtstep/payload/{$actionId}/{$stepName}",
            $this->headers,
        );
        if ($statusCode === 0) {
            return new WbsResult(0, 'inaccessible');
        }
        if ($statusCode >= 400) {
            return self::apiError($statusCode, $body);
        }
        if (!is_array($body)) {
            return new WbsResult($statusCode, 'inaccessible');
        }
        return new WbsResult($statusCode, null, $body['payload'] ?? null);
    }

    public function getKeystore(string $keylist): WbsResult
    {
        if (!$this->initialized) {
            return new WbsResult(603, 'Init required');
        }
        $keys = str_replace(' ', '', $keylist);
        [$statusCode, $body] = self::doRequest('GET', "{$this->baseUrl}/v1/keystore/{$keys}", $this->headers);
        if ($statusCode === 0) {
            return new WbsResult(0, 'inaccessible');
        }
        if ($statusCode >= 400) {
            return self::apiError($statusCode, $body);
        }
        if (!is_array($body)) {
            return new WbsResult($statusCode, 'inaccessible');
        }
        foreach (explode(',', $keys) as $key) {
            if ($key === '') {
                continue;
            }
            if (!array_key_exists($key, $body)) {
                return new WbsResult(605, "{$key} not found");
            }
        }
        return new WbsResult($statusCode, null, null, $body);
    }
}
