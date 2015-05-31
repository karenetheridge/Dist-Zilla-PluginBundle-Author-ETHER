use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Test::Fatal;
use Path::Tiny;

# load this in advance, as we change directories between configuration and building
use Pod::Weaver::PluginBundle::Author::ETHER;

{
    package MyContributors;
    use Moose;
    with 'Dist::Zilla::Role::MetaProvider';
    sub metadata { +{ x_contributors => [ 'Anon Y. Moose <anon@null.com>' ] } }
}

{
    my $tzil = Builder->from_config(
        { dist_root => 'does-not-exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    'GatherDir',
                    '=MyContributors',
                    [ PodWeaver => { config_plugin => '@Author::ETHER' } ],
                ),
                path(qw(source lib Foo.pm)) => <<FOO,
package Foo;
# ABSTRACT: Hello, this is foo

1;
=pod

=cut
FOO
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);
    is(
        exception { $tzil->build },
        undef,
        'build proceeds normally',
    );

    my $module = $tzil->slurp_file('build/lib/Foo.pm');
    my $version = $tzil->version;

    isnt(index($module, <<POD), -1, 'module has woven the encoding, NAME and VERSION sections into pod');
=pod

=encoding UTF-8

=head1 NAME

Foo - Hello, this is foo

=head1 VERSION

version $version

POD

    like($module, qr/^=head1 AUTHOR\n\n/m, 'module has woven the AUTHOR section into pod');

    like($module, qr/^=head1 CONTRIBUTOR\n\n.*Anon Y. Moose <anon\@null.com>\n\n/ms, 'module has woven the CONTRIBUTOR section into pod');

    diag 'got log messages: ', explain $tzil->log_messages
        if not Test::Builder->new->is_passing;
}

done_testing;
