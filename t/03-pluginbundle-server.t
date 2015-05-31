use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use Test::Fatal;
use Path::Tiny;

use Test::Requires {
    'Dist::Zilla::Plugin::GithubMeta' => 0,
    'Dist::Zilla::Plugin::GitHub::Update' => '0.40',
};

use Test::File::ShareDir -share => { -dist => { 'Dist-Zilla-PluginBundle-Author-ETHER' => 'share' } };

use lib 't/lib';
use Helper;
use NoNetworkHits;
use NoPrereqChecks;

# this data should be constant across all server types
my %bugtracker = (
    bugtracker => {
        mailto => 'bug-DZT-Sample@rt.cpan.org',
        web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=DZT-Sample',
    },
);

my %server_to_resources = (
    github => {
        %bugtracker,
        homepage => 'https://github.com/karenetheridge/Dist-Zilla-PluginBundle-Author-ETHER',
        repository => {
            type => 'git',
            # note that we use use .git/config in the local repo!
            url => 'https://github.com/karenetheridge/Dist-Zilla-PluginBundle-Author-ETHER.git',
            web => 'https://github.com/karenetheridge/Dist-Zilla-PluginBundle-Author-ETHER',
        },
    },
    gitmo => {
        %bugtracker,
        # no homepage set
        repository => {
            type => 'git',
            url => 'git://git.moose.perl.org/DZT-Sample.git',
            web => 'http://git.shadowcat.co.uk/gitweb/gitweb.cgi?p=gitmo/DZT-Sample.git;a=summary',
        },
    },
    ( map {
        $_ => {
            %bugtracker,
            # no homepage set
            repository => {
                type => 'git',
                url => 'git://git.shadowcat.co.uk/' . $_ . '/DZT-Sample.git',
                web => 'http://git.shadowcat.co.uk/gitweb/gitweb.cgi?p=' . $_ . '/DZT-Sample.git;a=summary',
            },
        },
    } qw(p5sagit catagits)),
);

foreach my $server (keys %server_to_resources)
{ SKIP: {
    skip('can only test server=github when in the local git repository', 1)
        if $server eq 'github' and not (-d '.git' or -d '../../.git' or -d '../../../.git');

    my $tzil = Builder->from_config(
        { dist_root => 'does-not-exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    'GatherDir',
                    [ '@Author::ETHER' => {
                        server => $server,
                        installer => 'MakeMaker',
                        '-remove' =>  \@REMOVED_PLUGINS,
                        'RewriteVersion::Transitional.skip_version_provider' => 1,
                      },
                    ],
                ),
                path(qw(source lib MyModule.pm)) => "package MyModule;\n\n1",
            },
        },
    );

    assert_no_git($tzil);

    $tzil->chrome->logger->set_debug(1);
    is(
        exception { $tzil->build },
        undef,
        'build proceeds normally',
    );

    # check that everything we loaded is properly declared as prereqs
    all_plugins_in_prereqs($tzil,
        exempt => [ 'Dist::Zilla::Plugin::GatherDir' ],     # used by us here
        additional => [
            'Dist::Zilla::Plugin::MakeMaker',       # via installer option
            'Dist::Zilla::Plugin::GithubMeta',      # via server option
            'Dist::Zilla::Plugin::GitHub::Update',
        ],
    );

    cmp_deeply(
        $tzil->distmeta,
        superhashof({
            resources => $server_to_resources{$server},
        }),
        'server ' . $server . ': all meta resources are correct',
    ) or diag 'got distmeta: ', explain $tzil->distmeta;

    diag 'got log messages: ', explain $tzil->log_messages
        if not Test::Builder->new->is_passing;
} }

done_testing;
