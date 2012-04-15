#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Parse::CPAN::Packages::Fast;

my $p = Parse::CPAN::Packages::Fast->new;

if (@ARGV) {
    for (@ARGV) {
	resolve_distname($_);
    }
} else {
    print STDERR "Reading from STDIN...\n";
    while(<>) {
	chomp;
	my $distname = $_;
	resolve_distname($distname);
    }
}

sub resolve_distname {
    my $distname = shift;
    my $d = $p->latest_distribution($distname);
    if (!$d) {
	# strip version?
	(my $try_distname = $distname) =~ s{-v?\d.*}{};
	$d = $p->latest_distribution($try_distname);
    }
    if (!$d) {
	print "# missing: $distname\n";
    } else {
	my($mod) = sort { length $a <=> length $b } $d->contains;
	print $mod->package, "\n";
    }
}

__END__

=head1 NAME

cpan_dist_to_mod.pl - map distribution to module

=head1 SYNOPSIS

    ./cpan_dist_to_mod.pl Dist-Name-A Dist-Name-B-1.23 ...

=head1 DESCRIPTION

Return for every given CPAN distribution name a module member, usually
the one with the shortest name.

Input parameters may be distribution names with or without version
number, without the author part or any file suffix.

=cut

