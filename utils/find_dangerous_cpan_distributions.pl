#!/usr/bin/perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009,2014 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use CPAN::DistnameInfo;
use Getopt::Long;
use Parse::CPAN::Packages::Fast;
use CPAN::Version ();

my $packages_file;# = "/usr/local/src/CPAN/sources/modules/02packages.details.txt.gz";
my $do_report;
my $do_filter;
my $do_distropref;
GetOptions("packages=s" => \$packages_file,
	   "filter" => \$do_filter,
	   "report" => \$do_report,
	   "distropref" => \$do_distropref,
	  )
    or die "usage: $0 [-packages /path/to/02packages.details.txt.gz] [-filter] [-report]";

my %resolved = ('CGI'  => ['3.33', '3.34'], # https://rt.cpan.org/Ticket/Display.html?id=48425 (not dangerous)
		'Geo-Coder-US' => ['0.21'], # large changes in code base, removal of a module
		'XML-Compile-SOAP' => ['2.04', # XML::Compile::SOAP::Tester was removed afterwards
				       '0.78', # XML::Compile::WSDL11::Operation was removed afterwards
				      ],
		'perl' => 1, # CPAN.pm does not install perl anyway
	       );

my %seen_dist;

my %special_comparison =
    (
     'Gearman-XS' => sub {
	 # Gearman-XS-0.7 is probably older than 0.15
	 my($dist) = @_;
	 my @dists = sort {
	     if    ($a eq '0.7') { return +1 }
	     elsif ($b eq '0.7') { return -1 }
	     else {
		 CPAN::Version->vcmp($b, $a);
	     }
	 } keys %{ $seen_dist{$dist} };
     },
    );

for my $dist (keys %resolved) {
    if (ref $resolved{$dist}) {
	$resolved{$dist} = { map {($_,1)} @{ $resolved{$dist} } }; # create a set out of it
    }
}

my $pcp = Parse::CPAN::Packages::Fast->new($packages_file);
for my $p ($pcp->distributions) {
    my $dist = $p->dist;
    next if !defined $dist;
    my $version = $p->version; $version = '???' if !defined $version;

##XXX
#    # Is this already resolved?
#    my $val = $resolved{$dist};
#    if (defined $val) {
#	next if $val eq 1;
#	next if $val->{$version};
#    }

    $seen_dist{$dist}{$version} = $p->prefix;
}

my @problematic;
for my $dist (keys %seen_dist) {
    if (keys %{ $seen_dist{$dist} } > 1) {
	push @problematic, $dist;
    }
}

if ($do_filter || $do_distropref) {
    # The newest one is not problematic:
    for my $dist (@problematic) {
	my $newest;
	if (exists $special_comparison{$dist}) {
	    ($newest) = $special_comparison{$dist}->($dist);
	} else {
	    ($newest) = sort { CPAN::Version->vcmp($b, $a) } keys %{ $seen_dist{$dist} };
	}
	delete $seen_dist{$dist}->{$newest};
    }

    if ($do_distropref) {
	print <<EOF;
---
comment: dangerous CPAN distributions which may cause downgrades, automatically created by $0
disabled: 1
match:
  distribution: |-
    ^(?x:
EOF
	my @problematic_dist;
	for my $dist (@problematic) {
	    while(my($ver, $dist_ver) = each %{ $seen_dist{$dist} }) {
		# create short dist name
		$dist_ver =~ s{^./../}{};
		push @problematic_dist, $dist_ver;
	    }
	}
	@problematic_dist = sort @problematic_dist;
	my $first = shift @problematic_dist;
	print "      \\Q$first\\E\n";
	for my $problematic_dist (@problematic_dist) {
	    print "     |\\Q$problematic_dist\\E\n";
	}
	print "    )\$\n";
    } else {
	my %problematic_dist;
	for my $dist (@problematic) {
	    for (values %{ $seen_dist{$dist} }) {
		$problematic_dist{$_} = 1;
	    }
	}

	while(<>) {
	    chomp;
	    my $in_dist = $_;
	    my $long_dist = $in_dist;
	    my $cdi = CPAN::DistnameInfo->new($in_dist);
	    if (!(my $cpanid = $cdi->cpanid)) {
		# probably short dist name, try to create long one...
		if (my($author,$filename) = $in_dist =~ m{^([^/]+)/(.*)$}) {
		    $long_dist = substr($author,0,1)."/".substr($author,0,2)."/".$author."/".$filename;
		    $cdi = CPAN::DistnameInfo->new($long_dist);
		    if (!($cpanid = $cdi->cpanid)) {
			warn "Cannot parse '$in_dist' nor '$long_dist', skipping...\n";
			next;
		    }
		} else {
		    warn "Cannot parse '$in_dist' (probably author is missing?), skipping...\n";
		}
	    }
	    if ($problematic_dist{$long_dist}) {
		warn "Skipping dangerous distribution '$in_dist'...\n";
	    } else {
		print $in_dist, "\n";
	    }
	}
    }
} elsif ($do_report) {
    for my $dist (@problematic) {
	print "$dist\t" . join(", ", sort keys %{ $seen_dist{$dist} }) . "\n";
    }
} else {
    for my $dist (@problematic) {
	print join("\n", values %{ $seen_dist{$dist} }) . "\n";
    }
}

__END__
