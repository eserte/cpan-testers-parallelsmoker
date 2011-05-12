#!/bin/sh

set -e
set -x

perl5.12.3 ./utils/create_modlist_by_years.pl -years 2005..2011 -perl /usr/perl5.12.3/bin/perl -perl ~cpansand/var/ctps/2pre5140/install/perl-5.12.3/bin/perl |\
    grep -v '^Bundle::' |\
    grep -v '^Task::' |\
    grep -v '^MM$' > /tmp/2005-2011.modlist3~
cat <<EOF >> /tmp/2005-2011.modlist3~
Apache::Session::Counted
Astro::Sunrise
Chart::ThreeD::Pie
GD::SVG
List::Permutor
Tk::ExecuteCommand
EOF
chmod ugo+r /tmp/2005-2011.modlist3~
mv /tmp/2005-2011.modlist3~ /tmp/2005-2011.modlist3
cat /tmp/2005-2011.modlist3
