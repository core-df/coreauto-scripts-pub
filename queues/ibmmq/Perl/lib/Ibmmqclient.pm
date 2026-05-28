package Ibmmqclient;
use strict;
use warnings;
use JSON qw(encode_json);
use Coreauto::Result;
use IbmmqRest;
# Copyright Core DF — Apache License 2.0

sub _queue {
    my ($explicit) = @_;
    return $explicit if defined $explicit && $explicit ne '';
    return $ENV{MQ_QUEUE} // '';
}

sub Init {
    return Coreauto::Result::missing_env('MQ_HOST and MQ_QUEUE_MANAGER') unless $ENV{MQ_HOST} && $ENV{MQ_QUEUE_MANAGER};
    return Coreauto::Result::missing_env('MQ_QUEUE (or pass queue per call)') unless $ENV{MQ_QUEUE};
    return { status_code => 200 };
}

sub Put {
    my ($value, $queue) = @_;
    return Coreauto::Result::missing_env('MQ_QUEUE') unless _queue($queue);
    my $body = ref $value ? encode_json($value) : $value;
    return IbmmqRest::put_message(_queue($queue), $body);
}

sub Get {
    my ($queue, $timeout_sec, $max_messages) = @_;
    return Coreauto::Result::missing_env('MQ_QUEUE') unless _queue($queue);
    return IbmmqRest::get_messages(_queue($queue), $max_messages // 1);
}

1;
