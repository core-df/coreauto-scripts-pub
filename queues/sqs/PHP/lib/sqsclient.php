<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
require_once __DIR__ . '/result.php';

final class Sqsclient {
    private static function queueUrl(?string $explicit): string {
        return ($explicit && $explicit !== '') ? $explicit : (getenv('SQS_QUEUE_URL') ?: '');
    }
    public static function Init(): array {
        if (!getenv('AWS_ACCESS_KEY_ID') && !getenv('AWS_PROFILE')) return CoreautoResult::missingEnv('AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE');
        if (!getenv('SQS_QUEUE_URL')) return CoreautoResult::missingEnv('SQS_QUEUE_URL (or pass queue_url per call)');
        return ['status_code' => 200];
    }
    public static function Send(mixed $value, ?string $queue_url = null): array {
        $url = self::queueUrl($queue_url);
        if ($url === '') return CoreautoResult::missingEnv('SQS_QUEUE_URL');
        if (!class_exists('Aws\\Sqs\\SqsClient')) return ['status_code' => 500, 'error' => 'aws/aws-sdk-php required'];
        try {
            $region = getenv('AWS_REGION') ?: getenv('AWS_DEFAULT_REGION') ?: 'us-east-1';
            $cfg = ['version' => 'latest', 'region' => $region];
            if ($ep = getenv('SQS_ENDPOINT_URL')) $cfg['endpoint'] = $ep;
            $c = new Aws\Sqs\SqsClient($cfg);
            $body = is_string($value) ? $value : json_encode($value);
            $r = $c->sendMessage(['QueueUrl' => $url, 'MessageBody' => $body]);
            return ['status_code' => 200, 'message_id' => $r['MessageId'] ?? null];
        } catch (Throwable $e) { return CoreautoResult::transportError($e->getMessage()); }
    }
    public static function Receive(?string $queue_url = null, int $max_messages = 1, int $wait_time_sec = 10, bool $delete = true): array {
        $url = self::queueUrl($queue_url);
        if ($url === '') return CoreautoResult::missingEnv('SQS_QUEUE_URL');
        if (!class_exists('Aws\\Sqs\\SqsClient')) return ['status_code' => 500, 'error' => 'aws/aws-sdk-php required'];
        try {
            $max_messages = max(1, min($max_messages, 10));
            $region = getenv('AWS_REGION') ?: getenv('AWS_DEFAULT_REGION') ?: 'us-east-1';
            $cfg = ['version' => 'latest', 'region' => $region];
            if ($ep = getenv('SQS_ENDPOINT_URL')) $cfg['endpoint'] = $ep;
            $c = new Aws\Sqs\SqsClient($cfg);
            $r = $c->receiveMessage([
                'QueueUrl' => $url,
                'MaxNumberOfMessages' => $max_messages,
                'WaitTimeSeconds' => $wait_time_sec,
            ]);
            $messages = [];
            foreach ($r['Messages'] ?? [] as $item) {
                $body = $item['Body'] ?? '';
                $decoded = json_decode($body, true);
                if (json_last_error() !== JSON_ERROR_NONE) $decoded = $body;
                $messages[] = [
                    'message_id' => $item['MessageId'] ?? null,
                    'receipt_handle' => $item['ReceiptHandle'] ?? null,
                    'value' => $decoded,
                ];
                if ($delete && !empty($item['ReceiptHandle'])) {
                    $c->deleteMessage(['QueueUrl' => $url, 'ReceiptHandle' => $item['ReceiptHandle']]);
                }
            }
            return ['status_code' => 200, 'messages' => $messages];
        } catch (Throwable $e) {
            return CoreautoResult::transportError($e->getMessage());
        }
    }
}
