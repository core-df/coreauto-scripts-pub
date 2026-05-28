package S3client;
use strict;
use warnings;
use File::Temp qw(tempfile);
use Coreauto::Result;
# Copyright Core DF — Apache License 2.0
# Uses AWS CLI (aws) on PATH for S3 operations.

sub _env {
    my ($k, $fallback) = @_;
    my $v = $ENV{$k};
    return $v if defined $v && $v ne '';
    return $fallback // '';
}

sub _bucket {
    my ($explicit) = @_;
    return $explicit if defined $explicit && $explicit ne '';
    return _env('S3_BUCKET');
}

sub _aws_base {
    my $region = _env('AWS_REGION', _env('AWS_DEFAULT_REGION', 'us-east-1'));
    my $endpoint = _env('S3_ENDPOINT_URL');
    my @parts = ('aws', '--region', $region);
    if ($endpoint ne '') {
        push @parts, '--endpoint-url', $endpoint;
    }
    return join ' ', map { $_ =~ /\s/ ? qq('$_') : $_ } @parts;
}

sub _run {
    my ($cmd) = @_;
    my $out = `$cmd 2>&1`;
    my $rc = $? >> 8;
    return ($out, undef) if $rc == 0;
    return ($out, $out);
}

sub Init {
    return Coreauto::Result::missing_env('AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE')
        unless _env('AWS_ACCESS_KEY_ID') || _env('AWS_PROFILE');
    return Coreauto::Result::missing_env('S3_BUCKET (or pass bucket per call)') unless _env('S3_BUCKET');
    return { status_code => 200 };
}

sub GetObject {
    my ($key, $bucket_name) = @_;
    my $b = _bucket($bucket_name);
    return Coreauto::Result::missing_env('S3_BUCKET') unless $b;
    my $cmd = sprintf("%s s3 cp s3://%s/%s -", _aws_base(), $b, $key);
    my ($out, $err) = _run($cmd);
    return Coreauto::Result::transport_error($err) if $err;
    return { status_code => 200, content => $out // '' };
}

sub PutObject {
    my ($key, $content, $bucket_name) = @_;
    my $b = _bucket($bucket_name);
    return Coreauto::Result::missing_env('S3_BUCKET') unless $b;
    my ($fh, $tmp) = tempfile();
    print {$fh} $content // '';
    close $fh;
    my $cmd = sprintf("%s s3 cp %s s3://%s/%s", _aws_base(), $tmp, $b, $key);
    my ($_, $err) = _run($cmd);
    unlink $tmp;
    return Coreauto::Result::transport_error($err) if $err;
    return { status_code => 200 };
}

sub ListObjects {
    my ($prefix, $bucket_name) = @_;
    $prefix //= '';
    my $b = _bucket($bucket_name);
    return Coreauto::Result::missing_env('S3_BUCKET') unless $b;
    my $uri = "s3://$b/";
    $uri .= $prefix if $prefix ne '';
    my $cmd = sprintf("%s s3 ls %s --recursive", _aws_base(), $uri);
    my ($out, $err) = _run($cmd);
    return Coreauto::Result::transport_error($err) if $err;
    my @keys;
    for my $line (split /\r?\n/, $out // '') {
        if ($line =~ /\S+\s+\S+\s+\S+\s+\S+\s+(.+)$/) {
            push @keys, $1;
        }
    }
    return { status_code => 200, keys => \@keys };
}

1;
