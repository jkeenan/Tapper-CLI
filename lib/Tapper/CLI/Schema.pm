package Tapper::CLI::Schema;

use 5.010;
use warnings;
use strict;

use Tapper::Model 'model';
use Compress::Bzip2;

=head1 NAME

Tapper::CLI::Schema - Tapper - handle everything related to schema changes

=head1 SYNOPSIS

This module is part of the Tapper::CLI framework. It is supposed to be
used together with App::Rad. All following functions expect their
arguments as $c->options->{$arg}.

    use App::Rad;
    use Tapper::CLI::Schema;
    Tapper::CLI::Schema::setup($c);
    App::Rad->run();

=head1 FUNCTIONS

=head2 zipfiles

Compress all uncompressed reportfile entries

@optparam verbose - be more chatty
@optparam help    - print out help message and die

=cut

sub zipfiles
{
        my ($c) = @_;
        $c->getopt( 'verbose|v', 'help|?' );

        if ($c->options->{help} ) {
                say STDERR "Usage: $0 zipfiles [ --verbose ]";
                say STDERR "\n  Optional arguments:";
                say STDERR "\t--verbose\tGive file name of the updated file";
                say STDERR "\t--help\t\tprint this help message and exit";
                exit -1;
        }
        my $uncompressed_files  = model('ReportsDB')->resultset('ReportFile')->search({is_compressed => 0});
        while (my $file = $uncompressed_files->next) {
                $file->set_filtered_column(filecontent => memBzip $file->filecontent);
                $file->is_compressed(1);
                $file->update();
                print( $c->options->{verbose} ? $file->filename."\n" : '.' );
        }
}




=head2 setup

Initialize the notification functions for tapper CLI

=cut

sub setup
{
        my ($c) = @_;
        $c->register('zipfiles', \&zipfiles, 'Compress all uncompressed files uploaded to reports framework');
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
