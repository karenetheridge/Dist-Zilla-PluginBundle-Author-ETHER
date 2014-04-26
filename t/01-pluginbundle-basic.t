use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep '!blessed';
use Test::DZil;
use File::Find;
use File::Spec;
use Path::Tiny;
use Test::Deep::JSON;

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
            path(qw(source dist.ini)) => simple_ini(
                'GatherDir',
                # our files are copied into source, so Git::GatherDir doesn't see them
                # and besides, we would like to run these tests at install time too!
                [ '@Author::ETHER' => {
                    '-remove' => [ 'Git::GatherDir', 'Git::NextVersion', 'Git::Describe',
                        'Git::Check', 'Git::Commit', 'Git::Tag', 'Git::Push',
                        'Git::CheckFor::MergeConflicts', 'Git::CheckFor::CorrectBranch',
                        'Git::Remote::Check', 'PromptIfStale' ],
                    server => 'none',
                } ],
                'MetaConfig',
            ),
            path(qw(source lib DZT Sample.pm)) => "package DZT::Sample;\n\n1",
            path(qw(source lib DZT Sample2.pm)) => "package DZT::Sample2;\n\n1",
        },
    },
);

my @git_plugins =
    grep { /Git/ }
    map { $_->meta->name }
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

my $build_dir = path($tzil->tempdir)->child('build');

my @expected_files = qw(
    Build.PL
    Makefile.PL
    dist.ini
    INSTALL
    lib/DZT/Sample.pm
    lib/DZT/Sample2.pm
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

SKIP: {
    skip 'need recent Dist::Zilla to test default_jobs option', 1
        if not eval { Dist::Zilla->VERSION('5.014'); 1 };

    my $json = $tzil->slurp_file('build/META.json');
    cmp_deeply(
        $json,
        json(superhashof({
            prereqs => superhashof({
                develop => superhashof({
                    requires => superhashof({ 'Dist::Zilla::Plugin::ModuleBuildTiny' => '0.004' }),
                })
            }),
            x_Dist_Zilla => superhashof({
                plugins => supersetof(
                    map {
                        +{
                            class => 'Dist::Zilla::Plugin::' . $_,
                            config => superhashof({
                                'Dist::Zilla::Role::TestRunner' => superhashof({default_jobs => 9 }),
                            }),
                            name => ignore,
                            version => ignore,
                        }
                    } qw(MakeMaker::Fallback ModuleBuildTiny RunExtraTests)
                ),
            })
        })),
        'config is properly included in metadata',
    );
}

my $contributing = $tzil->slurp_file('build/CONTRIBUTING');
unlike($contributing, qr/[^\S\n]\n/m, 'no trailing whitespace in generated CONTRIBUTING');
like(
    $contributing,
    qr/^  \$ cpanm --reinstall --installdeps --with-recommends DZT::Sample\n.*^  \$ cpanm --reinstall --installdeps --with-develop --with-recommends DZT::Sample$/ms,
    'name of main module properly inserted into CONTRIBUTING',
);

my $version = Dist::Zilla::PluginBundle::Author::ETHER->VERSION // '';
like(
    $contributing,
    qr/^template file originating in Dist-Zilla-PluginBundle-Author-ETHER-$version\.$/m,
    'name of this bundle dist and its version properly inserted into CONTRIBUTING',
);

done_testing;
