#!/usr/bin/env perl
# Copyright Core DF
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Core Auto real-time step — full integration example (Perl port).
use strict;
use warnings;
use JSON qw(encode_json);
use FindBin qw($Bin);
use lib $Bin;
require 'lib.pl';

sub ok {
    my ($r, $label) = @_;
    my $code = $r->{status_code} // 0;
    if ($code >= 400 || !$code) {
        print encode_json({ step => $label, error => $r }) . "\n";
        exit 1;
    }
    return $r;
}

sub optional {
    my ($label, $fn) = @_;
    my $r = $fn->();
    my $code = $r->{status_code} // 0;
    my $err = lc($r->{error} // '');
    if (grep { $_ == $code } (601, 500) && index($err, 'missing') >= 0) {
        print "[skip] $label: not configured\n";
        return;
    }
    if ($code >= 400 || !$code) {
        print "[warn] $label\n";
        return;
    }
    print "[ok] $label\n";
    return $r;
}

ok(Cawbs::Init(), 'cawbs.Init');
my $event = ok(Cawbs::GetEventPayload(), 'cawbs.GetEventPayload');
my $payload = $event->{payload} // {};
my $order_id = $payload->{orderId} // $payload->{id} // 'unknown';
my $ack_dir = $ENV{EXAMPLE_ACK_DIR} // '/tmp/coreauto-example';
mkdir $ack_dir unless -d $ack_dir;
my $ack_path = "$ack_dir/$order_id.json";
my $order = { orderId => $order_id, details => $payload };
my $text = ok(Transformclient::JsonStringify($order), 'transform.JsonStringify');
ok(Fileclient::LocalWrite($ack_path, $text->{text}), 'files.LocalWrite');

my @published;
my $topic = $ENV{EXAMPLE_KAFKA_TOPIC} // 'orders.enriched';
optional('queues.kafka', sub { Kafkaclient::Produce($topic, $order) }) and push @published, 'kafka';

my $output = { orderId => $order_id, queuesPublished => \@published, ackPath => $ack_path };
ok(Cawbs::PutStepPayload($output), 'cawbs.PutStepPayload');
print encode_json({ status_code => 200, result => $output }) . "\n";
