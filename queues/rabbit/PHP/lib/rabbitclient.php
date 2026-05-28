<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
require_once __DIR__ . '/result.php';

final class Rabbitclient {
    private static function url(): string {
        $u = getenv('RABBITMQ_URL') ?: '';
        if ($u !== '') return $u;
        $host = getenv('RABBITMQ_HOST') ?: '';
        if ($host === '') return '';
        $user = rawurlencode(getenv('RABBITMQ_USER') ?: 'guest');
        $pass = rawurlencode(getenv('RABBITMQ_PASSWORD') ?: 'guest');
        $port = getenv('RABBITMQ_PORT') ?: '5672';
        $vhost = rawurlencode(getenv('RABBITMQ_VHOST') ?: '/');
        return "amqp://{$user}:{$pass}@{$host}:{$port}/{$vhost}";
    }
    private static function encode(mixed $v): string {
        return is_string($v) ? $v : json_encode($v, JSON_THROW_ON_ERROR);
    }
    public static function Init(): array {
        if (self::url() === '') return CoreautoResult::missingEnv('RABBITMQ_URL or RABBITMQ_HOST');
        return ['status_code' => 200];
    }
    public static function Publish(string $queue, mixed $value, bool $durable = true): array {
        if (self::url() === '') return CoreautoResult::missingEnv('RABBITMQ_URL or RABBITMQ_HOST');
        if (!class_exists('PhpAmqpLib\\Connection\\AMQPStreamConnection')) {
            return ['status_code' => 500, 'error' => 'php-amqplib required (composer require php-amqplib/php-amqplib)'];
        }
        try {
            $conn = \PhpAmqpLib\Connection\AMQPStreamConnection::create_from_url(self::url());
            $ch = $conn->channel();
            $ch->queue_declare($queue, false, $durable, false, false);
            $msg = new \PhpAmqpLib\Message\AMQPMessage(self::encode($value));
            $ch->basic_publish($msg, '', $queue);
            $ch->close(); $conn->close();
            return ['status_code' => 200];
        } catch (Throwable $e) { return CoreautoResult::transportError($e->getMessage()); }
    }
    private static function decode(string $raw): mixed {
        $decoded = json_decode($raw, true);
        return json_last_error() === JSON_ERROR_NONE ? $decoded : $raw;
    }
    public static function Consume(string $queue, float $timeout_sec = 30, int $max_messages = 1, bool $auto_ack = true, bool $durable = true): array {
        if (self::url() === '') return CoreautoResult::missingEnv('RABBITMQ_URL or RABBITMQ_HOST');
        if (!class_exists('PhpAmqpLib\\Connection\\AMQPStreamConnection')) {
            return ['status_code' => 500, 'error' => 'php-amqplib required (composer require php-amqplib/php-amqplib)'];
        }
        try {
            $conn = \PhpAmqpLib\Connection\AMQPStreamConnection::create_from_url(self::url());
            $ch = $conn->channel();
            $ch->queue_declare($queue, false, $durable, false, false);
            $messages = [];
            $deadline = (int) $timeout_sec;
            while (count($messages) < $max_messages && $deadline > 0) {
                $msg = $ch->basic_get($queue, !$auto_ack);
                if ($msg === null) {
                    sleep(1);
                    $deadline--;
                    continue;
                }
                $messages[] = [
                    'queue' => $queue,
                    'delivery_tag' => $msg->getDeliveryTag(),
                    'value' => self::decode($msg->getBody()),
                ];
                if ($auto_ack) {
                    $ch->basic_ack($msg->getDeliveryTag());
                }
            }
            $ch->close();
            $conn->close();
            return ['status_code' => 200, 'messages' => $messages];
        } catch (Throwable $e) {
            return CoreautoResult::transportError($e->getMessage());
        }
    }
}
