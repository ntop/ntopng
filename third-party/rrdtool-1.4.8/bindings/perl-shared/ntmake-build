use ExtUtils::MakeMaker;
use Config;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
# Run VCVARS32.BAT before generating makefile/compiling.
WriteMakefile(
    'NAME'	=> 'RRDs',
    'VERSION_FROM' => 'RRDs.pm',
#    'DEFINE'	   => "-DPERLPATCHLEVEL=$Config{PATCHLEVEL}",
# keep compatible w/ ActiveState 5xx builds
    'DEFINE'	   => "-DPERLPATCHLEVEL=5",

   'INC'	=> '-I../../src/ "-I/Program Files/GnuWin32/include"',
# Since we are now using GnuWin32 libraries dynamically (instead of static
# complile with code redistributed with rrdtool), use /MD instead of /MT.
# Yes, this means we need msvcrt.dll but GnuWin32 dlls already require it
# and it is available on most versions of Windows.
   'OPTIMIZE' => '-O2 -MD',
   'LIBS'  => '../../src/release/rrd.lib "/Program Files/GnuWin32/lib/libart_lgpl.lib" "/Program Files/GnuWin32/lib/libz.lib" "/Program Files/GnuWin32/lib/libpng.lib" "/Program Files/GnuWin32/lib/libfreetype.lib"', 
    'realclean'    => {FILES => 't/demo?.rrd t/demo?.png' },
    ($] ge '5.005') ? (
        'AUTHOR' => 'Tobias Oetiker (tobi@oetiker.ch)',
        'ABSTRACT' => 'Round Robin Database Tool',
    ) : ()


);
