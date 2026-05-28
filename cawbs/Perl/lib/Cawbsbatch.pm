# Copyright (c) Core DF. All rights reserved.
#
# Batch-oriented cawbs client for the Core Auto Collector.
#
# Documentation: https://coreauto.coredf.com/resources

package Cawbsbatch;

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

sub GetKeystore {
    my ($keylist) = @_;
    return $sess->get_keystore($keylist);
}

1;
