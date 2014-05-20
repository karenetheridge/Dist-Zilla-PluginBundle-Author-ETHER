use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
{{
    ($zilla_plugin) = ($dist->name =~ /^Dist-Zilla-Plugin-(.+)$/g);
    $zilla_plugin //= '';
    $zilla_plugin =~ s/-/::/g;

    $zilla_plugin
        ? <<PLUGIN
use Test::DZil;
use Test::Fatal;
use Path::Tiny;

my \$tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ GatherDir => ],
                [ '$zilla_plugin' => ... ],
            ),
            path(qw(source lib Foo.pm)) => "package Foo;\\n1;\\n",
        },
    },
);

\$tzil->chrome->logger->set_debug(1);
is(
    exception { \$tzil->build },
    undef,
    'build proceeds normally',
) or diag 'saw log messages: ', explain \$tzil->log_messages;
PLUGIN
        : 'use ' . $dist->name =~ s/-/::/gr . ';'
            . "\n\nfail('this test is TODO!');"
}}
done_testing;
