package Artemis::CLI::Testrun::Command::new;

use 5.010;

use strict;
use warnings;

use parent 'App::Cmd::Command';

use YAML::Syck;
use Data::Dumper;
use File::Slurp 'slurp';
use Artemis::Model 'model';
use Artemis::Schema::TestrunDB;
use Artemis::Cmd::Precondition;
use Artemis::Cmd::Requested;
use Artemis::CLI::Testrun;
use DateTime::Format::Natural;
require Artemis::Schema::TestrunDB::Result::Topic;
use Template;

use Moose;

has macropreconds => ( is => "rw" );

sub abstract {
        'Create a new testrun'
}


my $options = { "verbose"           => { text => "some more informational output" },
                "notes"             => { text => "TEXT; notes", type => 'string' },
                "shortname"         => { text => "TEXT; shortname", type => 'string' },
                "queue"             => { text => "STRING, default=AdHoc", type => 'string' },
                "topic"             => { text => "STRING, default=Misc; one of: Kernel, Xen, KVM, Hardware, Distribution, Benchmark, Software, Misc", type => 'string' },
                "owner"             => { text => "STRING, default=\$USER; user login name", type => 'string' },
                "wait_after_tests"  => { text => "BOOL, default=0; wait after testrun for human investigation", type => 'bool' },
                "auto_rerun"        => { text => "BOOL, default=0; put this testrun into db again when it is chosen by scheduler", type => 'bool' },
                "earliest"          => { text => "STRING, default=now; don't start testrun before this time (format: YYYY-MM-DD hh:mm:ss or now)", type => 'string' },
                "precondition"      => { text => "assigned precondition ids", needed => 1, type => 'manystring'  },
                "macroprecond"      => { text => "STRING, use this macro precondition file", needed => 1 , type => 'string' },
                "D"                 => { text => "Define a key=value pair used in macro preconditions", type => 'keyvalue' },
                "requested_host"    => { text => "String; name one possible host for this testrequest; \n\t\t\t\t  ".
                                                "multiple requested hosts are OR evaluated, i.e. each is appropriate", type => 'manystring' },
                "requested_feature" => { text => "String; description of one requested feature of a matching host for this testrequest; \n\t\t\t\t  ".
                                                "multiple requested features are AND evaluated, i.e. each must fit; ".
                                                "not evaluated if a matching requested host is found already", type => 'manystring' },
                };

sub opt_spec {
        my @opt_spec;
        foreach my $key (keys %$options) {
                my $pushkey;
                given($options->{$key}->{type}){
                        when ("string")     {$pushkey = $key ."=s";}
                        when ("manystring") {$pushkey = $key ."=s@";}
                        when ("keyvalue")   {$pushkey = $key ."=s%";}
                        default             {$pushkey = $key; }
                }
                push @opt_spec, [$pushkey, $options->{$key}->{text}];
        }
        return (
                @opt_spec
               );
}


sub usage_desc
{
        my $allowed_opts = join ' ', map { '--'.$_ } _allowed_opts();
        "artemis-testruns new  [ --requested_host=s@ | --requested_feature=s@ | --topic=s | --queue=s | --notes=s | --shortname=s | --owner=s | --wait_after_tests=s | --macroprecond=s | -Dkey=val | --auto_rerun]*";
}

sub _allowed_opts
{
        my @allowed_opts = map { $_->[0] } opt_spec();
}

sub convert_format_datetime_natural
{
        my ($self, $opt, $args) = @_;
        # handle natural datetimes
        if ($opt->{earliest}) {
                my $parser = DateTime::Format::Natural->new;
                my $dt = $parser->parse_datetime($opt->{earliest});
                if ($parser->success) {
                        print("%02d.%02d.%4d %02d:%02d:%02d\n", $dt->day,
                              $dt->month,
                              $dt->year,
                              $dt->hour,
                              $dt->min,
                              $dt->sec) if $opt->{verbose};
                        $opt->{earliest} = $dt;
                } else {
                        die $parser->error;
                }
        }
}

