package Tapper::CLI::DbDeploy::Command::init;

use 5.010;

use strict;
use warnings;

use parent 'App::Cmd::Command';

use Tapper::CLI::DbDeploy;
use Tapper::Cmd::DbDeploy;
use Data::Dumper;
use Tapper::Schema::TestrunDB;


sub opt_spec {
        return (
                [ "verbose", "some more informational output"       ],
                [ "db=s",    "STRING, one of: ReportsDB, TestrunDB" ],
               );
}

sub abstract {
        'Initialize a database from scratch. DANGEROUS! Think twice.'
}

sub usage_desc
{
        my ($self, $opt, $args) = @_;
        my $allowed_opts = join ' ', map { '--'.$_ } $self->_allowed_opts();
        "tapper-db-deploy init --db=DBNAME  [ --verbose ]";
}

sub _allowed_opts {
        my ($self, $opt, $args) = @_;
        my @allowed_opts = map { $_->[0] } $self->opt_spec();
}

sub validate_args {
        my ($self, $opt, $args) = @_;

        #         print "opt  = ", Dumper($opt);
        #         print "args = ", Dumper($args);

        my $ok = 1;
        if (not $opt->{db})
        {
                say "Missing argument --db\n";
                $ok = 0;
        }
        elsif (not $opt->{db} = 'TestrunDB' )
        {
                say "Wrong DB name '".$opt->{db}."' (must be TestrunDB)";
                $ok = 0;
        }

        return $ok if $ok;
        die $self->usage->text;
}

sub run
{
        my ($self, $opt, $args) = @_;

        my $cmd = Tapper::Cmd::DbDeploy->new;
        $cmd->dbdeploy($opt->{db});
}


# perl -Ilib bin/tapper-db-deploy init --db=TestrunDB

1;
