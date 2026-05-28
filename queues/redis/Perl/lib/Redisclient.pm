package Redisclient;
use strict;
use warnings;
# Copyright Core DF — Apache License 2.0
use JSON qw(encode_json decode_json);
use Coreauto::Result;

sub _url {
    return $ENV{REDIS_URL} if $ENV{REDIS_URL};
    return '' unless $ENV{REDIS_HOST};
    my $port = $ENV{REDIS_PORT} // '6379';
    my $db = $ENV{REDIS_DB} // '0';
    my $pass = $ENV{REDIS_PASSWORD} // '';
    return $pass ne '' ? "redis://:$pass\@$ENV{REDIS_HOST}:$port/$db" : "redis://$ENV{REDIS_HOST}:$port/$db";
}

sub _encode {
    my ($value) = @_;
    return $value unless ref $value;
    return encode_json($value);
}

sub _decode {
    my ($raw) = @_;
    eval { return decode_json($raw) };
    return $raw;
}

sub Init {
    return Coreauto::Result::missing_env('REDIS_URL or REDIS_HOST') unless _url();
    return { status_code => 200 };
}

sub Push {
    my ($queue, $value) = @_;
    return Coreauto::Result::missing_env('REDIS_URL or REDIS_HOST') unless _url();
    eval { require Redis; 1 } or return { status_code => 500, error => 'Redis CPAN module required' };
    eval {
        my $host = $ENV{REDIS_HOST} // do {
            my $url = _url();
            $url =~ m{//([^:/]+)/} ? $1 : '127.0.0.1';
        };
        my $port = ($ENV{REDIS_PORT} // 6379) + 0;
        my $r = Redis->new(server => "$host:$port");
        $r->auth($ENV{REDIS_PASSWORD}) if $ENV{REDIS_PASSWORD};
        $r->select($ENV{REDIS_DB}) if defined $ENV{REDIS_DB};
        $r->lpush($queue, _encode($value));
        return { status_code => 200 };
    } or return Coreauto::Result::transport_error($@);
}

sub Pop {
    my ($queue, $timeout_sec, $max_messages) = @_;
    $timeout_sec = 30 unless defined $timeout_sec;
    $max_messages = 1 unless defined $max_messages;
    return Coreauto::Result::missing_env('REDIS_URL or REDIS_HOST') unless _url();
    eval { require Redis; 1 } or return { status_code => 500, error => 'Redis CPAN module required' };
    eval {
        my $host = $ENV{REDIS_HOST} // do {
            my $url = _url();
            $url =~ m{//([^:/]+)/} ? $1 : '127.0.0.1';
        };
        my $port = ($ENV{REDIS_PORT} // 6379) + 0;
        my $r = Redis->new(server => "$host:$port");
        $r->auth($ENV{REDIS_PASSWORD}) if $ENV{REDIS_PASSWORD};
        $r->select($ENV{REDIS_DB}) if defined $ENV{REDIS_DB};
        my @messages;
        my $remaining = $max_messages < 1 ? 1 : $max_messages;
        my $deadline = $timeout_sec;
        while ($remaining > 0) {
            my $wait = ($remaining == $max_messages) ? ($deadline < 1 ? 1 : int($deadline)) : 1;
            my $item = $r->brpop($queue, $wait);
            last unless $item;
            my ($key, $body) = @$item;
            push @messages, { queue => $queue, value => _decode($body) };
            $remaining--;
            $deadline -= $wait;
            last if $deadline <= 0;
        }
        return { status_code => 200, messages => \@messages };
    } or return Coreauto::Result::transport_error($@);
}

1;
