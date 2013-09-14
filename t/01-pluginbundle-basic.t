use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING} || $ENV{AUTOMATED_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use File::Find;
use File::Spec;

my $tzil = Builder->from_config(
    { dist_root => 't/corpus/dist/no_options' },
    {
        add_files => {
            'source/dist.ini' => dist_ini(
                {
                    name    => 'NoOptions',
                    author  => 'E. Xavier Ample <example@example.org>',
                    copyright_holder => 'E. Xavier Ample',
                    copyright_year => '2013',
                    license => 'Perl_5',
                    version => '1.0',
                },
                'GatherDir',
                # our files are copied into source, so Git::GatherDir doesn't see them
                # and besides, we would like to run these tests at install time too!
                [ '@Author::ETHER' => {
                    '-remove' => [ 'Git::GatherDir', 'Git::NextVersion', 'PromptIfStale' ],
                } ],
            ),
        },
    },
);

$tzil->build;
my $build_dir = $tzil->tempdir->subdir('build');

my @expected_files = qw(
    Build.PL
    dist.ini
    INSTALL
    lib/NoOptions.pm
    LICENSE
    MANIFEST
    META.json
    META.yml
    README
    t/00-check-deps.t
    t/00-compile.t
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

done_testing;
