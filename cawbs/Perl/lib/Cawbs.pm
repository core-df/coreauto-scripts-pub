# Copyright (c) Core DF. All rights reserved.
#
# Core Auto Web Services library (cawbs) — Perl client for the Core Auto Collector.
#
# Documentation: https://coreauto.coredf.com/resources

package Cawbs;

use strict;
use warnings;
use File::Basename qw(dirname);
use lib dirname(__FILE__);
use Wbs;

my $sess = Wbs::Session->new;

sub Init {
    my $env         = $ENV{ENV}            // '';
    my $action_id   = $ENV{ACTIONID}       // '';
    my $access_code = $ENV{CA_ACCESS_CODE} // '';
    my $base_url    = $ENV{CA_WBS_URL}     // '';
    my $step_name   = $ENV{STEPNAME}       // '';
    if ($env eq '' || $action_id eq '' || $access_code eq '' || $base_url eq '' || $step_name eq '') {
        return Wbs::missing_env('ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME');
    }
    return $sess->authenticate($env, $access_code, $base_url);
}

sub GetEventPayload {
    return $sess->get_event_payload($ENV{ACTIONID});
}

sub PutStepPayload {
    my ($payload) = @_;
    return $sess->put_step_payload($ENV{ACTIONID}, $ENV{STEPNAME}, $payload);
}

sub GetStepPayload {
    my ($stepname) = @_;
    return $sess->get_step_payload($ENV{ACTIONID}, $stepname);
}

sub GetKeystore {
    my ($keylist) = @_;
    return $sess->get_keystore($keylist);
}

1;
