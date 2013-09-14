use strict;
use warnings FATAL => 'all';

use Test::More;
use JSON;

BEGIN {
    plan skip_all => 'these tests require a git repository'
        unless -d '.git' or -d '../../.git' or -d '../../../.git';
}

use if $ENV{AUTHOR_TESTING} || $ENV{AUTOMATED_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use File::Find;
use File::Spec;

my $tzil = Builder->from_config(
    { dist_root => 't/corpus/dist/no_options' },
    {
        add_files => {
            'source/dist.ini' => dist_ini(
                {
                    name    => 'NoOptions',
                    author  => 'E. Xavier Ample <example@example.org>',
                    copyright_holder => 'E. Xavier Ample',
                    copyright_year => '2013',
                    license => 'Perl_5',
                },
                'GatherDir',
                # our files are copied into source, so Git::GatherDir doesn't see them
                [ '@Author::ETHER' => {
                    server => 'gitmo',
                    '-remove' => [ 'Git::GatherDir', 'PromptIfStale' ],
                  },
                ],
            ),
        },
    },
);

$tzil->build;

my $json = $tzil->slurp_file('build/META.json');
my $meta = JSON->new->decode($json);

cmp_deeply(
    $meta->{resources},
    {
        bugtracker => {
            mailto => 'bug-NoOptions@rt.cpan.org',
            web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=NoOptions',
        },
        # no homepage set
        repository => {
            type => 'git',
            url => 'git://git.moose.perl.org/NoOptions.git',
            web => 'http://git.shadowcat.co.uk/gitweb/gitweb.cgi?p=gitmo/NoOptions.git;a=summary',
        },
    },
    'all meta resources are correct',
);

done_testing;
