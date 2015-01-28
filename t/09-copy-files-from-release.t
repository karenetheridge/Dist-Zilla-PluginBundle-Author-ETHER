use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use Test::Fatal;
use Path::Tiny;
use List::Util 'first';

use Test::File::ShareDir -share => { -dist => { 'Dist-Zilla-PluginBundle-Author-ETHER' => 'share' } };

use lib 't/lib';
use Helper;
use NoNetworkHits;
use NoPrereqChecks;

my $tzil = Builder->from_config(
    { dist_root => 't/does_not_exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                'GatherDir',
                # our files are copied into source, so Git::GatherDir doesn't see them
                # and besides, we would like to run these tests at install time too!
                [ '@Author::ETHER' => {
                    installer => 'MakeMaker',
                    '-remove' => [ 'Git::GatherDir', 'Git::NextVersion', 'Git::Describe',
                        'Git::Contributors', 'Git::Check', 'Git::Commit', 'Git::Tag', 'Git::Push',
                        'Git::CheckFor::MergeConflicts', 'Git::CheckFor::CorrectBranch',
                        'Git::Remote::Check', 'PromptIfStale', 'EnsurePrereqsInstalled' ],
                    server => 'none',
                } ],
            ) . "\ncopy_file_from_release = extra_file\n",
            path(qw(source lib DZT Sample.pm)) => "package DZT::Sample;\n\n1",
            path(qw(source lib DZT Sample2.pm)) => "package DZT::Sample2;\n\n1",
            path(qw(source extra_file)) => "this is a random data file\n",
        },
    },
);

my @git_plugins = grep { $_->meta->name =~ /Git(?!(?:hubMeta|Hub::Update))/ } @{$tzil->plugins};
cmp_deeply(\@git_plugins, [], 'no git-based plugins are running here');

$tzil->chrome->logger->set_debug(1);
is(
    exception { $tzil->build },
    undef,
    'build proceeds normally',
);

cmp_deeply(
    $tzil->plugin_named('@Author::ETHER/CopyFilesFromRelease')->filename,
    bag(qw(CONTRIBUTING LICENSE extra_file)),
    'additional copy_files_from_release file does not overshadow the defaults',
);

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

done_testing;
