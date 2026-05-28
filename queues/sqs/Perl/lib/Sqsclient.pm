package Sqsclient;
use strict;
use warnings;
# Copyright Core DF — Apache License 2.0
use JSON qw(encode_json decode_json);
use Coreauto::Result;

sub _queue_url {
    my ($explicit) = @_;
    return $explicit if defined $explicit && $explicit ne '';
    return $ENV{SQS_QUEUE_URL} // '';
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
    return Coreauto::Result::missing_env('AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE')
        unless $ENV{AWS_ACCESS_KEY_ID} || $ENV{AWS_PROFILE};
    return Coreauto::Result::missing_env('SQS_QUEUE_URL (or pass queue_url per call)')
        unless $ENV{SQS_QUEUE_URL};
    return { status_code => 200 };
}

sub Send {
    my ($value, $queue_url) = @_;
    my $url = _queue_url($queue_url);
    return Coreauto::Result::missing_env('SQS_QUEUE_URL') unless $url;
    eval { require Paws; 1 } or return { status_code => 500, error => 'Paws CPAN module required' };
    eval {
        my $region = $ENV{AWS_REGION} // $ENV{AWS_DEFAULT_REGION} // 'us-east-1';
        my $sqs = Paws->service('SQS', region => $region);
        my $resp = $sqs->SendMessage(QueueUrl => $url, MessageBody => _encode($value));
        return { status_code => 200, message_id => $resp->MessageId };
    } or return Coreauto::Result::transport_error($@);
}

sub Receive {
    my ($queue_url, $max_messages, $wait_time_sec, $delete) = @_;
    $max_messages = 1 unless defined $max_messages;
    $wait_time_sec = 10 unless defined $wait_time_sec;
    $delete = 1 unless defined $delete;
    my $url = _queue_url($queue_url);
    return Coreauto::Result::missing_env('SQS_QUEUE_URL') unless $url;
    eval { require Paws; 1 } or return { status_code => 500, error => 'Paws CPAN module required' };
    eval {
        my $region = $ENV{AWS_REGION} // $ENV{AWS_DEFAULT_REGION} // 'us-east-1';
        my $sqs = Paws->service('SQS', region => $region);
        $max_messages = 1 if $max_messages < 1;
        $max_messages = 10 if $max_messages > 10;
        my $resp = $sqs->ReceiveMessage(
            QueueUrl            => $url,
            MaxNumberOfMessages => $max_messages,
            WaitTimeSeconds     => $wait_time_sec,
        );
        my @messages;
        for my $item (@{ $resp->Messages // [] }) {
            push @messages, {
                message_id     => $item->MessageId,
                receipt_handle => $item->ReceiptHandle,
                value          => _decode($item->Body // ''),
            };
            if ($delete && $item->ReceiptHandle) {
                $sqs->DeleteMessage(QueueUrl => $url, ReceiptHandle => $item->ReceiptHandle);
            }
        }
        return { status_code => 200, messages => \@messages };
    } or return Coreauto::Result::transport_error($@);
}

1;
