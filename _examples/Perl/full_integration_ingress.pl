#!/usr/bin/env perl
# Copyright Core DF — Apache License 2.0
# Kafka ingress bridge — Perl port.
use strict;
use warnings;
use JSON qw(encode_json);
use FindBin qw($Bin);
use lib "$Bin/../../queues/ingress/Perl";
use lib "$Bin/../../queues/kafka/Perl/lib";
require "$Bin/../../queues/ingress/Perl/ingress.pl";
require Kafkaclient;

my $topic = $ARGV[0] // $ENV{EXAMPLE_KAFKA_TOPIC} // 'orders.inbound';
warn "Bridging Kafka topic $topic\n";
while (1) {
    my $r = Ingress::RunBridge(sub { Kafkaclient::Consume($topic, 30, 10) });
    my $code = $r->{status_code} // 0;
    if ($code >= 400 || !$code) {
        warn encode_json($r);
        sleep 5;
        next;
    }
    print encode_json({ forwarded => $r->{forwarded} }) . "\n" if $r->{forwarded};
}
