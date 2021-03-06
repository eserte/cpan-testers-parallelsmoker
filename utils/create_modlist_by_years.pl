#!/usr/bin/perl -w

use strict;
use FindBin;
use File::Temp qw(tempfile);
use Getopt::Long;
use List::Util qw(first);
use Parse::CPAN::Packages::Fast;
use Tie::IxHash;

my($cpan_allpackages_script) = "$FindBin::RealBin/cpan_allpackages";
die "Cannot find cpan_allpackages script" if !-x $cpan_allpackages_script;

my($find_dangerous_cpan_distributions_script) = "$FindBin::RealBin/find_dangerous_cpan_distributions.pl";
die "Cannot find find_dangerous_cpan_distributions.pl" if !-x $find_dangerous_cpan_distributions_script;

my @perls;
my $years_range_in;
my $output_dists;
GetOptions('perl=s@' => \@perls,
	   "years=s" => \$years_range_in,
	   'dists'   => \$output_dists,
	  ) or die "usage: $0 [-dists] -perl /path/to/perl [-perl ...] -years YYYY.. | -years YYYY..YYYY\n";
sub usage_years_range () { die "Please specify years range in the form -years YYYY..YYYY or -years YYYY.." }
$years_range_in or usage_years_range;
@perls or die "Please specify -perl /path/to/perl";

my $years_rx;
{
    my @years_ranges = split /,/, $years_range_in;
    my %years;
    for my $years_range (@years_ranges) {
	my($year_from, $year_to);
	if ($years_range =~ m{^(\d{4})\.\.(\d{4})$}) {
	    ($year_from, $year_to) = ($1, $2);
	} elsif ($years_range =~ m{(\d{4})\.\.$}) {
	    $year_from = $1;
	    $year_to = ((localtime)[5]) + 1900;
	} else {
	    usage_years_range;
	}
	if ($year_from > $year_to) {
	    die "years_from must be smaller or equal years_to";
	}
	for my $year ($year_from .. $year_to) {
	    $years{$year} = 1;
	}
    }
    if (!keys %years) {
	usage_years_range;
    }
    $years_rx = '(' . join("|", map { quotemeta } keys %years) . ')';
    $years_rx = qr{$years_rx};
}

my $pf = Parse::CPAN::Packages::Fast->new;

warn "Find list of already tested distributions for " . (@perls == 1 ? "this perl" : "these perls") . "...\n";
my $tested_list;
{
    my $tmpfh;
    ($tmpfh,$tested_list) = tempfile(SUFFIX => '_tested_list', UNLINK => 0)
	or die $!;
    for my $perl (@perls) {
	my @cmd = ($^X, $cpan_allpackages_script, "-perl", $perl);
	warn "  @cmd ...\n";
	open my $fh, "-|", @cmd
	    or die "@cmd: $!";
	while(<$fh>) {
	    print $tmpfh $_;
	}
	close $fh
	    or die "@cmd: $!";
    }
    close $tmpfh
	or die $!;
}

warn "Find dangerous cpan distributions...\n";
my %dangerous;
{
    my @cmd = ($^X, $find_dangerous_cpan_distributions_script);
    warn "  @cmd ...\n";
    open my $fh, "-|", @cmd
	or die "@cmd: $!";
    while(<$fh>) {
	s{^./../}{};
	chomp;
	$dangerous{$_} = 1;
    }
    close $fh
	or die "@cmd: $!";
}

warn "Various filters (FAIL, year, dangerous...)...\n";
{
    my %fail_dist;
    tie my %date_dists, 'Tie::IxHash';
    open my $ifh, $tested_list
	or die $!;
    while(<$ifh>) {
	next if /^\?/;
	chomp;
	my @f = split /\s+/, $_, 3;
	next if !defined $f[1];
	next if $fail_dist{$f[1]};
	if ($f[2] =~ /(FAIL|DISCARD|UNKNOWN)/) {
	    delete $date_dists{$f[1]};
	    $fail_dist{$f[1]} = 1;
	    next;
	}
	next if $f[0] !~ $years_rx;
	$date_dists{$f[1]} = [@f];
    }
    close $ifh
	or die $!;

    my %seen; # package or distribution
    for my $date_dist (sort { $b->[0] cmp $a->[0] } values %date_dists) {# sort by date, newest first
	my(@fields) = @$date_dist;
	my $dist = $fields[1];
	next if $dangerous{$dist};
	if ($dist =~ m{^(.)(.)}) {
	    $dist = "$1/$1$2/$dist";
	    if (my $dist_o = eval { $pf->distribution($dist) }) {
		if ($output_dists) {
		    my $distname = $dist_o->cpanid . '/' . $dist_o->filename;
		    if (!$seen{$distname}++) {
			print $distname, "\n";
		    }
		} else {
		    # Translate distname into the best module name
		    my $primary_package;

		    my $maybe_primary_package = $dist_o->dist;
		    $maybe_primary_package =~ s{-}{::}g; # e.g. ExtUtils-MakeMaker -> ExtUtils::MakeMaker

		    my @packages;
		    for my $contains ($dist_o->contains) {
			my $package = $contains->package;
			if ($package eq $maybe_primary_package) {
			    $primary_package = $package;
			    last;
			}
			push @packages, $package;
		    }

		    if (!defined $primary_package) {
			# find shortest module here
			# XXX Bundles should get a lower priority XXX
			@packages = sort { length($a) <=> length($b) } @packages;
			$primary_package = $packages[0];
		    }

		    if (!$seen{$primary_package}++) {
			print $primary_package, "\n";
		    }
		}
	    }
	}
    }
}
