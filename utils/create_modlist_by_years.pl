#!/usr/bin/perl -w

use strict;
use File::Temp qw(tempfile);
use Getopt::Long;
use List::Util qw(first);
use Parse::CPAN::Packages::Fast;

my($cpan_allpackages_script) =
    grep { -x $_ } ("$ENV{HOME}/work/srezic-misc/scripts/cpan_allpackages",
		    "$ENV{HOME}/work2/srezic-misc/scripts/cpan_allpackages",
		    "/home/e/eserte/work/srezic-misc/scripts/cpan_allpackages",
		    "/home/slavenr/work2/srezic-misc/scripts/cpan_allpackages",
		   );
die "Cannot find cpan_allpackages script" if !$cpan_allpackages_script;

my($find_dangerous_cpan_distributions_script) =
    grep { -x $_ } ("$ENV{HOME}/devel/find_dangerous_cpan_distributions.pl",
		    "$ENV{HOME}/devel-biokovo/find_dangerous_cpan_distributions.pl",
		    "$ENV{HOME}/devel-biokovo.git/find_dangerous_cpan_distributions.pl",
		    "/home/e/eserte/devel/find_dangerous_cpan_distributions.pl",
		    "/home/slavenr/devel-biokovo/find_dangerous_cpan_distributions.pl",
		    "/home/slavenr/devel-biokovo.git/find_dangerous_cpan_distributions.pl",
		   );
die "Cannot find find_dangerous_cpan_distributions.pl" if !$find_dangerous_cpan_distributions_script;

my $perl;
my $years_range;
GetOptions("perl=s" => \$perl,
	   "years=s" => \$years_range,
	  ) or die "usage?";
sub usage_years_range () { die "Please specify years range in the form YYYY..YYYY or YYYY.." }
$years_range or usage_years_range;
$perl or die "Please specify -perl /path/to/perl";

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
my $years_rx = '(' . join("|", map { quotemeta } $year_from..$year_to) . ')';
$years_rx = qr{$years_rx};

my $pf = Parse::CPAN::Packages::Fast->new;

warn "Find list of already tested distributions for this perl...\n";
my $tested_list;
{
    my $tmpfh;
    ($tmpfh,$tested_list) = tempfile(SUFFIX => '_tested_list', UNLINK => 1)
	or die $!;
    my @cmd = ($^X, $cpan_allpackages_script, "-perl", $perl);
    warn "  @cmd ...\n";
    open my $fh, "-|", @cmd
	or die "@cmd: $!";
    while(<$fh>) {
	print $tmpfh $_;
    }
    close $tmpfh
	or die $!;
    close $fh
	or die "@cmd: $!";
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
    my @date_dists;
    open my $ifh, $tested_list
	or die $!;
    while(<$ifh>) {
	next if /^\?/;
	next if /(FAIL|DISCARD|UNKNOWN)/;
	next if $_ !~ $years_rx;
	chomp;
	push @date_dists, $_;
    }
    close $ifh
	or die $!;

    my %seen;
    @date_dists = sort @date_dists; # sort by date
    for my $date_dist (@date_dists) {
	my(@fields) = split /\s+/, $date_dist;
	my $dist = $fields[1];
	next if $dangerous{$dist};
	if ($dist =~ m{^(.)(.)}) {
	    $dist = "$1/$1$2/$dist";
	    if (my $dist_o = eval { $pf->distribution($dist) }) {
		my $first_p = ($dist_o->contains)[0]->package;
		if (!$seen{$first_p}++) {
		    print $first_p, "\n";
		}
	    }
	}
    }
}
