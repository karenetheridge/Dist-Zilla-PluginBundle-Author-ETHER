use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Test::Fatal;
use Path::Tiny;
use PadWalker 'closed_over';

use lib 't/lib';
use Helper;
use NoNetworkHits;
use NoPrereqChecks;

# load this in advance, as we change directories between configuration and building
use Pod::Weaver::PluginBundle::Author::ETHER;

my $stopwords = qr/^=for stopwords irc\n\n/m;
my $rt = qr{^\QBugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Foo-Bar>\E\s\(or L<bug-Foo-Bar\@rt\.cpan\.org\|mailto:bug-Foo-Bar\@rt\.cpan\.org>\)\.$}m;
my $irc_channel = qr{^There is also an irc channel available for users of this distribution, at\sL<irc://irc\.perl\.org/\#foobar>\.$}m;
my $mailing_list = qr{^There is also a mailing list available for users of this distribution, at\sL<http://foo.org/mailing-list>\.$}m;
my $irc_ether = qr/^I am also usually active on irc, as 'ether' at C<irc.perl.org>\.$/m;

my @tests = (
    map {
        my $authority = $_;
        my @authority_conf = ( [ Authority => { authority => "cpan:$authority" } ] );
        my $extra_pod = $authority eq 'cpan:ETHER' ? qr/\n\n$irc_ether/m : '';
        {
            test_name => "authority = $authority, no metadata",
            config => [
                @authority_conf,
            ],
            pod => qr/^=head1 SUPPORT\n\n$rt$extra_pod/m,
        },
        #{
        #    test_name => 'authority = ETHER, github issues (no email)',
        #    TODO
        #}
        {
            test_name => "authority = $authority, irc channel",
            config => [
                @authority_conf,
                [ MetaResources => { x_IRC => 'irc://irc.perl.org/#foobar' } ],
            ],
            pod => qr/^=head1 SUPPORT\n\n$rt\n\n$irc_channel$extra_pod/m,
        },
        {
            test_name => "authority = $authority, irc and mailing list",
            config => [
                @authority_conf,
                [ MetaResources => { x_IRC => 'irc://irc.perl.org/#foobar', x_MailingList => 'http://foo.org/mailing-list' } ],
            ],
            pod => qr/^=head1 SUPPORT\n\n$rt\n\n$mailing_list\n\n$irc_channel$extra_pod/m,
        },
        {
            test_name => "authority = $authority, custom SUPPORT content",
            config => [
                @authority_conf,
            ],
            extra_content => "\n\n-pod\n\n=head1 SUPPORT\n\nHere is my custom support content\.\n\n=cut\n",
            pod => qr/^=head1 SUPPORT\n\nHere is my custom support content\.\n\n$rt$extra_pod/m,
        },
    }
    qw(ETHER BOB)
);

subtest $_->{test_name} => sub
{
    my $config = $_->{config};
    my $extra_content = $_->{extra_content} // '';
    my $expected_pod = $_->{pod};

    my $tzil = Builder->from_config(
        { dist_root => 'does-not-exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    {   # merge into root section
                        name => 'Foo-Bar',
                        version => '0.005',
                    },
                    'GatherDir',
                    [ '@Author::ETHER' => {
                        '-remove' => [ @REMOVED_PLUGINS, 'Authority' ],
                        installer => 'MakeMaker',
                        'RewriteVersion::Transitional.skip_version_provider' => 1,
                      },
                    ],
                    @$config,
                ),
                path(qw(source lib Foo.pm)) => "package Foo;\n\n1;\n$extra_content",
            },
        },
    );

    assert_no_git($tzil);

    # allow [Authority] to run multiple times without exploding
    undef ${ closed_over(\&Dist::Zilla::Plugin::Authority::metadata)->{'$seen_author'} };

    $tzil->chrome->logger->set_debug(1);
    is(
        exception { $tzil->build },
        undef,
        'build proceeds normally',
    );

    like(
        $tzil->slurp_file('build/lib/Foo.pm'),
        $expected_pod,
        'correct SUPPORT section is woven into pod',
    );

    diag 'got distmeta: ', explain $tzil->distmeta
        if not Test::Builder->new->is_passing;

    diag 'got log messages: ', explain $tzil->log_messages
        if not Test::Builder->new->is_passing;
}
foreach @tests;

done_testing;
