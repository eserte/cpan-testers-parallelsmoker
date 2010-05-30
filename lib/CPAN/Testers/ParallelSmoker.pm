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
