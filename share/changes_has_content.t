use strict;
use warnings;

use Test::More;
plan skip_all => 'xt/release/changes_has_content.t is missing' if not -e 'xt/release/changes_has_content.t';

if (not $ENV{TRAVIS_PULL_REQUEST}) {
    chomp(my $branch_name = ($ENV{TRAVIS_BRANCH} || `git rev-parse --abbrev-ref HEAD`));
diag 'testing with branch ', ($branch_name || 'undef'), '...';
    $TODO = 'Changes need not have content for this release yet if this is only the master branch'
        if ($branch_name || '') eq 'master';
}
else {
diag 'testing in a pull request.';
}

do './xt/release/changes_has_content.t';
die $@ if $@;
