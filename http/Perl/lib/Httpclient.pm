package Httpclient;
use strict; use warnings;
use JSON qw(decode_json encode_json);
use LWP::UserAgent;
use HTTP::Request;
use URI;
use Coreauto::Result;
# Copyright Core DF — Apache License 2.0
sub _parse_body { my ($raw)=@_; return undef if !defined $raw || $raw eq ''; eval { return decode_json($raw) }; return $raw if $@; }
sub _request {
    my ($method,$url,$headers,$body,$params)=@_;
    if ($params && %$params) { my $u=URI->new($url); $u->query_form($u->query_form, %$params); $url=$u->as_string; }
    my $ua=LWP::UserAgent->new(timeout=>60);
    my $req=HTTP::Request->new($method=>$url);
    for my $k (keys %{$headers||{}}) { $req->header($k=>$headers->{$k}); }
    $req->content($body) if defined $body;
    my $resp=eval { $ua->request($req) }; return Coreauto::Result::transport_error($@) if !$resp || $@;
    my $code=$resp->code; my $parsed=_parse_body($resp->content);
    return $code>=400 ? {status_code=>$code, error=>$parsed//'inaccessible'} : {status_code=>$code, body=>$parsed};
}
sub Get { my ($url,%opt)=@_; _request('GET',$url,$opt{headers},undef,$opt{params}); }
sub Post { my ($url,%opt)=@_; my %h=%{$opt{headers}||{}}; my $body; if (defined $opt{json_body}) { $h{'Content-Type'}||='application/json'; $body=encode_json($opt{json_body}); } elsif (defined $opt{data}) { $body=$opt{data}; } _request('POST',$url,\%h,$body); }
sub Put { my ($url,%opt)=@_; my %h=%{$opt{headers}||{}}; my $body; if (defined $opt{json_body}) { $h{'Content-Type'}||='application/json'; $body=encode_json($opt{json_body}); } _request('PUT',$url,\%h,$body); }
sub Delete { my ($url,%opt)=@_; _request('DELETE',$url,$opt{headers}); }
1;
