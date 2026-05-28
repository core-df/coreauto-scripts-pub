<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
require_once __DIR__ . '/../../../http/PHP/lib/result.php';
require_once __DIR__ . '/../../../http/PHP/lib/httpclient.php';

final class Notifyclient
{
    public static function Slack(string $text, ?string $webhook_url = null): array
    {
        $url = $webhook_url ?? getenv('SLACK_WEBHOOK_URL') ?: '';
        if ($url === '') {
            return CoreautoResult::missingEnv('SLACK_WEBHOOK_URL');
        }
        return Httpclient::Post($url, json_body: ['text' => $text]);
    }

    public static function Teams(string $text, ?string $webhook_url = null): array
    {
        $url = $webhook_url ?? getenv('TEAMS_WEBHOOK_URL') ?: '';
        if ($url === '') {
            return CoreautoResult::missingEnv('TEAMS_WEBHOOK_URL');
        }
        return Httpclient::Post($url, json_body: [
            '@type' => 'MessageCard',
            '@context' => 'http://schema.org/extensions',
            'text' => $text,
        ]);
    }

    public static function PagerDuty(string $summary, ?string $routing_key = null, string $severity = 'error'): array
    {
        $key = $routing_key ?? getenv('PAGERDUTY_ROUTING_KEY') ?: '';
        if ($key === '') {
            return CoreautoResult::missingEnv('PAGERDUTY_ROUTING_KEY');
        }
        return Httpclient::Post('https://events.pagerduty.com/v2/enqueue', json_body: [
            'routing_key' => $key,
            'event_action' => 'trigger',
            'payload' => [
                'summary' => $summary,
                'severity' => $severity,
                'source' => 'coreauto-step',
            ],
        ]);
    }

    public static function Email(string $subject, string $body, string $to_addrs, ?string $from_addr = null): array
    {
        $host = getenv('SMTP_HOST') ?: '';
        $port = (int)(getenv('SMTP_PORT') ?: '587');
        $user = getenv('SMTP_USER') ?: '';
        $password = getenv('SMTP_PASSWORD') ?: '';
        $sender = $from_addr ?? getenv('SMTP_FROM') ?: $user;
        if ($host === '' || $sender === '') {
            return CoreautoResult::missingEnv('SMTP_HOST and SMTP_FROM (or from_addr)');
        }
        $errno = 0;
        $errstr = '';
        $fp = @fsockopen($host, $port, $errno, $errstr, 60);
        if (!$fp) {
            return CoreautoResult::transportError($errstr ?: 'smtp connect failed');
        }
        $read = static function () use ($fp): bool {
            $line = fgets($fp, 512);
            return $line !== false && ($line[0] === '2' || $line[0] === '3');
        };
        $send = static function (string $line) use ($fp): void {
            fwrite($fp, $line . "\r\n");
        };
        fgets($fp, 512);
        $send('EHLO coreauto.local');
        if (!$read()) {
            fclose($fp);
            return CoreautoResult::transportError('smtp handshake failed');
        }
        if ($user !== '' && $password !== '') {
            $send('STARTTLS');
            $read();
        }
        $send("MAIL FROM:<{$sender}>");
        if (!$read()) {
            fclose($fp);
            return CoreautoResult::transportError('smtp mail from failed');
        }
        foreach (array_map('trim', explode(',', $to_addrs)) as $to) {
            if ($to === '') {
                continue;
            }
            $send("RCPT TO:<{$to}>");
            if (!$read()) {
                fclose($fp);
                return CoreautoResult::transportError('smtp rcpt failed');
            }
        }
        $send('DATA');
        if (!$read()) {
            fclose($fp);
            return CoreautoResult::transportError('smtp data failed');
        }
        fwrite($fp, "From: {$sender}\r\nTo: {$to_addrs}\r\nSubject: {$subject}\r\n\r\n{$body}\r\n.");
        if (!$read()) {
            fclose($fp);
            return CoreautoResult::transportError('smtp send failed');
        }
        $send('QUIT');
        fclose($fp);
        return ['status_code' => 200];
    }
}
