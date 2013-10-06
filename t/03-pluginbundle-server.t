use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::Deep::JSON;
use Test::DZil;
use Path::Tiny;

use Test::Requires qw(
    Dist::Zilla::Plugin::GithubMeta
    Dist::Zilla::Plugin::GitHub::Update
);

use lib 't/lib';
use Helper;

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
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    'GatherDir',
                    # our files are copied into source, so Git::GatherDir doesn't see them
                    # and besides, we would like to run these tests at install time too!
                    [ '@Author::ETHER' => {
                        server => $server,
                        installer => 'MakeMaker',
                        '-remove' => [ 'Git::GatherDir', 'Git::NextVersion', 'Git::Describe', 'PromptIfStale' ],
                      },
                    ],
                ),
                path(qw(source lib MyModule.pm)) => 'package MyModule; 1',
            },
        },
    );

    $tzil->build;

    # check that everything we loaded is in test-requires or run-requires
    all_plugins_are_required($tzil,
        'Dist::Zilla::Plugin::GatherDir',   # used by us here
        'Dist::Zilla::Plugin::MakeMaker',   # via installer option
        'Dist::Zilla::Plugin::GithubMeta',
        'Dist::Zilla::Plugin::GitHub::Update',
    );

    cmp_deeply(
        $tzil->slurp_file('build/META.json'),
        json(superhashof({
            resources => $server_to_resources{$server},
        })),
        'server ' . $server . ': all meta resources are correct',
    );
} }

done_testing;
