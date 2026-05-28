<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
require_once __DIR__ . '/result.php';

final class Pubsubclient {
    public static function Init(): array {
        if (!getenv('PUBSUB_PROJECT_ID') && !getenv('GOOGLE_CLOUD_PROJECT')) return CoreautoResult::missingEnv('PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT');
        return ['status_code' => 200];
    }
    public static function Publish(mixed $value, ?string $topic = null): array {
        if (!class_exists('Google\\Cloud\\PubSub\\PubSubClient')) return ['status_code' => 500, 'error' => 'google/cloud-pubsub required'];
        try {
            $project = getenv('PUBSUB_PROJECT_ID') ?: getenv('GOOGLE_CLOUD_PROJECT');
            $topicId = $topic ?: getenv('PUBSUB_TOPIC_ID');
            if (!$topicId) return CoreautoResult::missingEnv('PUBSUB_TOPIC_ID');
            $ps = new Google\Cloud\PubSub\PubSubClient(['projectId' => $project]);
            $t = $ps->topic($topicId);
            $ids = $t->publish(['data' => is_string($value) ? $value : json_encode($value)]);
            return ['status_code' => 200, 'message_id' => $ids['messageIds'][0] ?? null];
        } catch (Throwable $e) { return CoreautoResult::transportError($e->getMessage()); }
    }
    public static function Pull(?string $subscription = null, int $max_messages = 1, float $timeout_sec = 30, bool $ack = true): array {
        if (!class_exists('Google\\Cloud\\PubSub\\PubSubClient')) {
            return ['status_code' => 500, 'error' => 'google/cloud-pubsub required'];
        }
        try {
            $project = getenv('PUBSUB_PROJECT_ID') ?: getenv('GOOGLE_CLOUD_PROJECT');
            if (!$project) return CoreautoResult::missingEnv('PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT');
            $subId = $subscription ?: getenv('PUBSUB_SUBSCRIPTION_ID');
            if (!$subId) return CoreautoResult::missingEnv('PUBSUB_SUBSCRIPTION_ID');
            $ps = new Google\Cloud\PubSub\PubSubClient(['projectId' => $project]);
            $sub = $ps->subscription($subId);
            $received = $sub->pull(['maxMessages' => max(1, min($max_messages, 1000)), 'returnImmediately' => false]);
            $messages = [];
            $ackIds = [];
            foreach ($received as $msg) {
                $body = $msg->data();
                $decoded = json_decode($body, true);
                if (json_last_error() !== JSON_ERROR_NONE) $decoded = $body;
                $messages[] = [
                    'subscription' => $subId,
                    'message_id' => $msg->id(),
                    'value' => $decoded,
                ];
                $ackIds[] = $msg->ackId();
            }
            if ($ack && $ackIds !== []) {
                $sub->acknowledgeBatch($ackIds);
            }
            return ['status_code' => 200, 'messages' => $messages];
        } catch (Throwable $e) {
            return CoreautoResult::transportError($e->getMessage());
        }
    }
}
