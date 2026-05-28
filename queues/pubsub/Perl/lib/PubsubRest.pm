package PubsubRest;
use strict;
use warnings;
use JSON qw(encode_json decode_json);
use LWP::UserAgent;
use MIME::Base64 qw(encode_base64 decode_base64);
# Copyright Core DF — Apache License 2.0

sub _token {
    return $ENV{GOOGLE_ACCESS_TOKEN} if $ENV{GOOGLE_ACCESS_TOKEN};
    my $out = `gcloud auth application-default print-access-token 2>/dev/null`;
    chomp $out;
    return $out;
}

sub publish {
    my ($project, $topic, $value) = @_;
    my $token = _token();
    return { status_code => 500, error => 'gcloud auth or GOOGLE_ACCESS_TOKEN required' } unless $token;
    my $data = ref $value ? encode_json($value) : $value;
    my $encoded = encode_base64($data, '');
    chomp $encoded;
    my $ua = LWP::UserAgent->new(timeout => 60);
    my $resp = $ua->post(
        "https://pubsub.googleapis.com/v1/projects/$project/topics/$topic:publish",
        Authorization => "Bearer $token",
        'Content-Type' => 'application/json',
        Content => encode_json({ messages => [{ data => $encoded }] }),
    );
    return { status_code => $resp->code, error => $resp->content } if $resp->code >= 400;
    my $parsed = eval { decode_json($resp->content) };
    return { status_code => 200, message_id => $parsed->{messageIds}[0] };
}

sub pull {
    my ($project, $subscription, $max_messages, $ack) = @_;
    my $token = _token();
    return { status_code => 500, error => 'gcloud auth or GOOGLE_ACCESS_TOKEN required' } unless $token;
    my $ua = LWP::UserAgent->new(timeout => 60);
    my $resp = $ua->post(
        "https://pubsub.googleapis.com/v1/projects/$project/subscriptions/$subscription:pull",
        Authorization => "Bearer $token",
        'Content-Type' => 'application/json',
        Content => encode_json({ maxMessages => $max_messages // 1 }),
    );
    return { status_code => $resp->code, error => $resp->content } if $resp->code >= 400;
    my $parsed = eval { decode_json($resp->content) } // {};
    my @messages;
    my @ack_ids;
    for my $item (@{ $parsed->{receivedMessages} // [] }) {
        my $raw = decode_base64($item->{message}{data} // '');
        my $value = eval { decode_json($raw) }; $value = $raw unless ref $value;
        push @messages, { subscription => $subscription, message_id => $item->{message}{messageId}, value => $value };
        push @ack_ids, $item->{ackId} if $item->{ackId};
    }
    if ($ack && @ack_ids) {
        $ua->post(
            "https://pubsub.googleapis.com/v1/projects/$project/subscriptions/$subscription:acknowledge",
            Authorization => "Bearer $token",
            'Content-Type' => 'application/json',
            Content => encode_json({ ackIds => \@ack_ids }),
        );
    }
    return { status_code => 200, messages => \@messages };
}

1;
