package Fileclient;
use strict;
use warnings;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use Coreauto::Result;
# Copyright Core DF — Apache License 2.0

sub LocalRead {
    my ($path, %opt) = @_;
    my $enc = $opt{encoding} // 'utf-8';
    open my $fh, '<:encoding(' . $enc . ')', $path or return { status_code => 500, error => $! };
    local $/; my $content = <$fh>; close $fh;
    return { status_code => 200, content => $content // '' };
}

sub LocalWrite {
    my ($path, $content, %opt) = @_;
    my $enc = $opt{encoding} // 'utf-8';
    my $dir = dirname($path);
    if ($dir && $dir ne '.') { eval { make_path($dir) }; }
    open my $fh, '>:encoding(' . $enc . ')', $path or return { status_code => 500, error => $! };
    print {$fh} $content // '';
    close $fh;
    return { status_code => 200 };
}

sub LocalMove {
    my ($src, $dest) = @_;
    return { status_code => 500, error => $! } unless rename $src, $dest;
    return { status_code => 200 };
}

sub _sftp_connect {
    eval { require Net::SFTP::Foreign };
    die 'Net::SFTP::Foreign required' if $@;
    my $host = $ENV{SFTP_HOST} // '';
    my $user = $ENV{SFTP_USER} // '';
    my $password = $ENV{SFTP_PASSWORD} // '';
    my $port = $ENV{SFTP_PORT} // 22;
    my $key = $ENV{SFTP_PRIVATE_KEY} // '';
    die 'SFTP_HOST and SFTP_USER required' unless $host && $user;
    my %args = (host => $host, user => $user, port => $port, more => ['-oBatchMode=yes']);
    if ($key) { $args{key_path} = $key; }
    elsif ($password) { $args{password} = $password; }
    else { die 'SFTP_PASSWORD or SFTP_PRIVATE_KEY required'; }
    return Net::SFTP::Foreign->new(%args);
}

sub SftpGet {
    my ($remote_path, $local_path) = @_;
    eval {
        my $sftp = _sftp_connect();
        my $dir = dirname($local_path);
        make_path($dir) if $dir && $dir ne '.';
        $sftp->get($remote_path, $local_path) or die $sftp->error;
    };
    return { status_code => 500, error => $@ } if $@;
    return { status_code => 200 };
}

sub SftpPut {
    my ($local_path, $remote_path) = @_;
    eval {
        my $sftp = _sftp_connect();
        $sftp->put($local_path, $remote_path) or die $sftp->error;
    };
    return { status_code => 500, error => $@ } if $@;
    return { status_code => 200 };
}

1;