sub validate_args
{
        my ($self, $opt, $args) = @_;

        #         print "opt  = ", Dumper($opt);
        #         print "args = ", Dumper($args);

        # -- topic constraints --
        my $topic    = $opt->{topic} || '';

        my $msg = "Unknown option";
        $msg   .= ($args and $#{$args} >=1) ? 's' : '';
        $msg   .= ": ";
        say STDERR $msg, join(', ',@$args) if ($args and @$args);


        my @needed_opts;
        my $precondition_ok;
        foreach my $key (keys %$options) {
                push @needed_opts, $key if  $options->{$key}->{needed};
        }

        my $needed_opts_re = join '|', @needed_opts;

        if (grep /$needed_opts_re/, keys %$opt) {
                $precondition_ok = 1;
        } else {
                say STDERR "At least one of ",join ", ",@needed_opts," is required.";
        }


        $self->convert_format_datetime_natural;

        my $macrovalues_ok = 1;
        if ($opt->{macroprecond}) {
                my @precond_lines =  slurp $opt->{macroprecond};
                my @mandatory;
                my $required = '';
                foreach my $line (@precond_lines) {
                        ($required) = $line =~/# (?:artemis[_-])?mandatory[_-]fields:\s*(.+)/;
                        last if $required;
                }

                my $delim = qr/,+\s*/;
                foreach my $field (split $delim, $required) {
                        my ($name, $type) = split /\./, $field;
                        if (not $opt->{d}{$name}) {
                                say STDERR "Expected macro field '$name' missing.";
                                $macrovalues_ok = 0;
                        }
                }
                $self->{macropreconds} = join '',@precond_lines;
        }

        return 1 if $precondition_ok and $macrovalues_ok;

        die $self->usage->text;
}

sub execute 
{
        my ($self, $opt, $args) = @_;

        $self->new_runtest ($opt, $args);
}

=head2 create_macro_preconditions

Process a macroprecondition. This includes substitions using
Template::Toolkit, separating the individual preconditions that are part of
the macroprecondition and putting them into the database. Parameters fit the
App::Cmd::Command API.

@param hashref - hash containing options
@param hashref - hash containing arguments

@returnlist array containing precondition ids

=cut

sub create_macro_preconditions
{
        my ($self, $opt, $args) = @_;

        my $D             = $opt->{d}; # options are auto-down-cased
        my $tt            = new Template ();
        my $macro         = $self->{macropreconds};
        my $ttapplied;

        $tt->process(\$macro, $D, \$ttapplied) || die $tt->error();
        my $precondition = Artemis::Cmd::Precondition->new();
        my @ids = $precondition->add($ttapplied);
        return @ids;
}


sub add_host
{
        my ($self, $testrun_id, $host) = @_;
        my $cmd =  Artemis::Cmd::Requested->new();
        my $id = $cmd->add_host($testrun_id, $host);
        return $id;

}


sub add_feature
{
        my ($self, $testrun_id, $feature) = @_;
        my $cmd = Artemis::Cmd::Requested->new();
        my $id = $cmd->add_feature($testrun_id, $feature);
        return $id;

}


sub new_runtest
{
        my ($self, $opt, $args) = @_;

        #print "opt  = ", Dumper($opt);

        my $testrun = {
                       notes        => $opt->{notes}        || '',
                       shortname    => $opt->{shortname}    || '',
                       topic        => $opt->{topic}        || 'Misc',
                       date         => $opt->{earliest}     || DateTime->now,
                       owner        => $opt->{owner}        || $ENV{USER},
                       auto_rerun   => $opt->{auto_rerun},
                       queue        => $opt->{queue}        || 'AdHoc',
                      };
        my @ids;


        @ids = $self->create_macro_preconditions($opt, $args) if $opt->{macroprecond};
        push @ids, @{$opt->{precondition}} if $opt->{precondition};

        die "No valid preconditions given" if not @ids;

        my $cmd = Artemis::Cmd::Testrun->new();
        my $testrun_id = $cmd->add($testrun);
        die "Can't create new testrun because of an unknown error" if not $testrun_id;
        my $testrun_search = model('TestrunDB')->resultset('Testrun')->find($testrun_id);

        my $retval = $cmd->assign_preconditions($testrun_id, @ids);
        if ($retval) {
                $testrun_search->delete();     
                die $retval;
        }

        if ($opt->{requested_host}) {
                foreach my $host(@{$opt->{requested_host}}) {
                        push @ids, $self->add_host($testrun_id, $host);
                }
        }

        if ($opt->{requested_feature}) {
                foreach my $feature(@{$opt->{requested_feature}}) {
                        push @ids, $self->add_feature($testrun_id, $feature);
                }
        }
        $testrun_search->testrun_scheduling->status('schedule');
        $testrun_search->testrun_scheduling->update;  

        if ($opt->{verbose}) {
                say $testrun_search->to_string;
        } else {
                say $testrun_id;
        }
}



# perl -Ilib bin/artemis-testrun new --topic=Software --precondition=14  --owner=ss5

1;
