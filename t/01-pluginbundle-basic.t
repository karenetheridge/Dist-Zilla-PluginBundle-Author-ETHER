use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use Test::Fatal;
use Path::Tiny;
use List::Util 'first';
use Module::Runtime 'module_notional_filename';

# these are used by our default 'installer' setting
use Test::Requires qw(
    Dist::Zilla::Plugin::MakeMaker::Fallback
    Dist::Zilla::Plugin::ModuleBuildTiny
);

use Test::File::ShareDir -share => { -dist => { 'Dist-Zilla-PluginBundle-Author-ETHER' => 'share' } };

use lib 't/lib';
use Helper;
use NoNetworkHits;
use NoPrereqChecks;

SKIP: {
    skip('we only insist that the author have bash installed', 1)
        unless $ENV{AUTHOR_TESTING};

    require Devel::CheckBin;
    ok(Devel::CheckBin::can_run('bash'), 'the bash executable is available');
}

require Dist::Zilla::PluginBundle::Author::ETHER;
$Dist::Zilla::PluginBundle::Author::ETHER::VERSION //= '1.000';

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
                        'Git::Contributors', 'Git::Check', 'Git::Commit', 'Git::Tag', 'Git::Push',
                        'Git::CheckFor::MergeConflicts', 'Git::CheckFor::CorrectBranch',
                        'Git::Remote::Check', 'PromptIfStale', 'EnsurePrereqsInstalled' ],
                    server => 'none',
                    ':version' => '0.002',
                } ],
            ),
            path(qw(source lib DZT Sample.pm)) => "package DZT::Sample;\n\n1",
            path(qw(source lib DZT Sample2.pm)) => "package DZT::Sample2;\n\n1",
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

# check that everything we loaded is in the pluginbundle's run-requires
all_plugins_in_prereqs($tzil,
    exempt => [ 'Dist::Zilla::Plugin::GatherDir' ],     # used by us here
    additional => [
        'Dist::Zilla::Plugin::MakeMaker::Fallback',     # via default installer option
        'Dist::Zilla::Plugin::ModuleBuildTiny::Fallback', # ""
    ],
);

SKIP:
foreach my $plugin ('Dist::Zilla::Plugin::MakeMaker::Fallback', 'Dist::Zilla::Plugin::ModuleBuildTiny::Fallback')
{
    skip "need recent $plugin to test default_jobs option", 1 if not $plugin->can('default_jobs');
    my $obj = first { $_->meta->name eq $plugin } @{$tzil->plugins};
    is(
        $obj->default_jobs,
        9,
        'default_jobs was set for ' . $obj->meta->name . ' (via installer option and extra_args',
    )
}

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
    t/00-report-prereqs.t
    xt/author/00-compile.t
    xt/author/eol.t
    xt/author/pod-spell.t
    xt/release/changes_has_content.t
    xt/release/cpan-changes.t
    xt/release/distmeta.t
    xt/release/kwalitee.t
    xt/release/minimum-version.t
    xt/release/mojibake.t
    xt/release/pod-coverage.t
    xt/release/pod-no404s.t
    xt/release/pod-syntax.t
    xt/release/portability.t
);

push @expected_files, eval { Dist::Zilla::Plugin::Test::NoTabs->VERSION('0.09'); 1 }
    ? 'xt/author/no-tabs.t'
    : 'xt/release/no-tabs.t';

push @expected_files, 't/00-report-prereqs.dd'
    if Dist::Zilla::Plugin::Test::ReportPrereqs->VERSION >= 0.014;

my @found_files;
my $iter = $build_dir->iterator({ recurse => 1 });
while (my $path = $iter->())
{
    push @found_files, $path->relative($build_dir)->stringify if -f $path;
}

cmp_deeply(
    \@found_files,
    bag(@expected_files),
    'the right files are created by the pluginbundle',
);

is(
    (grep { /someone tried to munge .* after we read from it. Making modifications again.../ } @{ $tzil->log_messages }),
    0,
    'no files were re-munged needlessly',
);

{
    cmp_deeply(
        $tzil->distmeta,
        superhashof({
            prereqs => superhashof({
                develop => superhashof({
                    requires => superhashof({
                        'Dist::Zilla::Plugin::ModuleBuildTiny::Fallback' => '0.006',
                        'Dist::Zilla::Plugin::MakeMaker::Fallback' => '0.012',
                        'Dist::Zilla::PluginBundle::Author::ETHER' => '0.002',
                    }),
                }),
            }),
            x_Dist_Zilla => superhashof({
                plugins => supersetof(
                    ( map {
                        +{
                            class => 'Dist::Zilla::Plugin::' . $_,
                            # TestRunner added default_jobs and started adding to dump_config in 5.014
                            ("Dist::Zilla::Plugin::$_"->can('default_jobs')
                                ? (config => superhashof({
                                    'Dist::Zilla::Role::TestRunner' => superhashof({ default_jobs => 9 }),
                                  }))
                                : ()),
                            name => '@Author::ETHER/' . $_,
                            version => ignore,
                        }
                    } qw(MakeMaker::Fallback ModuleBuildTiny::Fallback RunExtraTests) ),
                    subhashof({
                        class => 'Dist::Zilla::Plugin::Run::AfterRelease',
                        config => { # this may or may not be included, depending on the plugin version
                            'Dist::Zilla::Plugin::Run::Role::Runner' => {
                                fatal_errors => 0,
                                run => [ 'REDACTED' ],  # password detected!
                            },
                        },
                        name => '@Author::ETHER/install release',
                        version => ignore,
                    }),
                ),
            }),
        }),
        'config is properly included in metadata',
    )
    or diag 'got distmeta: ', explain $tzil->distmeta;
}

cmp_deeply(
    $tzil->distmeta,
    superhashof({
        prereqs => superhashof({
            develop => superhashof({
                requires =>
                    # TODO: replace with Test::Deep::notexists($key)
                    code(sub {
                        !exists $_[0]->{'Dist::Zilla::Plugin::Git::Commit'} ? 1 : (0, 'Dist::Zilla::Plugin::Git::Commit exists');
                    }),
            }),
        }),
    }),
    "a -remove'd plugin does not have a prereq injected into the dist",
);

is(
    $INC{ module_notional_filename('Dist::Zilla::Plugin::Git::Commit') },
    undef,
    "a -remove'd plugin has not been loaded",
);

# I'd like to test the release installation command here, but there's no nice
# way of doing that without risking leaking my (or someone else's!) PAUSE
# password in the failure output of like(). Can you imagine my embarrassment!

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

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

done_testing;
