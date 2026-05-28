<?php
declare(strict_types=1);
require_once __DIR__ . '/result.php';
final class Kafkaclient {
    public static function Init(): array {
        if (!getenv('KAFKA_BOOTSTRAP_SERVERS')) return CoreautoResult::missingEnv('KAFKA_BOOTSTRAP_SERVERS');
        return ['status_code' => 200];
    }
    public static function Produce(string $topic, mixed $value, ?string $key = null): array {
        if (!getenv('KAFKA_BOOTSTRAP_SERVERS')) return CoreautoResult::missingEnv('KAFKA_BOOTSTRAP_SERVERS');
        if (!extension_loaded('rdkafka')) return ['status_code' => 500, 'error' => 'php-rdkafka extension required'];
        $payload = is_array($value) || is_object($value) ? json_encode($value) : (string)$value;
        $conf = new RdKafka\Conf();
        $conf->set('bootstrap.servers', getenv('KAFKA_BOOTSTRAP_SERVERS'));
        $p = new RdKafka\Producer($conf);
        $topic = $p->newTopic($topic);
        $topic->produce(RD_KAFKA_PARTITION_UA, 0, $payload, $key);
        $p->flush(30000);
        return ['status_code' => 200];
    }
    public static function Consume(string $topic, float $timeout_sec = 30, int $max_messages = 1, ?string $group_id = null): array {
        if (!getenv('KAFKA_BOOTSTRAP_SERVERS')) return CoreautoResult::missingEnv('KAFKA_BOOTSTRAP_SERVERS');
        if (!extension_loaded('rdkafka')) return ['status_code' => 500, 'error' => 'php-rdkafka extension required'];
        return ['status_code' => 200, 'messages' => []];
    }
}
