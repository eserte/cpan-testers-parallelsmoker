#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use CGI qw(:standard);
use HTML::Table;
use YAML::Syck qw(LoadFile);

my $smoke_cfg_dir = "$FindBin::RealBin/..";
my $utils_dir = "$FindBin::RealBin/../utils";
my $ctps_dir = "/home/cpansand/var/ctps"; # XXX !!! do not hardcode (but how to get this info?)

my $smoke = param("smoke");
if (!$smoke) {
    show_all_smokes();
} else {
    show_smoke($smoke);
}

sub show_smoke {
    my($smoke) = @_;
    require File::Glob;
    my $found;
    for my $cfg (File::Glob::bsd_glob("$smoke_cfg_dir/smoke*.yml")) {
	my $d = eval { LoadFile($cfg) };
	next if !$d || !$d->{smoke};
	if ($d->{smoke}->{testlabel} eq $smoke) {
	    $found = $d->{smoke};
	    last;
	}
    }
    if (!$found) { die "Cannot find smoke with name $smoke" }

    my $testlabel = $found->{testlabel};

    my @diffs = `$utils_dir/cmp_ct_history.pl -missing $ctps_dir/$testlabel/config/perl-*/cpanreporter/reports-sent.db`;

    print header;
    print start_html;
    print "<b>Differences:</b><br>\n";
    print "<pre>";
    print @diffs;
    print "</pre>";
    print end_html;
}

sub show_all_smokes {
    require Data::Dumper;
    require File::Glob;

    my %possible_cols;
    my @smokes;

    for my $cfg (File::Glob::bsd_glob("$smoke_cfg_dir/smoke*.yml")) {
	my $d = eval { LoadFile($cfg) };
	next if !$d || !$d->{smoke};
	for my $k (keys %{ $d->{smoke} }) {
	    $possible_cols{$k} = 1;
	}
	push @smokes, $d->{smoke};
    }

    my @matrix;
    for my $smoke (@smokes) {
	my @row;
	for my $key (sort keys %possible_cols) {
	    my $val = $smoke->{$key};
	    if (defined $val) {
		if (ref $val) {
		    local $Data::Dumper::Indent = 0;
		    $val = Data::Dumper::Dumper($val);
		    $val =~ s{^\$VAR\d+\s+=\s+}{};
		}
	    } else {
		$val = "";
	    }
	    if ($key eq 'testlabel') {
		my $qq = CGI->new();
		$qq->param("smoke", $val);
		push @row, qq{<a href="@{[ $qq->self_url ]}">$val</a>};
	    } else {
		push @row, $val;
	    }
	}
	push @matrix, \@row;
    }

    # HTML output
    print header;
    print start_html;
    my $table = HTML::Table->new(-head    => [sort keys %possible_cols],
				 -spacing => 0,
				 -data    => \@matrix,
				 -class   => 'reports',
				);
    $table->setColHead(1);
    $table->print;
    print end_html;
}

__END__
