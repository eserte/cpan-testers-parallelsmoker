#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";

use Getopt::Long;

use CPAN::Testers::ParallelSmoker;

my $smoke_config_file;
GetOptions("config=s" => \$smoke_config_file)
    or die "usage?";

CPAN::Testers::ParallelSmoker::load_config($smoke_config_file);
CPAN::Testers::ParallelSmoker::set_home((getpwnam("cpansand"))[7]); # XXX do not hardcode!
CPAN::Testers::ParallelSmoker::expand_config();

my $reportsdir = $CPAN::Testers::ParallelSmoker::CONFIG->{perl2}->{reportsdir};
while(<>) {
    chomp;
    s{^\s*(\S+).*}{$1};
    my($file) = glob("$reportsdir/*/{fail,pass,unknown,na}.$_.*");
    if (!$file) {
	warn "Can't find a report for $file\n";
    } else {
	print $file, "\n";
    }
}

__END__
