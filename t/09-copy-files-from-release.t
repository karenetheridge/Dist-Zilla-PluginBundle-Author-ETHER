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
                [ '@Author::ETHER' => {
                    installer => 'MakeMaker',
                    '-remove' => \@REMOVED_PLUGINS,
                    server => 'none',
                    'RewriteVersion::Transitional.skip_version_provider' => 1,
                } ],
            ) . "\ncopy_file_from_release = extra_file\n",
            path(qw(source lib DZT Sample.pm)) => "package DZT::Sample;\n\n1",
            path(qw(source lib DZT Sample2.pm)) => "package DZT::Sample2;\n\n1",
            path(qw(source extra_file)) => "this is a random data file\n",
        },
    },
);

assert_no_git($tzil);

$tzil->chrome->logger->set_debug(1);
is(
    exception { $tzil->build },
    undef,
    'build proceeds normally',
);

cmp_deeply(
    $tzil->plugin_named('@Author::ETHER/CopyFilesFromRelease')->filename,
    bag(qw(CONTRIBUTING LICENSE Changes extra_file)),
    'additional copy_files_from_release file does not overshadow the defaults',
);

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

done_testing;
