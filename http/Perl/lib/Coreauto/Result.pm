package Coreauto::Result;
use strict; use warnings;
# Copyright Core DF — Apache License 2.0
sub missing_env { my ($vars)=@_; return { status_code => 601, error => "Environment variables $vars should be defined" }; }
sub transport_error { my ($msg)=@_; $msg='inaccessible' unless defined $msg; return { status_code => 0, error => $msg }; }
1;
