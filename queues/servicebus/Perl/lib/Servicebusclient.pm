package Servicebusclient;
use strict;
use warnings;
use JSON qw(encode_json);
use Coreauto::Result;
use ServiceBusRest;
# Copyright Core DF — Apache License 2.0

sub _queue {
    my ($explicit) = @_;
    return $explicit if defined $explicit && $explicit ne '';
    return $ENV{SERVICE_BUS_QUEUE_NAME} // '';
}

sub Init {
    return Coreauto::Result::missing_env('SERVICE_BUS_CONNECTION_STRING') unless $ENV{SERVICE_BUS_CONNECTION_STRING};
    return Coreauto::Result::missing_env('SERVICE_BUS_QUEUE_NAME (or pass queue per call)') unless $ENV{SERVICE_BUS_QUEUE_NAME};
    return { status_code => 200 };
}

sub Send {
    my ($value, $queue) = @_;
    return Coreauto::Result::missing_env('SERVICE_BUS_CONNECTION_STRING') unless $ENV{SERVICE_BUS_CONNECTION_STRING};
    return Coreauto::Result::missing_env('SERVICE_BUS_QUEUE_NAME') unless _queue($queue);
    my $body = ref $value ? encode_json($value) : $value;
    return ServiceBusRest::send_message($ENV{SERVICE_BUS_CONNECTION_STRING}, _queue($queue), $body);
}

sub Receive {
    my ($queue, $timeout_sec, $max_messages, $complete) = @_;
    return Coreauto::Result::missing_env('SERVICE_BUS_CONNECTION_STRING') unless $ENV{SERVICE_BUS_CONNECTION_STRING};
    return Coreauto::Result::missing_env('SERVICE_BUS_QUEUE_NAME') unless _queue($queue);
    return ServiceBusRest::receive_messages($ENV{SERVICE_BUS_CONNECTION_STRING}, _queue($queue), $timeout_sec // 30, $max_messages // 1, defined $complete ? $complete : 1);
}

1;
