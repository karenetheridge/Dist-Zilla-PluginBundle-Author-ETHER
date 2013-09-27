use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;

use lib 't/lib';
use Helper;

# tests the core plugin - with all options disabled

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    'GatherDir',
                    # our files are copied into source, so Git::GatherDir doesn't see them
                    # and besides, we would like to run these tests at install time too!
                    [ '@Author::ETHER' => {
                        '-remove' => [ 'Git::GatherDir', 'Git::NextVersion', 'Git::Describe', 'PromptIfStale' ],
                        server => 'none',
                        installer => 'none',
                      },
                    ],
                ),
                path(qw(source lib MyModule.pm)) => 'package MyModule; 1',
            },
        },
    );

    $tzil->build;

    # check that everything we loaded is in test-requires or run-requires
    all_plugins_are_required($tzil,
        'Dist::Zilla::Plugin::GatherDir',   # used by us here
    );

    ok(!-e "build/$_", "no $_ was created in the dist") foreach qw(Makefile.PL Build.PL);
}

done_testing;
