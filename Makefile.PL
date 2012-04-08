# -*- cperl -*-

use 5.006;
use ExtUtils::MakeMaker;
WriteMakefile
    (
     NAME         => 'CPAN::Testers::ParallelSmoker',
     VERSION_FROM => 'lib/CPAN/Testers/ParallelSmoker.pm',
     PREREQ_PM    =>
     {
      'Slay::Makefile' => 0,
      # for cpan_smoke_modules
      'BSD::Resource' => 0,
      'CPAN::DistnameInfo' => 0,
      'File::ReadBackwards' => 0,
      'Filesys::DfPortable' => 0,
      'LWP::UserAgent' => 0,
      'PerlIO::gzip' => 0,
      'YAML' => 0,
      'YAML::Syck' => 0,
      ($^O eq 'MSWin32' ? ('Win32::Process' => 0) : ()),
      # for find_dependants
      'CPANDB' => 0,
      # optional for comparing reports
      'Text::WordDiff' => 0,
      # for create_modlist_by_years
      'Parse::CPAN::Packages::Fast' => 0,
     }
    );
