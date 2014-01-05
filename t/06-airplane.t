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
                        '-remove' => [ qw(Git::GatherDir Git::NextVersion Git::Describe Git::Tag
                            Git::Check Git::CheckFor::MergeConflicts
                            Git::CheckFor::CorrectBranch Git::Remote::Check Git::Push),
                            'PromptIfStale',
                            'CheckPrereqsIndexed',  # we will trip up on ourselves (it got a version bump,
                                                    # but obviously is not yet indexed)
                                                    # FIXME - update when the plugin gets smarter
                            'UploadToCPAN', # removed just in case!
                        ],
                        airplane => 1,
                    } ],
                    'FakeRelease',  # replaces UploadToCPAN
                ),
                path(qw(source lib Foo Bar.pm)) => <<MODULE,
package Foo::Bar;
use strict;
use warnings;
1;
MODULE
                path(qw(source Changes)) => <<'CHANGES',
Revision history for {{$dist->name}}

{{$NEXT}}
        - some changelog entry
CHANGES
            },
        },
    );
};

cmp_deeply(
    \@warnings,
    [ re(qr/^building in airplane mode - plugins requiring the network are skipped, and releases are not permitted/) ],
    'we warn when in airplane mode',
) or diag join("\n", @warnings);

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
