#!/usr/bin/env perl
# -*- cperl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use CPANDB;

my $distname = shift or die "distname?";
my $dist = CPANDB->distribution($distname);
die "Cannot find $distname as dist" if !$dist;

my @dependants = dependants($dist);
print join("\n", @dependants), "\n";

# Took from CPANDB::Distribution::_dependants
sub dependants {
    my $dist     = shift;
    my %param    = @_;
    my $class    = delete $param{_class};
    my $phase    = delete $param{phase};
    my $perl     = delete $param{perl};

    my $sql_where = 'where dependency = ?';
    my @sql_param = ();
    if ( $phase ) {
	$sql_where .= ' and phase = ?';
	push @sql_param, $phase;
    }
    if ( $perl ) {
	$sql_where .= ' and ( core is null or core >= ? )';
	push @sql_param, $perl;
    }

    # Fill the graph via simple list recursion
    my @todo = ( $dist->distribution );
    my %seen = ( $dist->distribution => 1 );
    while ( @todo ) {
	my $name = shift @todo;
	next if $name =~ /^Task-/; # XXX why?
	next if $name =~ /^Acme-Mom/;

	# Find the distinct dependencies for this node
	my @deps = map {
	    $_->distribution
	} CPANDB::Dependency->select(
				     $sql_where, $name, @sql_param,
				    );
	
	# Push the new ones to the list
	push @todo, grep { not $seen{$_}++ } @deps;
    }

    delete $seen{$dist->distribution};

    my @dist;
    for my $dist (keys %seen) {
	push @dist, CPANDB->distribution($dist)->release;
    }
    @dist;
}
