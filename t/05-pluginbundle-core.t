use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Test::Fatal;
use Path::Tiny;
use Test::Deep;

use Test::File::ShareDir -share => { -dist => { 'Dist-Zilla-PluginBundle-Author-ETHER' => 'share' } };

use lib 't/lib';
use Helper;
use NoNetworkHits;
use NoPrereqChecks;

# tests the core plugin - with all options disabled

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    'GatherDir',
                    # our files are copied into source, so Git::GatherDir doesn't see them
                    # and besides, we would like to run these tests at install time too!
                    [ '@Author::ETHER' => {
                        '-remove' => [ 'Git::GatherDir', 'Git::NextVersion', 'Git::Describe',
                            'Git::Contributors', 'Git::Check', 'Git::Commit', 'Git::Tag', 'Git::Push',
                            'Git::CheckFor::MergeConflicts', 'Git::CheckFor::CorrectBranch',
                            'Git::Remote::Check', 'PromptIfStale', 'EnsurePrereqsInstalled' ],
                        server => 'none',
                        installer => 'MakeMaker',
                        'RewriteVersion::Transitional.skip_version_provider' => 1,
                      },
                    ],
                ),
                path(qw(source lib MyModule.pm)) => "package MyModule;\n\n1",
            },
        },
    );

    my @git_plugins = grep { $_->meta->name =~ /Git(?!(?:hubMeta|Hub::Update))/ } @{$tzil->plugins};
    cmp_deeply(\@git_plugins, [], 'no git-based plugins are running here');

    $tzil->chrome->logger->set_debug(1);
    is(
        exception { $tzil->build },
        undef,
        'build proceeds normally',
    );

    # check that everything we loaded is properly declared as prereqs
    all_plugins_in_prereqs($tzil,
        exempt => [ 'Dist::Zilla::Plugin::GatherDir' ],     # used by us here
        additional => [ 'Dist::Zilla::Plugin::MakeMaker' ], # via installer option
    );

    ok(!-e "build/$_", "no $_ was created in the dist") foreach qw(Makefile.PL Build.PL);

    diag 'got log messages: ', explain $tzil->log_messages
        if not Test::Builder->new->is_passing;
}

done_testing;
