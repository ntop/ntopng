#! /usr/bin/perl 

# this exercises just the perl module .. not RRDtool as such ... 

BEGIN { $| = 1; print "1..5\n"; }
END {
  print "not ok 1\n" unless $loaded;
  unlink "demo.rrd";
}

sub ok
{
    $ok_count++;
    my($what, $result) = @_ ;
    print "not " unless $result;
    print "ok $ok_count $what\n";
}

use RRDp;

$loaded = 1;
$ok_count = 1;

print "ok 1 module load\n";

ok("RRDp::start", RRDp::start "../../src/rrdtool" > 0);

$now=time();
RRDp::cmd qw(create demo.rrd --start ), $now, qw(--step 100 ),
  qw( DS:in:GAUGE:100:U:U RRA:AVERAGE:0.5:1:10 );

$answer = RRDp::read;
ok("RRDp::cmd",  -s "demo.rrd" );

RRDp::cmd qw(last demo.rrd);
$answer = RRDp::read;

ok("RRDp::read", $$answer =~ /$now/);

$status = RRDp::end;

ok("RRDp::end", $status == 0);
