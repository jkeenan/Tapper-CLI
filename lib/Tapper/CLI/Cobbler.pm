package Tapper::CLI::Cobbler;

use 5.010;
use warnings;
use strict;

use Tapper::Cmd::Cobbler;

=head1 NAME

Tapper::CLI::Cobbler - Tapper - cobbler related commands for the tapper CLI

=head1 SYNOPSIS

This module is part of the Tapper::CLI framework. It is supposed to be
used together with App::Rad. All following functions expect their
arguments as $c->options->{$arg}.

    use App::Rad;
    use Tapper::CLI::Cobbler;
    Tapper::CLI::Cobbler::setup($c);
    App::Rad->run();

=head1 FUNCTIONS

=cut


=head2 host_new

Add a new system to cobbler by copying from an existing one.

=cut

sub host_new
{
        my ($c) = @_;
        $c->getopt(  'name=s','from=s', 'mac=s', 'quiet|q', 'help|?' );
        if ( $c->options->{help} or not $c->options->{name}) {
                say STDERR "Missing required parameter --name!" unless $c->options->{name};
                say STDERR "$0 cobbler-host-new  --name=s [ --quiet|q ] [ --from=s ]";
                say STDERR "\n\  Required Arguments:";
                say STDERR "        --name             Name of the new system";
                say STDERR "\n  Optional arguments:";
                say STDERR "        --from             Copy values of that system, default value is 'default'";
                say STDERR "        --mac              Provide mac address (will try to fetch from database if empty)";
                say STDERR "        --quit             Stay silent";
                say STDERR "        --help             Print this help message and exit";
                exit -1;
        }
        my $name    = $c->options->{name};
        my %options;
        $options{default} = $c->options->{default};
        $options{mac}     = $c->options->{mac};


        my $cmd = Tapper::Cmd::Cobbler->new();
        my $output = $cmd->host_new($name, \%options);
        return $output if $output;

        if (not $c->options->{quiet}) {
                return "Added host $name to cobbler";
        }
        return;
}

=head2 host_del

Delete existing system from cobbler.

=cut

sub host_del
{
        my ($c) = @_;
        $c->getopt( 'name=s', 'quiet|q', 'help|?' );
        if ( $c->options->{help} or not $c->options->{name}) {
                say STDERR "Missing required parameter --name!" unless $c->options->{name};
                say STDERR "$0 cobbler-host-del  --name=s [ --quiet|q ]";
                say STDERR "\n\  Required Arguments:";
                say STDERR "        --name             Name of the new system";
                say STDERR "\n  Optional arguments:";
                say STDERR "        --quiet            Stay silent";
                say STDERR "        --help             Print this help message and exit";
                exit -1;
        }
        my $name    = $c->options->{name};

        my $cmd = Tapper::Cmd::Cobbler->new();
        my $output = $cmd->host_del($name);
        die $output if $output;

        if (not $c->options->{quiet}) {
                return "Host $name removed from cobbler";
        }
        return;
}


=head2 host_list

Show all hosts known to cobbler, optionally all matching a given criteria.

=cut

sub host_list
{
        my ($c) = @_;
        $c->getopt( 'name=s', 'status', 'help|?' );
        if ( $c->options->{help}) {
                say STDERR "\n  Optional arguments:";
                say STDERR "        --name             Show system with that name";
                say STDERR "        --status           Show system with that status (one of development,testing,acceptance,production)";
                say STDERR "        --help             Print this help message and exit";
                exit -1;
        }

        my $cmd = Tapper::Cmd::Cobbler->new();
        my @output = $cmd->host_list();
        print join "\n",@output;
        return;
}


=head2 setup

Initialize the testplan functions for tapper CLI

=cut

sub setup
{
        my ($c) = @_;
        $c->register('cobbler-host-new', \&host_new,    'Add a new host to cobbler by copying from existing one');
        $c->register('cobbler-host-del', \&host_del,    'Remove an existing host from cobbler');
        $c->register('cobbler-host-list', \&host_list,  'Show host known to cobbler');
        if ($c->can('group_commands')) {
                $c->group_commands('Cobbler commands', 'cobbler-host-new', 'cobbler-host-del', 'cobbler-host-list' );
        }
        return;
}

=head1 AUTHOR

AMD OSRC Tapper Team, C<< <tapper at amd64.org> >>

=head1 BUGS


=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 AMD OSRC Tapper Team, all rights reserved.

This program is released under the following license: freebsd


=cut

1; # End of Tapper::CLI
