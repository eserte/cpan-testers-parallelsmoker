#!/usr/bin/perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
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

my $packages_file;# = "/usr/local/src/CPAN/sources/modules/02packages.details.txt.gz";
my $do_report;
GetOptions("packages=s" => \$packages_file)
    or die "usage: $0 [-packages /path/to/02packages.details.txt.gz] [-report]";

my %resolved = ('CGI'  => ['3.33', '3.34'], # https://rt.cpan.org/Ticket/Display.html?id=48425 (not dangerous)
		'Geo-Coder-US' => ['0.21'], # large changes in code base, removal of a module
		'XML-Compile-SOAP' => ['2.04', # XML::Compile::SOAP::Tester was removed afterwards
				       '0.78', # XML::Compile::WSDL11::Operation was removed afterwards
				      ],
		'perl' => 1, # CPAN.pm does not install perl anyway
	       );
for my $dist (keys %resolved) {
    if (ref $resolved{$dist}) {
	$resolved{$dist} = { map {($_,1)} @{ $resolved{$dist} } }; # create a set out of it
    }
}

my %seen_dist;

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

if ($do_report) {
    for my $dist (@problematic) {
	print "$dist\t" . join(", ", sort keys %{ $seen_dist{$dist} }) . "\n";
    }
} else {
    for my $dist (@problematic) {
	print join("\n", values %{ $seen_dist{$dist} }) . "\n";
    }
}

__END__
