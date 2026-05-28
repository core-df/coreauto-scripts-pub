package Ingress;
use strict;
use warnings;
use lib '../../../cawbs/Perl/lib';
use Cawbsingress;
use Coreauto::Result;
# Copyright Core DF — Apache License 2.0

sub TriggerEvent {
    my ($payload, $event_name, $event_source) = @_;
    my $name = defined $event_name ? $event_name : ($ENV{CA_EVENT_NAME} // '');
    return Coreauto::Result::missing_env('CA_EVENT_NAME (or pass event_name)') unless $name;
    my $source = defined $event_source ? $event_source : ($ENV{CA_EVENT_SOURCE} // '');
    my $init = Cawbsingress::Init();
    return $init if ($init->{status_code} // 0) >= 400;
    return Cawbsingress::PostEvent($name, $payload, ($source ne '' ? $source : undef));
}

sub ForwardMessages {
    my ($consume_result) = @_;
    return $consume_result if ($consume_result->{status_code} // 0) != 200;
    my @forwarded;
    for my $msg (@{ $consume_result->{messages} // [] }) {
        my $value = exists $msg->{value} ? $msg->{value} : $msg;
        my $result = TriggerEvent($value);
        return $result if ($result->{status_code} // 0) >= 400;
        push @forwarded, { actionId => $result->{actionId}, eventId => $result->{eventId} };
    }
    return { status_code => 200, forwarded => \@forwarded };
}

sub RunBridge {
    my ($consume_fn, @args) = @_;
    return ForwardMessages($consume_fn->(@args));
}

1;
