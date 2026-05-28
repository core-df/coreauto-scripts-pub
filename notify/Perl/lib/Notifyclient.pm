package Notifyclient;
use strict;
use warnings;
use JSON qw(encode_json decode_json);
use LWP::UserAgent;
use Coreauto::Result;
# Copyright Core DF — Apache License 2.0

sub _post_json {
    my ($url, $payload) = @_;
    my $ua = LWP::UserAgent->new(timeout => 30);
    my $resp = eval { $ua->post($url, 'Content-Type' => 'application/json', Content => encode_json($payload)) };
    return Coreauto::Result::transport_error($@) if !$resp || $@;
    my $code = $resp->code;
    my $text = $resp->content;
    return { status_code => $code, error => $text } if $code >= 400;
    return { status_code => 200 } if !defined $text || $text eq '';
    my $body = eval { decode_json($text) }; $body = $text if $@;
    return { status_code => 200, body => $body };
}

sub Slack {
    my ($text, $webhook_url) = @_;
    $webhook_url //= $ENV{SLACK_WEBHOOK_URL} // '';
    return Coreauto::Result::missing_env('SLACK_WEBHOOK_URL') unless $webhook_url;
    return _post_json($webhook_url, { text => $text });
}

sub Teams {
    my ($text, $webhook_url) = @_;
    $webhook_url //= $ENV{TEAMS_WEBHOOK_URL} // '';
    return Coreauto::Result::missing_env('TEAMS_WEBHOOK_URL') unless $webhook_url;
    return _post_json($webhook_url, {
        '@type' => 'MessageCard',
        '@context' => 'http://schema.org/extensions',
        text => $text,
    });
}

sub PagerDuty {
    my ($summary, $routing_key, $severity) = @_;
    $routing_key //= $ENV{PAGERDUTY_ROUTING_KEY} // '';
    $severity //= 'error';
    return Coreauto::Result::missing_env('PAGERDUTY_ROUTING_KEY') unless $routing_key;
    return _post_json('https://events.pagerduty.com/v2/enqueue', {
        routing_key => $routing_key,
        event_action => 'trigger',
        payload => { summary => $summary, severity => $severity, source => 'coreauto-step' },
    });
}

sub Email {
    my ($subject, $body, $to_addrs, $from_addr) = @_;
    my $host = $ENV{SMTP_HOST} // '';
    my $port = $ENV{SMTP_PORT} // 587;
    my $user = $ENV{SMTP_USER} // '';
    my $password = $ENV{SMTP_PASSWORD} // '';
    my $sender = $from_addr // $ENV{SMTP_FROM} // $user;
    return Coreauto::Result::missing_env('SMTP_HOST and SMTP_FROM (or from_addr)') unless $host && $sender;
    eval {
        require Net::SMTP;
        require MIME::Lite;
    };
    return { status_code => 500, error => 'MIME::Lite and Net::SMTP required' } if $@;
    my $msg = MIME::Lite->new(
        From => $sender,
        To => $to_addrs,
        Subject => $subject,
        Type => 'text/plain',
        Data => $body // '',
    );
    my $smtp = Net::SMTP->new($host, Port => $port, Timeout => 60);
    return Coreauto::Result::transport_error('smtp connect failed') unless $smtp;
    if ($user && $password) {
        $smtp->starttls if $smtp->can('starttls');
        $smtp->auth($user, $password) or return Coreauto::Result::transport_error('smtp auth failed');
    }
    $msg->send($smtp, 'send') or return Coreauto::Result::transport_error('smtp send failed');
    return { status_code => 200 };
}

1;
