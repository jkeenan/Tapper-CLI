package Tapper::CLI::Notification;

use 5.010;
use warnings;
use strict;

use YAML::XS;
use Tapper::Cmd::Notification;

=head1 NAME

Tapper::CLI::Notification - Tapper - notification commands for the tapper CLI

=head1 SYNOPSIS

This module is part of the Tapper::CLI framework. It is supposed to be
used together with App::Rad. All following functions expect their
arguments as $c->options->{$arg}.

    use App::Rad;
    use Tapper::CLI::Notification;
    Tapper::CLI::Notification::setup($c);
    App::Rad->run();

=head1 FUNCTIONS

=head2 notificationnew

Register new notification subscriptions.

@param file     - contains the new subscription in YAML, multiple can be given
@optparam user  - overwrite user information given in the file or set if none
@optparam quiet - only return notification ids
@optparam help  - print out help message and die

=cut

sub notificationnew
{
        my ($c) = @_;
        $c->getopt( 'file|f=s', 'user|u=s','quiet|q', 'help|?' );

        if (not %{$c->options} or $c->options->{help} ) {
                say STDERR "Usage: $0 notification-new --file=filename [ --user=login ] [ --quiet ]";
                say STDERR "\n\  Required Arguments:";
                say STDERR "\t--file\t\tname of file containing the notification subscriptions in YAML (required)";
                say STDERR "\n  Optional arguments:";
                say STDERR "\t--user\t\tset this user for all notification subscriptions (even if a different one is set in YAML)";
                say STDERR "\t--quiet\t\tOnly return notification ids";
                say STDERR "\t--help\t\tprint this help message and exit";
                exit -1;
        }

        my $cmd = Tapper::Cmd::Notification->new();
        my $user = $c->options->{user};

        my @ids;
        my @subscriptions =  YAML::XS::LoadFile($c->options->{file});
        foreach my $subscription (@subscriptions) {
                if ($user) {
                        $subscription->{user_login} = $user;
                        delete $subscription->{owner_id};
                }
                push @ids, $cmd->add($subscription);
        }
        my $msg;
        $msg  = "The notification subscriptions were registered with the following ids:" if not $c->options->{quiet};
        $msg .= join ",", @ids;
        return $msg;
}

=head2 notificationlist

Show all or a subset of notification subscriptions

@optparam

=cut

sub notificationlist
{
        my ($c) = @_;
        my $cmd = Tapper::Cmd::Notification->new();
        my $subscription_result = $cmd->list();
        while (my $this_subscription = $subscription_result->next) {
                delete $this_subscription->{created_at};
                delete $this_subscription->{updated_at};
                print YAML::XS::Dump($this_subscription);
        }
        return;
}

=head2 notificationupdate

Update an existing notification subscription.

@param file - name of the file containing the new data for subscription notification in YAML
@param id   - id of the notification subscription to update
@optparam quiet - only return ids of updated notification subscriptions
@optparam help  - print out help message and die

=cut

sub notificationupdate
{
        my ($c) = @_;
        $c->getopt( 'file|f=s', 'id|i=i','quiet|q', 'help|?' );

        if (not %{$c->options} or $c->options->{help} ) {
                say STDERR "Usage: $0 notification-update --file=filename --id=id [ --quiet ]";
                say STDERR "\n\  Required Arguments:";
                say STDERR "\t--file\t\tname of file containing the notification subscriptions in YAML";
                say STDERR "\t--id\t\tid of the notification subscriptions";
                say STDERR "\n  Optional arguments:";
                say STDERR "\t--quiet\t\tonly return ids of updated notification subscriptions";
                say STDERR "\t--help\t\tprint this help message and exit";
                exit -1;
        }

        my $cmd = Tapper::Cmd::Notification->new();

        my $subscription =  YAML::XS::LoadFile($c->options->{file});
        my $id = $cmd->update($c->options->{id}, $subscription);

        return "The notification subscription was updated:" unless $c->options->{quiet};
        return $id;
}

=head2 notificationdel

Delete an existing notification subscription.

@param id       - id of the notification subscription to delete
@optparam quiet - stay silent when deleting succeeded
@optparam help  - print out help message and die


=cut

sub notificationdel
{
        my ($c) = @_;
        $c->getopt( 'id|i=i','quiet|q', 'help|?' );

        if (not %{$c->options} or $c->options->{help} ) {
                say STDERR "Usage: $0 notification-del --id=id";
                say STDERR "\n\  Required Arguments:";
                say STDERR "\t--id\t\tDatabase ID of the notification subscription";
                say STDERR "\n  Optional arguments:";
                say STDERR "\t--quiet\t\tStay silent when deleting succeeded";
                say STDERR "\t--help\t\tprint this help message and exit";
                exit -1;
        }

        my $cmd = Tapper::Cmd::Notification->new();

        my $id = $cmd->del($c->options->{id});

        return "The notification subscription was deleted." unless $c->options->{quiet};
        return;
}



=head2 setup

Initialize the notification functions for tapper CLI

=cut

sub setup
{
        my ($c) = @_;
        $c->register('notification-new', \&notificationnew, 'Register a new notification subscription');
        $c->register('notification-list', \&notificationlist, 'Show all notification subscriptions');
        $c->register('notification-update', \&notificationupdate, 'Update an existing notification subscription');
        $c->register('notification-del', \&notificationdel, 'Delete an existing notification subscription');
        if ($c->can('group_commands')) {
                $c->group_commands('Notification commands', 'notification-new', 'notification-list', 'notification-update', 'notification-del');
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
