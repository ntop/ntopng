package Doxygen::Lua;

use warnings;
use strict;

=head1 NAME

Doxygen::Lua - Make Doxygen support Lua

=head1 VERSION

Version 0.04

=cut

our $VERSION = '0.04';

=head1 SYNOPSIS

    use Doxygen::Lua;
    my $p = Doxygen::Lua->new;
    print $p->parse($input);

=head1 DESCRIPTION

A script named "lua2dox" will be installed. Then modify your Doxyfile as below:

    FILTER_PATTERNS = *.lua=../bin/lua2dox

That's all!

=head1 SUBROUTINES/METHODS

=head2 new

This function will create a Doxygen::Lua object.

=cut

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    $self->_init;
    return $self;
}

sub _init {
    my $self = shift;
    $self->{mark} = '--!';
}

=head2 parse

This function will parse the given input file and return the result.

=cut

sub parse {
    my $self = shift;
    my $input = shift;

    my $in_block = 0;
    my $in_function = 0;
    my $block_name = q{};
    my $result = q{};
    my $doc_found = 0;
    my %modules;

    my $mark = $self->mark;
     
    open FH, "<$input"
        or die "Can't open $input for reading: $!";
     
    foreach my $line (<FH>) {
        chomp $line;

        # include empty lines
        if ($line =~ m{^\s*$}) {
            $result .= "\n"
        }
        # skip normal comments
        next if $line =~ /^\s*--[^!]/;
        # remove end of line comments
        $line =~ s/--[^!].*//;
        # skip comparison
        next if $line =~ /==/;
        # translate to doxygen mark
        $line =~ s{$mark}{///};

        # documentation string
        if ($line =~ m{^\s*///}) {
            $doc_found = 1;
            $result .= "$line\n";
        }
        # function start
        elsif ($line =~ /^function/) {
            $in_function = 1;
            $line .= q{;};
            $line =~ s/:/-/;

            if ($doc_found) {
                my $funcname = $line;
                $funcname =~ s/function\s+//;
                $funcname =~ s/\(.*//;

                my $dot_idx = index($funcname, ".");
                if($dot_idx != -1) {
                    my $module = substr $funcname, 0, $dot_idx;
                    $module = "module_" . $module;
                    my $method = substr $funcname, $dot_idx + 1;

                    # remove module from function name
                    $line =~ s/$funcname/$method/;

                    # assign the module to a group
                    $result .= "/// \@ingroup $module\n";
                    $modules{$module} = 1;
                }

                # note: single colon was replaced with "-" before
                my $colon_idx = index($funcname, "-");
                if($colon_idx != -1) {
                    my $module = substr $funcname, 0, $colon_idx;
                    $module = "module_" . $module;
                    my $method = substr $funcname, $colon_idx + 1;

                    # remove module from function name
                    $line =~ s/$funcname/$method/;

                    # assign the module to a group
                    $result .= "/// \@ingroup $module\n";
                    $modules{$module} = 1;
                }

                $result .= "$line\n";
            }
        }
	#local function start
   	elsif ($line =~ /^local.+function/) {
            $in_function = 1;
            $line .= q{;};
            $line =~ s/function\s+/function-/;

            if ($doc_found) {
                $result .= "$line\n";
            }
        }
        # function end
        elsif ($in_function == 1 && $line =~ /^end/) {
            $doc_found = 0;
            $in_function = 0;
        }
        # block start
        elsif ($in_function == 0 && $line =~ /^(\S+)\s*=\s*{/ && $line !~ /}/) {
            $block_name = $1; 
            $in_block = 1;
        }
        # block end
        elsif ($in_function == 0 && $line =~ /^\s*}/ && $in_block == 1) {
            $block_name = q{};
            $in_block = 0;
        }
        # variables
        elsif ($in_function == 0 && $line =~ /=/) {
            $line =~ s/(?=\S)/$block_name./ if $block_name;
            $line =~ s{,?(\s*)(?=///|$)}{;$1};

            if ($doc_found) {
                $result .= "$line\n";
                $doc_found = 0;
            }
        }
    }

    # define all the used groups
    for my $module (keys %modules) {
        $result .= "/// \@defgroup $module\n";
    }

    close FH;
    return $result;
}

=head2 mark

This function will set the mark style. The default value is "--!".

=cut

sub mark {
    my ($self, $value) = @_;
    $self->{mark} = $value if $value;
    return $self->{mark};
}

=head1 AUTHOR

Alec Chen, C<< <alec at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-doxygen-lua at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Doxygen-Lua>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Doxygen::Lua

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Doxygen-Lua>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Doxygen-Lua>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Doxygen-Lua>

=item * Search CPAN

L<http://search.cpan.org/dist/Doxygen-Lua/>

=back

=head1 ACKNOWLEDGEMENTS

=head1 REPOSITORY

See http://github.com/alecchen/doxygen-lua

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Alec Chen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1; # End of Doxygen::Lua
