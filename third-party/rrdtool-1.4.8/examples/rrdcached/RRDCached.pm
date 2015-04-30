
use strict;
use warnings;

package RRDCached;

=head1 RRDCached

This module implements the B<RRDCached> client protocol for bulk updates.

=head1 SYNOPSIS

    my $cache = RRDCached->new('unix:/var/run/rrdcached.sock')
        or die "Cannot connect to RRDCached";

    $cache->update('file1.rrd', 'N:10:2:78');
    $cache->update('file2.rrd', '1222973760:30:0:9', 'N:68:1:55');
    ...

    $cache->done();

=cut

use IO::Socket;

#################################################################

sub new {
    my ($class, $daemon) = @_;
    my $this = {};

    $daemon ||= $ENV{RRDCACHED_ADDRESS};
    defined $daemon or return undef;

    my $sock_family = "INET";

    if ($daemon =~ m{^unix: | ^/ }x)
    {
        $sock_family = "UNIX";
        $daemon =~ s/^unix://;
    }

    my $sock = "IO::Socket::$sock_family"->new($daemon)
        or die "Cannot connect to daemon";

    $sock->printflush("BATCH\n");

    my $go = $sock->getline;
    warn "We didn't get go-ahead from rrdcached" unless $go =~ /^0/;

    $sock->autoflush(0);

    bless { sock => $sock,
            daemon => $daemon,
        }, $class;
}

sub update {
    my $this = shift;
    my $file = shift;
    ## @updates = @_;

    @_ or warn "No updates for $file!";

    ## rrdcached doesn't handle N: timestamps
    my $now = time();
    s/^N(?=:)/$now/ for (@_);

    $this->{sock}->print("update $file @_\n");
}

sub done {
    my ($this) = @_;

    my $sock = delete $this->{sock};

    $sock->printflush(".\n");
    my $errs = $sock->getline;

    my ($num_err) = $errs =~ /^(\d+)/;
    return unless $num_err;

    $sock->getline for (1..$num_err);

    $sock->close;
}

#################################################################

1;
