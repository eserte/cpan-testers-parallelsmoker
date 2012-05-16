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

package CPAN::Testers::ParallelSmoker;

use strict;
our $VERSION = '0.01';

use Exporter 'import';

our($CONFIG, $OPTIONS, $HOME);

our @EXPORT = qw(load_config expand_config set_home $CONFIG $OPTIONS);

use Cwd qw(realpath);
use File::Basename qw(basename);
use Hash::Util qw();
use YAML::Syck qw(LoadFile);

sub load_config ($) {
    my $config_file = shift;
    $CONFIG = (LoadFile $config_file)->{smoke};
    $CONFIG->{configfile} = realpath $config_file;
    $CONFIG;
}

sub set_home ($) {
    $HOME = shift;
}

sub expand_config () {
    set_home $ENV{HOME} if !defined $HOME;
    die "Config not available, maybe you have to call load_config first?" if !$CONFIG;
    if (!$CONFIG->{testlabel}) {
	if (!$CONFIG->{configfile}) {
	    die "testlabel is missing and cannot be deduced from configfile";
	}
	my $configbase = basename $CONFIG->{configfile};
	if ($configbase !~ m{^smoke_(.+)\.ya?ml$}) {
	    die 'Config filename does not match /smoke_.*\.ya?ml/, cannot deduce testlabel from it. Please set testlabel explicitely.';
	}
	$CONFIG->{testlabel} = $1;
    }
    $CONFIG->{testlabel} =~ m{^[a-zA-Z0-9_.-]+$} or die "Illegal letters found in testlabel, try alphanumerics and . - _";

    $CONFIG->{smokerdir} = "$HOME/var/ctps/$CONFIG->{testlabel}";
    $CONFIG->{downloaddir} = "$HOME/var/ctps/downloads";

    $OPTIONS = $CONFIG->{options}; # separate, to not be subject of lock_hash

    for my $key (qw(perl1 perl2)) {
	if (!$CONFIG->{$key}->{url}) {
	    if ($CONFIG->{$key}->{version}) {
		my $ver = $CONFIG->{$key}->{version};
		my $url = "http://www.cpan.org/src/5.0/perl-$ver.tar.bz2";
		$CONFIG->{$key}->{url} = $url;
	    } elsif ($CONFIG->{$key}->{commit}) {
		if (!$CONFIG->{git_repository}) { # XXX consider to use perl's default repo
		    die "Must specify 'git_repository' in config when using 'commit'";
		}
	    } else {
		die "Must specify either url or version or commit for every perl";
	    }
	}
	if ($CONFIG->{$key}->{url}) {
	    my $base = basename $CONFIG->{$key}->{url};
	    $CONFIG->{$key}->{base} = $base;
	    $CONFIG->{$key}->{downloadfile} = $CONFIG->{downloaddir} . '/' . $base;
	    (my $base_without_ext = $base) =~ s{\.tar\.(bz2|gz)$}{};
	    $CONFIG->{$key}->{base_without_ext} = $base_without_ext;
	} else {
	    $CONFIG->{$key}->{base_without_ext} = "perl-" . $CONFIG->{$key}->{commit};
	}
    }
    if ($CONFIG->{perl1}->{base_without_ext} eq $CONFIG->{perl2}->{base_without_ext}) {
	# same perl, so need to add a suffix
	for my $def (['perl1', '1'], ['perl2', '2']) {
	    my($key, $suffix) = @$def;
	    my $base = $CONFIG->{$key}->{base_without_ext} . "-" . $suffix;
	    $CONFIG->{$key}->{builddir} = $CONFIG->{smokerdir} . '/src/' . $base;
	    $CONFIG->{$key}->{installdir} = $CONFIG->{smokerdir} . '/install/' . $base;
	    $CONFIG->{$key}->{configdir} = $CONFIG->{smokerdir} . '/config/' . $base;
	    $CONFIG->{$key}->{reportsdir} = $CONFIG->{smokerdir} . '/reports/' . $base;
	}
    } else {
	for my $key (qw(perl1 perl2)) {
	    $CONFIG->{$key}->{builddir} = $CONFIG->{smokerdir} . '/src/' . $CONFIG->{$key}->{base_without_ext};
	    $CONFIG->{$key}->{installdir} = $CONFIG->{smokerdir} . '/install/' . $CONFIG->{$key}->{base_without_ext};
	    $CONFIG->{$key}->{configdir} = $CONFIG->{smokerdir} . '/config/' . $CONFIG->{$key}->{base_without_ext};
	    $CONFIG->{$key}->{reportsdir} = $CONFIG->{smokerdir} . '/reports/' . $CONFIG->{$key}->{base_without_ext};
	}
    }

    for my $key (qw(perl1 perl2)) {
	for my $def (['edit_report', 'default:no'],
		     ['email_from',  $ENV{EMAIL}],
		     ['send_report', 'default:yes'],
		     ['transport',   "File " . $CONFIG->{$key}->{reportsdir}],
		    ) {
	    my($cr_key, $cr_def_val) = @$def;
	    if (!exists $CONFIG->{cpanreporter}->{$cr_key}) {
		$CONFIG->{$key}->{cpanreporter}->{$cr_key} = $cr_def_val;
	    } else {
		$CONFIG->{$key}->{cpanreporter}->{$cr_key} = $CONFIG->{cpanreporter}->{$cr_key};
	    }
	}
    }

    $CONFIG->{want_mod_comparison} = (exists $CONFIG->{mod1} || exists $CONFIG->{mod2});
    $CONFIG->{run_in} ||= 'xterm';
    for my $key (qw(perl1 perl2)) {
	$CONFIG->{$key}->{extract_from_git} = $CONFIG->{$key}->{commit};
    }
    $CONFIG->{modlist}->{dependants} ||= undef;
    $CONFIG->{modlist}->{file}       ||= undef;
    $CONFIG->{modlist}->{command}    ||= undef;

    {
	local $SIG{__WARN__} = sub {}; # lock_hashref_recurse is noisy
	Hash::Util::lock_hashref_recurse($CONFIG);
    }
}

