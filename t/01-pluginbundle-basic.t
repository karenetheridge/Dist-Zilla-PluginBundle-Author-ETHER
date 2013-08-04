use strict;
use warnings FATAL => 'all';

use Test::More;

BEGIN {
    plan skip_all => 'these tests require a git repository' unless -d '.git';
}

use Test::Warnings;
use Test::Deep;
use Test::Deep qw(cmp_details deep_diag);
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
                },
                'GatherDir',
                # Git::GatherDir doesn't understand our corpus structure??
                [ '@Author::ETHER' => { '-remove' => 'Git::GatherDir' } ],
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
    xt/release/distmeta.t
    xt/release/eol.t
    xt/release/minimum-version.t
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

my ($ok, $stack) = cmp_details(
    \@found_files,
    bag(@expected_files),
);

pass('the right files are created') if $ok;

if (not $ok)
{
    # check that the minimum expected files are still created...
    cmp_deeply(
        \@found_files,
        superbagof(@expected_files),
        'the minimum set of expected files are created',
    )
    and
    Test::Builder->new->diag("When checking what files are created in the build...\n"
        . deep_diag($stack));
}

done_testing;
