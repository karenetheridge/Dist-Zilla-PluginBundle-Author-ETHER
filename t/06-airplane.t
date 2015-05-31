use strict;
use warnings;

use Test::More;
use Test::Warnings 0.009 ':no_end_test', ':all';
use Test::DZil;
use Test::Deep '!any';
use Test::Fatal;
use Path::Tiny;
use List::Util 1.33 'any';
use PadWalker 'closed_over';
use Term::ANSIColor 2.01 'colorstrip';

use lib 't/lib';
use Helper;
use NoNetworkHits;
use NoPrereqChecks;

# used by the 'airplane' config
use Test::Requires 'Dist::Zilla::Plugin::BlockRelease';

use Test::File::ShareDir -share => { -dist => { 'Dist-Zilla-PluginBundle-Author-ETHER' => 'share' } };

my $tzil;
my @warnings = warnings {
    $tzil = Builder->from_config(
        { dist_root => 'does-not-exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    'GatherDir',
                    [ '@Author::ETHER' => {
                        '-remove' => [
                            @REMOVED_PLUGINS,
                            'UploadToCPAN', # removed just in case!
                            'RunExtraTests', 'TestRelease', # why waste the time?
                        ],
                        airplane => 1,
                        'RewriteVersion::Transitional.skip_version_provider' => 1,
                    } ],
                    'FakeRelease',  # replaces UploadToCPAN, just in case!
                ),
                path(qw(source lib Foo Bar.pm)) => <<MODULE,
use strict;
use warnings;
package Foo::Bar;

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

my $ok = cmp_deeply(
    [ map { colorstrip($_) } @warnings ],
    superbagof(re(qr'^\[@Author::ETHER\] building in airplane mode - plugins requiring the network are skipped, and releases are not permitted')),
    'we warn when in airplane mode',
) or diag explain @warnings;
diag explain grep { !m'building in airplane mode - plugins requiring the network are skipped, and releases are not permitted' } @warnings if $ok;

assert_no_git($tzil);

$tzil->chrome->logger->set_debug(1);
is(
    exception { $tzil->build },
    undef,
    'build proceeds normally',
);

# check that everything we loaded is in the pluginbundle's run-requires, etc
all_plugins_in_prereqs($tzil,
    exempt => [
        'Dist::Zilla::Plugin::GatherDir',       # used by us here
        'Dist::Zilla::Plugin::FakeRelease',     # ""
    ],
    additional => [
        'Dist::Zilla::Plugin::BlockRelease',    # via airplane option
    ],
);

my @network_plugins =
    map { Dist::Zilla::Util->expand_config_package_name($_) } @{
        closed_over(\&Dist::Zilla::PluginBundle::Author::ETHER::configure)->{'@network_plugins'}
    };

my @found_network_plugins = grep {
    my $plugin = $_;
    any { $_ eq $plugin } @network_plugins
} $tzil->plugins;

cmp_deeply(
    \@found_network_plugins,
    [],
    'no network-using plugins were actually loaded',
);

like(
    exception { $tzil->release },
    qr{\[\@Author::ETHER/BlockRelease\] halting release},
    'release halts',
);

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

had_no_warnings if $ENV{AUTHOR_TESTING};
done_testing;
