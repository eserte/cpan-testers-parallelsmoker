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
use CGI qw(:standard escapeHTML);
use File::Glob qw(bsd_glob);
use HTML::Table;
use YAML::Syck qw(LoadFile);

my $smoke_cfg_dir = "$FindBin::RealBin/..";
my $utils_dir = "$FindBin::RealBin/../utils";
my $ctps_dir = "/home/cpansand/var/ctps"; # XXX !!! do not hardcode (but how to get this info?)

my $smoke = param("smoke");
my $min = param("min");
if (!$smoke) {
    show_all_smokes();
} else {
    if (param("notes")) {
	show_smoke_notes($smoke);
    } else {
	show_smoke($smoke);
    }
}

sub _find_smoke {
    my($smoke) = @_;
    my $found;
    for my $cfg (bsd_glob("$smoke_cfg_dir/smoke*.yml")) {
	my $d = eval { LoadFile($cfg) };
	next if !$d || !$d->{smoke};
	if ($d->{smoke}->{testlabel} eq $smoke) {
	    $found = $d->{smoke};
	    last;
	}
    }
    if (!$found) { die "Cannot find smoke with name $smoke" }
    $found;
}

sub show_smoke {
    my($smoke) = @_;
    my $found = _find_smoke($smoke);
    my $testlabel = $found->{testlabel};

    my $mins = $min >= 0 && $min <= 4 ? (" -min ") x $min : "";
    my @hist_dbs = reverse bsd_glob("$ctps_dir/$testlabel/config/perl-*/cpanreporter/reports-sent.db"); # reverse! new, then old!
    my @diffs = `$utils_dir/cmp_ct_history.pl $mins @hist_dbs`;
    if (!@diffs && !$min) {
	# boring? then show at least the missing ones
	@diffs = `$utils_dir/cmp_ct_history.pl -missing @hist_dbs`;
    }
    my @wc = `wc -l @hist_dbs`;

    my $smoke_html = "$ctps_dir/$testlabel/smoke.html";

    for (@diffs) {
	s{^(.*)-(\S+)(.*)}{
	    my($name,$ver,$rest) = ($1, $2, $3);
	    my $qq = CGI->new({});
	    $qq->param("dist", $name.' '.$ver);
	    qq{<a href="http://matrix.cpantesters.org/?} . $qq->query_string . qq{">$name-$ver</a>} . escapeHTML($rest);
        }eg;
    }

    print header;
    print start_html(-title => "Parallel Smoker ($testlabel)", -style => {-code => style()});
    print "<b>Differences:</b> (new vs. old)<br>\n";
    print "<pre>", @diffs, "</pre>";
    print "<b>Checked distributions:</b><br>\n";
    print "<pre>", join("", map { escapeHTML($_) } @wc), "</pre>";
    if (-r $smoke_html) {
	my $qq = CGI->new();
	$qq->param("smoke", $testlabel);
	$qq->param("notes", 1);
	print qq{<a href="@{[ $qq->self_url ]}">Smoke notes</a>}
    }
    print end_html;
}

sub show_smoke_notes {
    my($smoke) = @_;
    my $found = _find_smoke($smoke);
    my $testlabel = $found->{testlabel};

    my $smoke_html = "$ctps_dir/$testlabel/smoke.html";

    print header;
    open my $ifh, $smoke_html or die $!;
    while(<$ifh>) {
	print $_;
    }
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

    my @possible_cols = ('testlabel', sort grep { $_ ne 'testlabel' } keys %possible_cols);

    my @matrix;
    for my $smoke (@smokes) {
	my @row;
	for my $key (@possible_cols) {
	    my $val = $smoke->{$key};
	    if (defined $val) {
		if (ref $val) {
		    no warnings 'once';
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
    print start_html(-title => 'Parallel Smoker', -style => {-code => my_style()});
    my $table = HTML::Table->new(-head    => [@possible_cols],
				 -spacing => 0,
				 -data    => \@matrix,
				 -class   => 'reports',
				);
    $table->setColHead(1);
    $table->print;
    print end_html;
}

sub my_style {
    <<EOF;
  table		  { border-collapse:collapse; }
  th,td           { border:1px solid black; }
  body		  { font-family:sans-serif; }

  .bt th,td	  { border:none; height:2.2ex; }

  .reports th	  { border:2px solid black; padding-left:3px; padding-right:3px; }
  .reports td	  { border:1px solid black; padding-left:3px; padding-right:3px; }

  .warn           { color:red; font-weight:bold; }
  .sml            { font-size: x-small; }
  .unimpt         { font-size: smaller; }
EOF
}

__END__

=pod

Possible configuration in Apache:

    ScriptAlias /parsmoker /home/e/eserte/src/perl/CPAN-Testers-ParallelSmoker/cgi-bin/par-smoker-status.cgi

=cut
