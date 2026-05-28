# Copyright Core DF

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
# Shared HTTP helpers for the Core Auto Collector (cawbs) Perl client.

package Wbs;

use strict;
use warnings;
use JSON qw(decode_json encode_json);
use LWP::UserAgent;
use HTTP::Request;

sub missing_env {
    my ($vars) = @_;
    return { status_code => 601, error => "Environment variables $vars should be defined" };
}

sub trim_url {
    my ($url) = @_;
    $url =~ s{\A[/ ]+|[/ ]+\z}{}g;
    return $url;
}

sub do_request {
    my ($method, $url, $headers, $body) = @_;
    my $ua = LWP::UserAgent->new(timeout => 60);
    my $req = HTTP::Request->new($method => $url);
    for my $k (keys %$headers) {
        $req->header($k => $headers->{$k});
    }
    $req->content($body) if defined $body;

    my $resp = eval { $ua->request($req) };
    return (0, undef) if !$resp || $@;

    my $code = $resp->code;
    my $parsed;
    if ($resp->content ne '') {
        eval { $parsed = decode_json($resp->content) };
        $parsed = undef if $@;
    }
    return ($code, $parsed);
}

sub api_error {
    my ($status_code, $body) = @_;
    return { status_code => $status_code, error => 'inaccessible' } if !defined $body;
    return { status_code => $status_code, error => $body };
}

package Wbs::Session;

use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless {
        initialized => 0,
        base_url    => '',
        headers     => {},
    }, $class;
}

sub authenticate {
    my ($self, $env, $access_code, $base_url) = @_;
    return { status_code => 602, error => 'init already called' } if $self->{initialized};

    $self->{base_url} = Wbs::trim_url($base_url);
    my %headers = (
        'Content-Type' => 'application/json',
        Environment    => $env,
    );
    my ($status_code, $body) = Wbs::do_request(
        'POST',
        "$self->{base_url}/v1/auth/apicode",
        \%headers,
        encode_json({ apiCode => $access_code }),
    );
    return { status_code => $status_code, error => 'inaccessible' } if $status_code == 0;
    return Wbs::api_error($status_code, $body) if $status_code >= 400;
    return { status_code => $status_code, error => 'inaccessible' }
        if ref($body) ne 'HASH' || !$body->{token};

    $headers{Authorization} = 'Bearer ' . $body->{token};
    $self->{headers} = \%headers;
    $self->{initialized} = 1;
    return { status_code => $status_code };
}

sub get_event_payload {
    my ($self, $action_id) = @_;
    return { status_code => 603, error => 'Init required' } if !$self->{initialized};

    my ($status_code, $body) = Wbs::do_request(
        'GET', "$self->{base_url}/v1/rtevent/$action_id", $self->{headers});
    return { status_code => $status_code, error => 'inaccessible' } if $status_code == 0;
    return Wbs::api_error($status_code, $body) if $status_code >= 400;
    return { status_code => $status_code, error => 'inaccessible' } if !defined $body;

    return { status_code => $status_code, payload => $body->{payload} };
}

sub put_step_payload {
    my ($self, $action_id, $step_name, $payload) = @_;
    return { status_code => 603, error => 'Init required' } if !$self->{initialized};

    my ($status_code, $body) = Wbs::do_request(
        'POST',
        "$self->{base_url}/v1/rtstep/payload",
        $self->{headers},
        encode_json({ actionId => $action_id, stepname => $step_name, payload => $payload }),
    );
    return { status_code => $status_code, error => 'inaccessible' } if $status_code == 0;
    return Wbs::api_error($status_code, $body) if $status_code >= 400;
    return { status_code => $status_code };
}

sub get_step_payload {
    my ($self, $action_id, $step_name) = @_;
    return { status_code => 603, error => 'Init required' } if !$self->{initialized};

    my ($status_code, $body) = Wbs::do_request(
        'GET',
        "$self->{base_url}/v1/rtstep/payload/$action_id/$step_name",
        $self->{headers},
    );
    return { status_code => $status_code, error => 'inaccessible' } if $status_code == 0;
    return Wbs::api_error($status_code, $body) if $status_code >= 400;
    return { status_code => $status_code, error => 'inaccessible' } if !defined $body;

    return { status_code => $status_code, payload => $body->{payload} };
}

sub get_keystore {
    my ($self, $keylist) = @_;
    return { status_code => 603, error => 'Init required' } if !$self->{initialized};

    my $keys = $keylist;
    $keys =~ s/ //g;
    my ($status_code, $body) = Wbs::do_request(
        'GET', "$self->{base_url}/v1/keystore/$keys", $self->{headers});
    return { status_code => $status_code, error => 'inaccessible' } if $status_code == 0;
    return Wbs::api_error($status_code, $body) if $status_code >= 400;
    return { status_code => $status_code, error => 'inaccessible' } if ref($body) ne 'HASH';

    for my $key (split /,/, $keys) {
        next if $key eq '';
        return { status_code => 605, error => "$key not found" } if !exists $body->{$key};
    }
    return { status_code => $status_code, answer => $body };
}

1;