1;

__END__

=head1 NAME

CPAN::Testers::ParallelSmoker

=head1 SYNOPSIS

XXX:
  ctps-build-perls
  ctps-setup-smoker
  ctps-make-distlist
  ...

=head1 WORKFLOW

=over

=item * Build two perls

This is typically the same perl version and configuration in two
separate installations paths, or two different perls (i.e. different
version, different configuration).

XXX If it's the same perl version and configuration: safe some build
time by creating a relocatable perl and just clone the first
installation (available from perl 5.8.9 and 5.9.4)?

XXX We can probably skip perl testing. Or maybe run the tests in
background with very low priority while the smoker already runs.

Existing tools: Perl's C<Configure> or C<configure.gnu>, my private
C<~/FreeBSD/build/perl>.

=item * Setup smoke environment

This involves installing all modules needed for cpan testing, i.e.
L<CPAN::Reporter> and useful modules like L<Expect>, L<YAML> and such.
(XXX when working with relocatable perls, then this step could
theoretically be done before cloning the perl installation). Create
.cpanreporter directory with config.ini file. CPAN::Reporter is setup
to not send reports, but to store them for later use (but sending is
possible nevertheless). Possibly setup .cpan/prefs directory.

Existing tools: C<CPAN.pm>, my private
C<~eserte/work/srezic-misc/scripts/cpan_smoke_modules> with a
hardcoded list of modules.

Creation of configuration files is currently done manually.

=item * Preparing module to test

This step is only needed if testing two different module versions:
install the old version in the first perl installation and the new
version in the second perl installation. Make sure that updating this
module is forbidden, i.e. by creating a dynamic distroprefs file.

=item * Create list of CPAN distributions to test against

