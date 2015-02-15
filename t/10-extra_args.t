use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use Test::Fatal;
use Path::Tiny;

use lib 't/lib';
use Helper;

use Dist::Zilla::Plugin::MakeMaker;
plan skip_all => 'need recent [MakeMaker] to test use of default_jobs option'
    if not Dist::Zilla::Plugin::MakeMaker->can('default_jobs');

use Test::File::ShareDir -share => { -dist => { 'Dist-Zilla-PluginBundle-Author-ETHER' => 'share' } };

my $tzil = Builder->from_config(
    { dist_root => 't/does_not_exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                'GatherDir',
                [ '@Author::ETHER' => {
                    '-remove' => \@REMOVED_PLUGINS,
                    server => 'none',
                    installer => 'MakeMaker',
                    'MakeMaker.default_jobs' => '8',
                    'RewriteVersion::Transitional.skip_version_provider' => 1,
                } ],
            ),
            path(qw(source lib DZT Sample.pm)) => "package DZT::Sample;\n\n1",
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

is(
    $tzil->plugin_named('@Author::ETHER/MakeMaker')->default_jobs,
    8,
    'extra arg added to plugin was overridden by the user',
);

done_testing;
