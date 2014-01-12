use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use File::Find;
use File::Spec;
use Path::Tiny;

# these are used by our default 'installer' setting
use Test::Requires qw(
    Dist::Zilla::Plugin::MakeMaker::Fallback
    Dist::Zilla::Plugin::ModuleBuildTiny
);

use Test::File::ShareDir -share => { -dist => { 'Dist-Zilla-PluginBundle-Author-ETHER' => 'share' } };

use lib 't/lib';
use Helper;

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
                } ],
            ),
            path(qw(source lib NoOptions.pm)) => "package NoOptions;\n\n1",
        },
    },
);

my @git_plugins =
    grep { /Git/ }
    map { blessed $_ }
    @{$tzil->plugins};

cmp_deeply(\@git_plugins, [], 'no git-based plugins are running here');

$tzil->chrome->logger->set_debug(1);
$tzil->build;

# check that everything we loaded is in the pluginbundle's run-requires
all_plugins_in_prereqs($tzil,
    exempt => [ 'Dist::Zilla::Plugin::GatherDir' ],     # used by us here
    additional => [
        'Dist::Zilla::Plugin::MakeMaker::Fallback',     # via installer option
        'Dist::Zilla::Plugin::ModuleBuildTiny',         # ""
    ],
);

my $build_dir = $tzil->tempdir->subdir('build');

my @expected_files = qw(
    Build.PL
    Makefile.PL
    dist.ini
    INSTALL
    lib/NoOptions.pm
    CONTRIBUTING
    LICENSE
    MANIFEST
    META.json
    META.yml
    README
    README.md
    t/00-report-prereqs.t
    xt/author/00-compile.t
    xt/author/pod-spell.t
    xt/release/changes_has_content.t
    xt/release/cpan-changes.t
    xt/release/distmeta.t
    xt/release/eol.t
    xt/release/kwalitee.t
    xt/release/minimum-version.t
    xt/release/mojibake.t
    xt/release/no-tabs.t
    xt/release/pod-coverage.t
    xt/release/pod-no404s.t
    xt/release/pod-syntax.t
    xt/release/portability.t
    xt/release/test-version.t
    xt/release/unused-vars.t
);

my @found_files;
find({
        wanted => sub { push @found_files, File::Spec->abs2rel($_, $build_dir) if -f  },
        no_chdir => 1,
     },
    $build_dir,
);

cmp_deeply(
    \@found_files,
    bag(@expected_files),
    'the right files are created by the pluginbundle',
);

is(
    (grep { /someone tried to munge .* after we read from it. Making modifications again.../ } @{ $tzil->log_messages }),
    0,
    'no files were re-munged needlessly',
) or diag 'found messages:' . join("\n", @{ $tzil->log_messages });

done_testing;
