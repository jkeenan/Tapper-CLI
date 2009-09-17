#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Artemis::CLI::Testrun;
use Artemis::CLI::Testrun::Command::list;
use Artemis::CLI::Testrun::Command::new;
use Artemis::CLI::Testrun::Command::newprecondition;
use Artemis::CLI::Testrun::Command::listprecondition;
use Artemis::Schema::TestTools;
use Artemis::Model 'model';
use Test::Fixture::DBIC::Schema;

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testruns_with_scheduling.yml' );
# -----------------------------------------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# -----------------------------------------------------------------------------------------------------------------

my $testrun = Artemis::CLI::Testrun::Command::list::_get_entry_by_id (23); # perfmon

is($testrun->id, 23, "testrun id");
is($testrun->notes, 'perfmon', "testrun notes");
is($testrun->shortname, 'perfmon', "testrun shortname");
is($testrun->topic_name, 'Software', "testrun topic_name");
is($testrun->topic->name, 'Software', "testrun topic->name");
is($testrun->topic->description, 'any non-kernel software, e.g., libraries, programs', "testrun topic->description");



my $precond_id = `/usr/bin/env perl -Ilib bin/artemis-testrun newprecondition  --condition="affe: ~"`;
chomp $precond_id;

my $precond = model('TestrunDB')->resultset('Precondition')->find($precond_id);
ok($precond->id, 'inserted precond / id');
like($precond->precondition, qr"affe: ~", 'inserted precond / yaml');

# --------------------------------------------------

my $old_precond_id = $precond_id;
$precond_id = `/usr/bin/env perl -Ilib bin/artemis-testrun updateprecondition --id=$old_precond_id --shortname="foobar-perl-5.11" --condition="not_affe_again: ~"`;
chomp $precond_id;

$precond = model('TestrunDB')->resultset('Precondition')->find($precond_id);
is($precond->id, $old_precond_id, 'update precond / id');
is($precond->shortname, 'foobar-perl-5.11', 'update precond / shortname');
like($precond->precondition, qr'not_affe_again: ~', 'update precond / yaml');

# --------------------------------------------------

my $testrun_id = `/usr/bin/env perl -Ilib bin/artemis-testrun new --topic=Software --requested_host=iring --precondition=1`;
chomp $testrun_id;

$testrun = model('TestrunDB')->resultset('Testrun')->find($testrun_id);
ok($testrun->id, 'inserted testrun / id');
is($testrun->testrun_scheduling->requested_hosts->first->host->name, 'iring', 'inserted testrun / first requested host');
is($testrun->topic->name, 'Software', 'Topic for new testrun');

# --------------------------------------------------
#
# Testrun with requested feature
#

$testrun_id = `/usr/bin/env perl -Ilib bin/artemis-testrun new --requested_feature='mem > 4096' --queue=KVM --precondition=1`;
chomp $testrun_id;

$testrun = model('TestrunDB')->resultset('Testrun')->find($testrun_id);
ok($testrun->id, 'inserted testrun / id');
is($testrun->testrun_scheduling->requested_features->first->feature, 'mem > 4096', 'inserted testrun / first requested feature');
is($testrun->testrun_scheduling->queue->name, 'KVM', 'inserted testrun / Queue');



# --------------------------------------------------
SKIP: {
        skip "Update is currently deprecated", 3;
        my $old_testrun_id = $testrun_id;
        $testrun_id = `/usr/bin/env perl -Ilib bin/artemis-testrun update --id=$old_testrun_id --topic=Hardware --requested_host=iring`;
        chomp $testrun_id;

        $testrun = model('TestrunDB')->resultset('Testrun')->find($testrun_id);
        is($testrun->id, $old_testrun_id, 'updated testrun / id');
        is($testrun->topic_name, "Hardware", 'updated testrun / topic');
        is($testrun->testrun_scheduling->requested_hosts->first->host->name, 'iring', 'updated testrun / first requested host');
}

# --------------------------------------------------

`/usr/bin/env perl -Ilib bin/artemis-testrun delete --id=$testrun_id --really`;
$testrun = model('TestrunDB')->resultset('Testrun')->find($testrun_id);
is($testrun, undef, "delete testrun");

`/usr/bin/env perl -Ilib bin/artemis-testrun deleteprecondition --id=$precond_id --really`;
$precond = model('TestrunDB')->resultset('Precondition')->find($precond_id);
is($precond, undef, "delete precond");

# --------------------------------------------------

$testrun_id = `/usr/bin/env perl -Ilib bin/artemis-testrun new --macroprecond=t/files/kernel_boot.mpc -Dkernel_version=2.6.19 --requested_host=iring`;
chomp $testrun_id;
$testrun = model('TestrunDB')->resultset('Testrun')->search({id => $testrun_id,})->first();

my @precond_array = $testrun->ordered_preconditions;

is($precond_array[0]->precondition_as_hash->{precondition_type}, "package",'Parsing macropreconditions, first sub precondition');
is($precond_array[1]->precondition_as_hash->{precondition_type}, "exec",'Parsing macropreconditions, second sub precondition');
is($precond_array[1]->precondition_as_hash->{options}->[0], "2.6.19",'Parsing macropreconditions, template toolkit substitution');
is($precond_array[0]->precondition_as_hash->{filename}, "kernel/linux-2.6.19.tar.gz",'Parsing macropreconditions, template toolkit with if block');

$testrun_id = `/usr/bin/env perl -Ilib bin/artemis-testrun new --macroprecond=t/files/kernel_boot.mpc --requested_host=iring 2>&1`;
chomp $testrun_id;
like($testrun_id, qr/Expected macro field 'kernel_version' missing./, "missing mandatory field recognized");

$testrun_id = `/usr/bin/env perl -Ilib bin/artemis-testrun new --requested_host=iring 2>&1`;
chomp $testrun_id;
like($testrun_id, qr/At least one of .+ is required./, "Prevented testrun without precondition");

$testrun_id = `/usr/bin/env perl -Ilib bin/artemis-testrun rerun --testrun=23`;
chomp $testrun_id;
ok($testrun_id, 'Got some testrun');
isnt($testrun_id, 23, 'Rerun creates new testrun');
$testrun = model('TestrunDB')->resultset('Testrun')->find($testrun_id);
my $testrun_old = model('TestrunDB')->resultset('Testrun')->find(23);
@precond_array = $testrun->ordered_preconditions;
my @precond_array_old = $testrun_old->ordered_preconditions;
is_deeply(\@precond_array, \@precond_array_old, 'Rerun testrun with same preconditions');

# --------------------------------------------------

my $queue_id = `/usr/bin/env perl -Ilib bin/artemis-testrun newqueue  --name="Affe" --priority=4711`;
chomp $queue_id;

my $queue = model('TestrunDB')->resultset('Queue')->find($queue_id);
ok($queue->id, 'inserted queue / id');
is($queue->name, "Affe", 'inserted queue / name');
is($queue->priority, 4711, 'inserted queue / priority');

$testrun_id = `/usr/bin/env perl -Ilib bin/artemis-testrun new --topic=Software --requested_host=iring --precondition=1 --queue=Affe --auto_rerun`;
chomp $testrun_id;

$testrun = model('TestrunDB')->resultset('Testrun')->find($testrun_id);
ok($testrun->id, 'inserted testrun / id');
is($testrun->topic->name, 'Software', 'Topic for new testrun');
is($testrun->testrun_scheduling->queue->name, 'Affe', 'Queue for new testrun');
is($testrun->testrun_scheduling->auto_rerun, '1', 'Auto_rerun new testrun');


# --------------------------------------------------
done_testing();
