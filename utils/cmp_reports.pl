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
use File::Basename qw(basename);
use File::Compare qw(compare);
use File::Temp qw(tempfile);
use Getopt::Long;

my $diffprog = "diff";
GetOptions("diff=s" => \$diffprog)
    or die "usage?";

my $report_file_or_dir1 = shift or die;
my $report_file_or_dir2 = shift or die;

if (-d $report_file_or_dir1) {
    my %reports1 = find_reports($report_file_or_dir1);
    my %reports2 = find_reports($report_file_or_dir2);
    for my $key (sort keys %reports1) {
	if (exists $reports2{$key}) {
	    print "*** $key\n";
	    diff_reports($reports1{$key}, $reports2{$key});
	} else {
	    print "*** No report for $key in directory $report_file_or_dir2\n";
	}
	delete $reports2{$key};
    }
    for my $key (sort keys %reports2) {
	print "*** No report for $key in directory $report_file_or_dir1\n";
    }
} else {
    diff_reports($report_file_or_dir1, $report_file_or_dir2);
}

sub find_reports {
    my $dir = shift;
    my @reports = glob("$dir/*.rpt");
    map {
	my $dist = basename $_;
	$dist =~ s{^[^\.]+\.}{};
	$dist =~ s{\.\d+\.\d+\.rpt$}{};
	($dist => $_);
    } @reports;
}

sub diff_reports {
    my($report_file1, $report_file2) = @_;

    my $report1;
    my $report2;
    for my $def ([$report_file1, \$report1],
		 [$report_file2, \$report2],
		) {
	my($file, $stringref) = @$def;
	open my $fh, $file or die "Can't open $file: $!";
	use constant STAGE_BEFORE_PROG_OUTPUT => 0;
	use constant STAGE_IN_PROG_OUTPUT => 1;
	my $stage = STAGE_BEFORE_PROG_OUTPUT;
	while (<$fh>) {
	    if ($stage == STAGE_BEFORE_PROG_OUTPUT) {
		if (/^PROGRAM OUTPUT/) {
		    $stage = STAGE_IN_PROG_OUTPUT;
		}
	    } elsif ($stage == STAGE_IN_PROG_OUTPUT) {
		$$stringref .= $_;
		if (/^PREREQUISITES/) {
		    last;
		}
	    }
	}

	# perl path names
	$$stringref =~ s{/perl-5[^/]+/}{/\$PERLDIR/}g;
	$$stringref =~ s{/5\.\d+\.\d+/}{/\$PERLVERSION/}g;
	$$stringref =~ s{\@INC contains:.* at .* line \d+}{}g;

	# CPAN.pm path names
	$$stringref =~ s{/\.cpan/build/[^/]+/}{\$CPANBUILD}g; # XXX must not be in .cpan!

        # different times
	$$stringref =~ s{Current time (local|GMT): .*}{}g;

        # different durations
	$$stringref =~ s{.*\d+ wallclock secs.*CPU.*}{};
    }

    my($tmp1fh,$tmp1file) = tempfile(UNLINK => 1, SUFFIX => 'report1.txt') or die $!;
    print $tmp1fh $report1;
    close $tmp1fh or die $!;

    my($tmp2fh,$tmp2file) = tempfile(UNLINK => 1, SUFFIX => 'report2.txt') or die $!;
    print $tmp2fh $report2;
    close $tmp2fh or die $!;

    if (compare($tmp1file, $tmp2file) != 0) {
	if ($diffprog eq 'Text::WordDiff') {
	    require Text::WordDiff;
	    my $diff = Text::WordDiff::word_diff($tmp1file, $tmp2file);
	    print $diff;
	} else {
	    my @cmd = ($diffprog, "-u", $tmp1file, $tmp2file);
	    system(@cmd);
	}
    }
}
