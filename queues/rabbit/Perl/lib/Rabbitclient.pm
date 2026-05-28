package Rabbitclient;
use strict;
use warnings;
# Copyright Core DF — Apache License 2.0
use JSON qw(encode_json decode_json);
use Coreauto::Result;

sub _url {
    return $ENV{RABBITMQ_URL} if $ENV{RABBITMQ_URL};
    return '' unless $ENV{RABBITMQ_HOST};
    my $user = $ENV{RABBITMQ_USER} // 'guest';
    my $pass = $ENV{RABBITMQ_PASSWORD} // 'guest';
    my $port = $ENV{RABBITMQ_PORT} // '5672';
    my $vhost = $ENV{RABBITMQ_VHOST} // '/';
    require URI::Escape;
    return "amqp://@{[URI::Escape::uri_escape($user)]}:@{[URI::Escape::uri_escape($pass)]}@$ENV{RABBITMQ_HOST}:$port@{[URI::Escape::uri_escape($vhost)]}";
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
    return Coreauto::Result::missing_env('RABBITMQ_URL or RABBITMQ_HOST') unless _url();
    return { status_code => 200 };
}

sub Publish {
    my ($queue, $value, $durable) = @_;
    $durable = 1 unless defined $durable;
    return Coreauto::Result::missing_env('RABBITMQ_URL or RABBITMQ_HOST') unless _url();
    eval { require Net::RabbitMQ; 1 } or return { status_code => 500, error => 'Net::RabbitMQ CPAN module required' };
    eval {
        my $host = $ENV{RABBITMQ_HOST} // do {
            my $url = _url();
            $url =~ m{//([^:/]+)/} ? $1 : '';
        };
        my $mq = Net::RabbitMQ->new();
        $mq->connect(1, $host, {
            user     => $ENV{RABBITMQ_USER} // 'guest',
            password => $ENV{RABBITMQ_PASSWORD} // 'guest',
            port     => ($ENV{RABBITMQ_PORT} // 5672) + 0,
            vhost    => $ENV{RABBITMQ_VHOST} // '/',
        });
        $mq->channel_open(1, 1);
        $mq->queue_declare(1, 1, $queue, { durable => $durable ? 1 : 0 });
        $mq->publish(1, 1, $queue, _encode($value));
        $mq->disconnect(1);
        return { status_code => 200 };
    } or return Coreauto::Result::transport_error($@);
}

sub Consume {
    my ($queue, $timeout_sec, $max_messages, $auto_ack, $durable) = @_;
    $timeout_sec = 30 unless defined $timeout_sec;
    $max_messages = 1 unless defined $max_messages;
    $auto_ack = 1 unless defined $auto_ack;
    $durable = 1 unless defined $durable;
    return Coreauto::Result::missing_env('RABBITMQ_URL or RABBITMQ_HOST') unless _url();
    eval { require Net::RabbitMQ; 1 } or return { status_code => 500, error => 'Net::RabbitMQ CPAN module required' };
    eval {
        my $host = $ENV{RABBITMQ_HOST} // do {
            my $url = _url();
            $url =~ m{//([^:/]+)/} ? $1 : '';
        };
        my $mq = Net::RabbitMQ->new();
        $mq->connect(1, $host, {
            user     => $ENV{RABBITMQ_USER} // 'guest',
            password => $ENV{RABBITMQ_PASSWORD} // 'guest',
            port     => ($ENV{RABBITMQ_PORT} // 5672) + 0,
            vhost    => $ENV{RABBITMQ_VHOST} // '/',
        });
        $mq->channel_open(1, 1);
        $mq->queue_declare(1, 1, $queue, { durable => $durable ? 1 : 0 });
        my @messages;
        my $deadline = $timeout_sec;
        while (@messages < $max_messages && $deadline > 0) {
            my $msg = $mq->get(1, 1, $queue, { no_ack => $auto_ack ? 1 : 0 });
            if (!$msg) {
                sleep 1;
                $deadline--;
                next;
            }
            push @messages, {
                queue         => $queue,
                delivery_tag  => $msg->{delivery_tag},
                value         => _decode($msg->{body}),
            };
        }
        $mq->disconnect(1);
        return { status_code => 200, messages => \@messages };
    } or return Coreauto::Result::transport_error($@);
}

1;
