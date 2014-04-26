#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";

use Getopt::Long;
use CPAN::Testers::ParallelSmoker;

my $once;
my $doit = 1;
my $v;
GetOptions("once" => \$once,
	   "n" => sub { $doit = 0 },
	   "v" => \$v,
	  )
    or die "usage?";

my $smoke_config = shift
    or die "Please specify smoke config file";
load_config $smoke_config;
my $home = (getpwnam("cpansand"))[7]; # XXX hardcoding cpansand user here
set_home $home;
expand_config;

my($ctr_good_or_invalid_script) =
    grep { -x $_ } (
		    "$ENV{HOME}/src/srezic-misc/scripts/ctr_good_or_invalid.pl",
		    "$ENV{HOME}/work/srezic-misc/scripts/ctr_good_or_invalid.pl",
		    "$ENV{HOME}/work2/srezic-misc/scripts/ctr_good_or_invalid.pl",
		    "/home/e/eserte/work/srezic-misc/scripts/ctr_good_or_invalid.pl",
		    "/home/slavenr/work2/srezic-misc/scripts/ctr_good_or_invalid.pl",
		   );
die "Cannot find ctr_good_or_invalid.pl script"
    if !$ctr_good_or_invalid_script;

my($send_tr_reports_script) =
    grep { -x $_ } (
		    "$ENV{HOME}/src/srezic-misc/scripts/send_tr_reports.pl",
		    "$ENV{HOME}/work/srezic-misc/scripts/send_tr_reports.pl",
		    "$ENV{HOME}/work2/srezic-misc/scripts/send_tr_reports.pl",
		    "/home/e/eserte/work/srezic-misc/scripts/send_tr_reports.pl",
		    "/home/slavenr/work2/srezic-misc/scripts/send_tr_reports.pl",
		   );
die "Cannot find send_tr_reports.pl script"
    if !$send_tr_reports_script;

while() {
    warn "**** WORKING ****\n";
    sleep 1;
    for my $key ("perl1", "perl2") {
	{
	    my @cmd = ($^X, $ctr_good_or_invalid_script, "-good", "-nocheck-screensaver", "-noxterm-title",
		       $CONFIG->{$key}->{reportsdir});
	    unshift @cmd, "echo" if !$doit;
	    warn "  @cmd ...\n" if $v;
	    system @cmd;
	    ## No: a non-zero exit is normal!
	    #die "@cmd: $?" if $? != 0;
	}
	{
	    my @cmd = ($^X, $send_tr_reports_script,
		       $CONFIG->{$key}->{reportsdir});
	    unshift @cmd, "echo" if !$doit;
	    warn "  @cmd ...\n" if $v;
	    system @cmd;
	    die "@cmd: $?" if $? != 0;
	}
    }
    warn "**** FINISHED ****\n";
    for (reverse(1..60)) {
        printf STDERR "\rSleep %d second(s)... ", $_;
	sleep 1;
    }
    print STDERR "\n";
}
