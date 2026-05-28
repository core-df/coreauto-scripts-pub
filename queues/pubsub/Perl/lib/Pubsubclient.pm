package Pubsubclient;
use strict;
use warnings;
use JSON qw(encode_json decode_json);
use Coreauto::Result;
use PubsubRest;
# Copyright Core DF — Apache License 2.0

sub _project {
    return $ENV{PUBSUB_PROJECT_ID} // $ENV{GOOGLE_CLOUD_PROJECT} // '';
}

sub _topic {
    my ($explicit) = @_;
    return $explicit if defined $explicit && $explicit ne '';
    return $ENV{PUBSUB_TOPIC_ID} // '';
}

sub _subscription {
    my ($explicit) = @_;
    return $explicit if defined $explicit && $explicit ne '';
    return $ENV{PUBSUB_SUBSCRIPTION_ID} // '';
}

sub Init {
    return Coreauto::Result::missing_env('PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT') unless _project();
    return { status_code => 200 };
}

sub Publish {
    my ($value, $topic) = @_;
    return Coreauto::Result::missing_env('PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT') unless _project();
    return Coreauto::Result::missing_env('PUBSUB_TOPIC_ID') unless _topic($topic);
    return PubsubRest::publish(_project(), _topic($topic), $value);
}

sub Pull {
    my ($subscription, $max_messages, $timeout_sec, $ack) = @_;
    return Coreauto::Result::missing_env('PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT') unless _project();
    return Coreauto::Result::missing_env('PUBSUB_SUBSCRIPTION_ID') unless _subscription($subscription);
    return PubsubRest::pull(_project(), _subscription($subscription), $max_messages // 1, defined $ack ? $ack : 1);
}

1;
