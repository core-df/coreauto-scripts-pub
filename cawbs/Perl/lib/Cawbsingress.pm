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
# Ingress-oriented cawbs client for the Core Auto Collector.
#
# Documentation: https://coreauto.coredf.com/resources

package Cawbsingress;

use strict;
use warnings;
use File::Basename qw(dirname);
use lib dirname(__FILE__);
use Wbs;

my $sess = Wbs::Session->new;

sub Init {
    my $env         = $ENV{ENV}            // '';
    my $access_code = $ENV{CA_ACCESS_CODE} // '';
    my $base_url    = $ENV{CA_WBS_URL}     // '';
    if ($env eq '' || $access_code eq '' || $base_url eq '') {
        return Wbs::missing_env('ENV, CA_ACCESS_CODE, CA_WBS_URL');
    }
    return $sess->authenticate($env, $access_code, $base_url);
}

sub PostEvent {
    my ($event_name, $payload, $event_source) = @_;
    my $r = $sess->post_event($event_name, $payload, $event_source);
    return $r if $r->{error};
    my $js = $r->{payload};
    return {
        status_code => $r->{status_code},
        eventId     => $js->{eventId},
        actionId    => $js->{actionId},
        createdAt   => $js->{createdAt},
    };
}

sub GetEventStatus {
    my ($action_id) = @_;
    my $r = $sess->get_event_status($action_id);
    return $r if $r->{error};
    return { status_code => $r->{status_code}, status => $r->{payload} };
}

sub GetEventList {
    my $r = $sess->get_event_list();
    return $r if $r->{error};
    return { status_code => $r->{status_code}, events => $r->{payload} };
}

sub SubmitFlag {
    my ($name, $system_name, $source_system_name, $date) = @_;
    my $r = $sess->submit_flag($name, $system_name, $source_system_name, $date);
    return $r if $r->{error};
    return {
        status_code => $r->{status_code},
        flagStatus  => $r->{payload}{status},
    };
}

sub GetKeystore {
    my ($keylist) = @_;
    return $sess->get_keystore($keylist);
}

1;