Depending on the task a different set of CPAN distributions needs to
be created which is then used for testing. In any case, the list
should be checked and reduced by "dangerous" CPAN distributions, i.e.
distributions in the modules index which would overwrite a newer
version of a module (this usually happens if a helper module is
removed from a distribution).

Existing tool finding "dangerous" distributions: private
C<find_dangerous_cpan_distributions.pl>.

=over

=item * For smoke-testing different Perl versions or configurations this
could be the list of all CPAN distributions, possibly restricted to
just newer ones (filter by release date), or maybe to the list of CPAN
distributions which had a good likelihood to pass on this system (i.e.
by examing old CPAN::Reporter history files).

Existing tools: some smart grep over
C<~/.cpanreporter/reports-sent.db>, private C<cpan_allpackages>.

=item * For testing different versions of build tools (i.e.
ExtUtils::MakeMaker, Module::Build) some heuristic is needed to find
the EUMM or MB based distributions (for example by examing the
contents of the distributions and looking for the existance of
Build.PL).

Existing tools: private C<cpandisthasfile.pl>.

=item * For testing different versions of any modules find the modules
depending on the modules to test.

Existing tools: cpants (but is down for a long time), L<CPANDB>.
Former art: L<Test::DependentModules>.

=back

=item * Start smoking

Prepare everything so two smokers may run in two terminals. Make it
possible to kill hanging distributions, and make it possible to
restart smoking. It may be advisable that both smokers does not run
exactly at the same time, because there are test suites working with
hardcoded socket ports, so one of both would win and the other fail.
There could also be other resource clashes (i.e. hardcoded path names
for temporary files). On the other hand, the smokers should not be too
far away, so e.g. temporary failures in internet connections affect
both smokers.

XXX install or not install (install mandatory for EUMM/MB tests)

Existing tools: C<cpan_smoke_modules>, C<CPAN::Reporter>+C<CPAN> with
a custom list, maybe also C<CPAN::Reporter::Smoker> (but I think it
cannot handle a distribution list, but this could be faked with some
kind of distroprefs file).

=item * Comparison reports

Comparison reports may be built already while the smokers are running.
They are available as plain text and as HTML file, with links to the
single reports and to useful sites like RT, search.cpan.org,
matrix.cpantesters.org.

Possible comparison types:

=over 

=item * PASS/FAIL comparisons

Find regresssions.

Existing tools: private C<cmp_ct_history.pl>

=item * Equivalent installations

Are installed files the same?

Existing tools: some mtree mechanism with exclusion lists.

=item * Benchmarking

Parse wallclock/CPU time out of test reports and compare.

=back

=back

=head1 CONFIGURATION and WORKFLOW KNOWLEDGE

Configuration:

 * root directories of both perls
 * paths to both perl binaries (usually $perlroot/bin/perl$perlversion, with or without $perlversion)
 * paths to both .cpanreporter directories (with CPAN::Reporter configuration)
 * paths to both directories containing the created reports (with done/sync/... subdirectories)
 * paths to both directories containing cpan distroprefs

Workflow knowledge:

 * completed step in the workflow
 * steps to be done
 * completed "sub-steps" (i.e. last successfully checked distribution)

=head1 HINTS

Force some failing key modules to install, or use a working devel
version instead. E.g. old Tk (devel version usually works) or Gtk2
(has often just one failing test).

Don't forget to clean /tmp and /var directories before starting the
smoker.

Generate a complete list of current CPAN distro with the pass/fail
status in the smoker run:

    cd .../var/ctps/<testlabel>
    ~eserte/work/srezic-misc/scripts/cpan_allpackages -perl install/perl-5.10.1-1/bin/perl > tested-perl-5.10.1-1
    # same with the other perl

The complete smoke directory (including both perls, ~16000 installed
distributions, configuration, and the test reports) takes about ...

=head1 TODO

 * optionally start Xnest or Xvfb for GUI testing (see multiperltest)

=head1 AUTHOR

Slaven ReziE<0x107>, E<lt>srezic@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Slaven ReziE<0x107>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

=cut
