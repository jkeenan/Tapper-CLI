package Artemis::CLI::Testrun::Command::rerun;

use 5.010;

use strict;
use warnings;

use parent 'App::Cmd::Command';

use YAML::Syck;
use Data::Dumper;
use File::Slurp 'slurp';
use Artemis::Model 'model';
use Artemis::Schema::TestrunDB;
use Artemis::CLI::Testrun;
use DateTime::Format::Natural;
require Artemis::Schema::TestrunDB::Result::Topic;
use Template;

use Moose;

has macropreconds => ( is => "rw" );

sub abstract {
        'Create a new testrun based on existing one'
}


sub opt_spec {
        return (
                [ "verbose",            "some more informational output"                                                                 ],
                [ "notes=s",            "TEXT; notes"                                                                                    ],
                [ "testrun=s",          "INT, testrun to start again"                                                                    ],
               );
}

sub usage_desc
{
        my $allowed_opts = join ' ', map { '--'.$_ } _allowed_opts();
        "artemis-testruns rerun --testrun=s [ --notes=s ]?";
}

sub _allowed_opts
{
        my @allowed_opts = map { $_->[0] } opt_spec();
}


sub validate_args
{
        my ($self, $opt, $args) = @_;


        my $msg = "Unknown option";
        $msg   .= ($args and $#{$args} >=1) ? 's' : '';
        $msg   .= ": ";
        say STDERR $msg, join(', ',@$args) if ($args and @$args);

        unless ($opt->{testrun}) {
                say "Missing argument --testrun";
                die $self->usage->text;
        }
        return 1;
}

sub execute 
{
        my ($self, $opt, $args) = @_;

        $self->new_runtest ($opt, $args);
}


sub new_runtest
{
        my ($self, $opt, $args) = @_;

        my $id  = $opt->{testrun};
        my $cmd = Artemis::Cmd::Testrun->new();
        my $retval = $cmd->rerun($id, $opt);
        die "Can't restart testrun $id" if not $retval;

        my $testrun = model('TestrunDB')->resultset('Testrun')->find( $retval );

        print $opt->{verbose} ? $testrun->to_string : $testrun->id, "\n";
}


# perl -Ilib bin/artemis-testrun rerun --testrun=1234

1;
