use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'         => 'RRDp',
    'VERSION'      => '0.99.0', # finds $VERSION
    'linkext'   => {LINKTYPE => ''},
    'dist'    =>    {COMPRESS=>'gzip', SUFFIX=>'gz'},
);
