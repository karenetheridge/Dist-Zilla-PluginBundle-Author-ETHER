use strict;
use warnings;

use Test::More;
plan skip_all => 'xt/release/changes_has_content.t is missing' if not -e 'xt/release/changes_has_content.t';

my $branch_name = $ENV{TRAVIS_BRANCH};

diag '1. testing with branch ', ($branch_name || 'undef'), '...';

chomp($branch_name = `git rev-parse --abbrev-ref HEAD`) if not $branch_name;
$TODO = 'Changes need not have content for this release yet if this is only the master branch'
    if ($branch_name || '') eq 'master';

diag '2. testing with branch ', ($branch_name || 'undef'), '...';

do './xt/release/changes_has_content.t';
die $@ if $@;
