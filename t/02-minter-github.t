use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use Path::Class;
use Path::Tiny;
use File::Find;
use File::Spec;
use Moose::Util 'find_meta';

# we need the profiles dir to have gone through file munging first (for
# profile.ini), as well as get installed into a sharedir
plan skip_all => 'this test requires a built dist'
    unless -d 'blib/lib/auto/share/dist/Dist-Zilla-PluginBundle-Author-ETHER/profiles';

my $tzil = Minter->_new_from_profile(
    [ 'Author::ETHER' => 'github' ],
    { name => 'My-New-Dist', },
    { global_config_root => dir('t/corpus/global')->absolute }, # sadly, this must quack like a Path::Class
);

# we need to stop the git plugins from doing their thing
foreach my $plugin (grep { /Git/ } map { ref } @{$tzil->plugins})
{
    next unless $plugin->can('after_mint');
    my $meta = find_meta($plugin);
    $meta->make_mutable;
    $meta->add_around_method_modifier(after_mint => sub { Test::More::note("in $plugin after_mint...") });
}

$tzil->mint_dist;
my $mint_dir = path($tzil->tempdir)->child('mint');

my @expected_files = qw(
    .gitignore
    Changes
    dist.ini
    CONTRIBUTING
    LICENSE
    README.md
    weaver.ini
    lib/My/New/Dist.pm
    t/01-basic.t
    xt/release/clean-namespaces.t
);

my @found_files;
find({
        wanted => sub {
            my $file = File::Spec->abs2rel($_, $mint_dir);
            return $File::Find::prune = 1 if $file eq '.git';
            push @found_files, $file if -f;     # ignore directories
        },
        no_chdir => 1,
     },
    $mint_dir,
);

cmp_deeply(
    \@found_files,
    bag(@expected_files),
    'the correct files are created',
);

like(
    path($mint_dir, 'lib/My/New/Dist.pm')->slurp_utf8,
    qr/^use strict;\nuse warnings;\npackage My::New::Dist;/m,
    'our new module has a valid package declaration',
);

like(
    path($mint_dir, 'dist.ini')->slurp_utf8,
    qr/\[\@Author::ETHER\]/,
    'plugin bundle is referenced in dist.ini',
);

like(
    path($mint_dir, '.gitignore')->slurp_utf8,
    qr'^/My-New-Dist-\*/$'ms,
    '.gitignore file is created properly, with dist name correctly inserted',
);

is(
    path($mint_dir, 'Changes')->slurp_utf8,
    <<'STRING',
Revision history for {{$dist->name}}

{{$NEXT}}
          - Initial release.
STRING
    'Changes file is created properly, with templates and whitespace preserved',
);

like(
    path($mint_dir, 'xt/release/clean-namespaces.t')->slurp_utf8,
    qr{namespaces_clean\(grep { !/\^My::New::Dist::Conflicts\$/ } Test::CleanNamespaces->find_modules\);}m,
    'Test::CleanNamespaces skips the ::Conflicts module',
);

done_testing;
