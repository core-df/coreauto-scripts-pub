package Transformclient;
use strict; use warnings;
use JSON qw(decode_json encode_json);
use Text::CSV;
use XML::Simple qw(XMLin XMLout);
# Copyright Core DF — Apache License 2.0
sub JsonParse { my ($text)=@_; eval { return {status_code=>200,data=>decode_json($text)} }; return {status_code=>400,error=>$@}; }
sub JsonStringify { my ($data,$indent)=@_; eval { my $t=$indent?encode_json($data):encode_json($data); return {status_code=>200,text=>$t}; }; return {status_code=>400,error=>$@}; }
sub CsvToRows { my ($text,$delim)=@_; $delim=',' unless defined $delim; my $csv=Text::CSV->new({sep_char=>$delim}); open my $fh,'<',\$text; my $hdr=$csv->getline($fh); return {status_code=>400,error=>'empty csv'} unless $hdr; my @rows; while (my $r=$csv->getline($fh)) { my %row; @row{@$hdr}=@$r; push @rows,\%row; } return {status_code=>200,rows=>\@rows}; }
sub RowsToCsv { my ($rows,$delim)=@_; return {status_code=>400,error=>'rows must not be empty'} unless $rows && @$rows; $delim=',' unless defined $delim; my @k=keys %{$rows->[0]}; my $out=join($delim,@k)."\n"; for (@$rows) { $out.=join($delim,map {$_->{$_}//''} @k)."\n"; } return {status_code=>200,text=>$out}; }
sub XmlToDict { my ($text)=@_; eval { my $x=XMLin($text,ForceArray=>0,KeyAttr=>[]); my ($root)=keys %$x; return {status_code=>200,data=>{$root=>$x->{$root}}}; }; return {status_code=>400,error=>$@}; }
sub DictToXml { my ($data,$root)=@_; $root='root' unless defined $root; eval { return {status_code=>200,text=>XMLout($data,RootName=>$root,NoAttr=>1)}; }; return {status_code=>400,error=>$@}; }
1;
