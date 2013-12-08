use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Warnings 0.005 ':no_end_test', ':all';
use Test::DZil;
use Test::Deep;
use Test::Fatal;
use Path::Tiny;

my $tzil;
my @warnings = warnings {
    $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    'GatherDir',
                    [ '@Author::ETHER' => {
                        # our files are copied into source, so Git::GatherDir doesn't see them
                        # and besides, we would like to run these tests at install time too!
                        '-remove' => [ 'Git::GatherDir', 'Git::NextVersion', 'Git::Describe', 'PromptIfStale' ],
                        airplane => 1,
                    } ],
                ),
                path(qw(source lib Foo Bar.pm)) => "package Foo::Bar;\n1;\n",
            },
        },
    );
};

cmp_deeply(
    \@warnings,
    [ re(qr/^building in airplane mode - plugins requiring the network are skipped, and releases are not permitted/) ],
    'we warn when in airplane mode',
);

is(
    exception { $tzil->build },
    undef,
    'build proceeds normally',
);

like(
    exception { $tzil->release },
    qr{\[\@Author::ETHER/BlockRelease\] halting release},
    'release halts',
);

done_testing;
