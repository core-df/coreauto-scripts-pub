package IbmmqRest;
use strict;
use warnings;
use JSON qw(encode_json decode_json);
use LWP::UserAgent;
use MIME::Base64 qw(encode_base64);
# Copyright Core DF — Apache License 2.0

sub _base_url {
    return $ENV{MQ_REST_BASE_URL} if $ENV{MQ_REST_BASE_URL};
    my $host = $ENV{MQ_HOST} // '';
    my $port = $ENV{MQ_REST_PORT} // 9443;
    return "https://$host:$port/ibmmq/rest/v2";
}

sub _auth {
    my $user = $ENV{MQ_USER} // '';
    my $pass = $ENV{MQ_PASSWORD} // '';
    return {} unless $user;
    return Authorization => 'Basic ' . encode_base64("$user:$pass", '');
}

sub put_message {
    my ($queue, $body) = @_;
    my $qmgr = $ENV{MQ_QUEUE_MANAGER};
    my $ua = LWP::UserAgent->new(timeout => 60, ssl_opts => { verify_hostname => 0, SSL_verify_mode => 0 });
    my $payload = ref $body ? encode_json($body) : $body;
    my $resp = $ua->post(
        _base_url() . "/messaging/qmgr/$qmgr/queue/$queue/message",
        _auth(),
        'Content-Type' => 'application/json',
        Content => encode_json({ type => 'string', content => $payload }),
    );
    return { status_code => $resp->code, error => $resp->content } if $resp->code >= 400;
    return { status_code => 200 };
}

sub get_messages {
    my ($queue, $max_messages) = @_;
    my $qmgr = $ENV{MQ_QUEUE_MANAGER};
    my $ua = LWP::UserAgent->new(timeout => 60, ssl_opts => { verify_hostname => 0, SSL_verify_mode => 0 });
    my @messages;
    for (1 .. ($max_messages // 1)) {
        my $resp = $ua->delete(_base_url() . "/messaging/qmgr/$qmgr/queue/$queue/message", _auth());
        last if $resp->code == 204 || !$resp->content;
        return { status_code => $resp->code, error => $resp->content } if $resp->code >= 400;
        my $parsed = eval { decode_json($resp->content) }; $parsed = $resp->content unless ref $parsed;
        my $value = ref $parsed eq 'HASH' ? ($parsed->{content} // $parsed) : $parsed;
        $value = eval { decode_json($value) } if !ref $value;
        push @messages, { queue => $queue, value => $value };
    }
    return { status_code => 200, messages => \@messages };
}

1;
