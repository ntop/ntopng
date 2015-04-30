#!/usr/bin/perl

=head1 NAME

rrdcached-size.pl - estimate the IO and memory requirements for rrdcached

=head1 SYNOPSIS

B<rrdcached-size.pl>
[B<-rrds>E<nbsp>I<file_count>]
[B<-step>E<nbsp>I<seconds>]
[B<-update>E<nbsp>I<length>]
[B<-file>E<nbsp>I<length>]
[B<-io>E<nbsp>I<files/sec>]
[B<-w>E<nbsp>I<seconds>]
[B<-f>E<nbsp>I<seconds>]
[B<-pagesize>E<nbsp>I<bytes>]

=head1 OPTIONS

=over 4

=item B<-rrds> I<file_count>

Specify the number of RRDs in the working set.

=item B<-step> I<seconds>

Specify the RRD step value for each file.

=item B<-update> I<length>

Average update string length.  For this calculation, the time value must
be specified as a C<time_t>, not C<N>.  For example, this update string
would lead to B<-update>E<nbsp>I<43> :

  1226936851:0:0:101113914:0:0:0:25814373:0:0

=item B<-file> I<length>

Specify the average file name length.  For this calculation, use the full
path of the file.

=item B<-io> I<files/sec>

Specify the number of RRD files that your system can write per second.

=item B<-w> I<timer>

Specifies the B<-w> timer used with rrdcached.  For more information, see
the B<rrdcached> documentation.

=item B<-f> I<timer>

Specifies the B<-f> timer used with rrdcached.  For more information, see
the B<rrdcached> documentation.

=item B<-pagesize> I<bytes>

Manually specify the system page size, in case it is not detected
properly.

=back

=cut

use strict;
use warnings;

my $filename_len = 60;
my $update_len = 128;
my $rrds = 100;
my $step = 300;
my $rrd_per_sec = 200;
my $rrdc_write = 300;
my $rrdc_flush = 3600;
my $pagesize = `pagesize` || 4096;

#################################################################

use Getopt::Long;
GetOptions('rrds=i' => \$rrds,
           'step=i' => \$step,
           'update=i' => \$update_len,
           'file=i' => \$filename_len,
           'io=i' => \$rrd_per_sec,
           'w=i'    => \$rrdc_write,
           'f=i'    => \$rrdc_flush,
           'pagesize=i' => \$pagesize,
           'h' => \&usage,
           )
    or die "Options failure";

@ARGV and die "Extra args: @ARGV\n";

#################################################################

my $MEG = 1024*1024;

my $write_time = int($rrds / $rrd_per_sec);
my $write_busy = int(100 * $write_time / $rrdc_write);
my $buffered_pdp = $rrdc_write / $step;

my $max_ram
    = $rrds
    * ($filename_len
           + ( $rrdc_write / $step ) * $update_len)
    / $MEG;

my $journal_size
    = $rrds
    * (length("update") + $filename_len + $update_len + 3)
    * ($rrdc_flush/$step)
    * 2  # 2 logs
    / $MEG;

my $journal_rate = (($journal_size*$MEG/2))/$rrdc_flush;
my $journal_page_rate = $journal_rate / $pagesize;

$_ = sprintf("%.1f", $_)
    for ($write_time,
         $write_busy,
         $buffered_pdp,
         $max_ram,
         $journal_size,
         $journal_rate,
         $journal_page_rate,
     );

print <<"EOF";
RRD files     : $rrds files
RRD step      : $step seconds
Update length : $update_len bytes
IO writes/sec : $rrd_per_sec rrd/sec
write timer   : $rrdc_write seconds
flush timer   : $rrdc_flush seconds
-----------------------------------------------------------------

Time to write all RRDs: $write_time sec ($write_busy\% busy)

$buffered_pdp PDPs will be buffered per file

RAM usage: $max_ram MB

Journal size: $journal_size MB (total size for two journals)

Journal write rate: $journal_page_rate page/sec ($journal_rate byte/sec)
EOF

sub usage {
    system("perldoc $0");
    exit(1);
}
