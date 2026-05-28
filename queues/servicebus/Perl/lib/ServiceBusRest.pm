package ServiceBusRest;
use strict;
use warnings;
use JSON qw(encode_json decode_json);
use LWP::UserAgent;
use URI::Escape qw(uri_escape);
use Digest::SHA qw(hmac_sha256);
use MIME::Base64 qw(encode_base64);
# Copyright Core DF — Apache License 2.0

sub _parse_conn {
    my ($conn) = @_;
    my %parts = map { my @p = split /=/, $_, 2; $p[0] => $p[1] // '' } split /;/, $conn;
    my $endpoint = $parts{Endpoint} // '';
    $endpoint =~ s{^sb://}{https://};
    $endpoint =~ s{/$}{};
    return (\%parts, $endpoint);
}

sub _sas_token {
    my ($resource, $key_name, $key) = @_;
    my $expiry = time() + 3600;
    my $encoded = uri_escape($resource);
    my $sig = encode_base64(hmac_sha256("$encoded\n$expiry", $key), '');
    chomp $sig;
    return "SharedAccessSignature sr=$encoded&sig=@{[uri_escape($sig)]}&se=$expiry&skn=@{[uri_escape($key_name)]}";
}

sub send_message {
    my ($conn, $queue, $body) = @_;
    my ($parts, $endpoint) = _parse_conn($conn);
    my $resource = "$endpoint/$queue";
    my $ua = LWP::UserAgent->new(timeout => 60);
    my $payload = ref $body ? encode_json($body) : $body;
    my $resp = $ua->post(
        "$resource/messages",
        'Authorization' => _sas_token($resource, $parts->{SharedAccessKeyName}, $parts->{SharedAccessKey}),
        'Content-Type' => 'application/json',
        Content => $payload,
    );
    return { status_code => $resp->code, error => $resp->content } if $resp->code >= 400;
    return { status_code => 200 };
}

sub receive_messages {
    my ($conn, $queue, $timeout_sec, $max_messages, $complete) = @_;
    my ($parts, $endpoint) = _parse_conn($conn);
    my $resource = "$endpoint/$queue";
    my $ua = LWP::UserAgent->new(timeout => $timeout_sec + 10);
    my @messages;
    for (1 .. ($max_messages // 1)) {
        my $resp = $ua->post(
            "$resource/messages/head?timeout=@{[int($timeout_sec)]}",
            'Authorization' => _sas_token($resource, $parts->{SharedAccessKeyName}, $parts->{SharedAccessKey}),
        );
        last if $resp->code == 204 || !$resp->content;
        return { status_code => $resp->code, error => $resp->content } if $resp->code >= 400;
        my $value = eval { decode_json($resp->content) }; $value = $resp->content if $@;
        my $lock;
        if (my $bp = $resp->header('BrokerProperties')) {
            my $props = eval { decode_json($bp) };
            $lock = $props->{LockToken} if ref $props eq 'HASH';
        }
        push @messages, { queue => $queue, value => $value };
        if ($complete && $lock) {
            $ua->delete("$resource/messages/$lock", Authorization => _sas_token($resource, $parts->{SharedAccessKeyName}, $parts->{SharedAccessKey}));
        }
    }
    return { status_code => 200, messages => \@messages };
}

1;
