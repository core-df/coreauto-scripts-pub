package Natsclient;
use strict;
use warnings;
# Copyright Core DF — Apache License 2.0
use JSON qw(encode_json decode_json);
use Coreauto::Result;

sub _servers {
    return $ENV{NATS_URL} // $ENV{NATS_SERVERS} // '';
}

sub Init {
    return Coreauto::Result::missing_env('NATS_URL or NATS_SERVERS') unless _servers();
    return { status_code => 200 };
}

sub Publish {
    my ($subject, $value) = @_;
    return Coreauto::Result::missing_env('NATS_URL or NATS_SERVERS') unless _servers();
    return { status_code => 500, error => 'Use Node/Python NATS client or add Net::NATS::Client bindings' };
}

sub Subscribe {
    my ($subject, $timeout_sec, $max_messages) = @_;
    return Coreauto::Result::missing_env('NATS_URL or NATS_SERVERS') unless _servers();
    return { status_code => 500, error => 'Use Node/Python NATS client or add Net::NATS::Client bindings' };
}

1;
