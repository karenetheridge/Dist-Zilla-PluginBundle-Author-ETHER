use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Warnings;
use Test::Deep;
use Test::DZil;
use Path::Class;
use File::Find;
use File::Spec;
use Moose::Util 'find_meta';

# we need the profiles dir to have gone through file munging first (for
# profile.ini)
plan skip_all => 'this test requires a built dist' unless -d 'blib/lib/auto/share/module';

my $tzil = Minter->_new_from_profile(
    [ 'Author::ETHER' => 'github' ],
    { name => 'My-New-Dist', },
    { global_config_root => dir('t/corpus/global')->absolute },
);

# we need to stop the git plugins from doing their thing
foreach my $plugin (grep { /Git/ } map { ref } @{$tzil->plugins})
{
    my $meta = find_meta($plugin);
    $meta->make_mutable;
    $meta->add_around_method_modifier(after_mint => sub { Test::More::note("in $plugin after_mint...") });
}

$tzil->mint_dist;
my $mint_dir = $tzil->tempdir->subdir('mint');

my @expected_files = qw(
    .gitignore
    Changes
    dist.ini
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
    $tzil->slurp_file('mint/lib/My/New/Dist.pm'),
    qr/^use strict;\nuse warnings;\npackage My::New::Dist;/m,
    'our new module has a valid package declaration',
);

like(
    $tzil->slurp_file('mint/dist.ini'),
    qr/\[\@Author::ETHER\]/,
    'plugin bundle is referenced in dist.ini',
);

like(
    $tzil->slurp_file('mint/xt/release/clean-namespaces.t'),
    qr{namespaces_clean\(grep { !/\^My::New::Dist::Conflicts\$/ } Test::CleanNamespaces->find_modules\);}m,
    'Test::CleanNamespaces skips the ::Conflicts module',
);

done_testing;
