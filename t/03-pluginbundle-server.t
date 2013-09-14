use strict;
use warnings FATAL => 'all';

use Test::More;
use JSON;
use if $ENV{AUTHOR_TESTING} || $ENV{AUTOMATED_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use File::Find;
use File::Spec;

# this data should be constant across all server types
my %bugtracker = (
    bugtracker => {
        mailto => 'bug-NoOptions@rt.cpan.org',
        web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=NoOptions',
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
            url => 'git://git.moose.perl.org/NoOptions.git',
            web => 'http://git.shadowcat.co.uk/gitweb/gitweb.cgi?p=gitmo/NoOptions.git;a=summary',
        },
    },
    ( map {
        $_ => {
            %bugtracker,
            # no homepage set
            repository => {
                type => 'git',
                url => 'git://git.shadowcat.co.uk/' . $_ . '/NoOptions.git',
                web => 'http://git.shadowcat.co.uk/gitweb/gitweb.cgi?p=' . $_ . '/NoOptions.git;a=summary',
            },
        },
    } qw(p5sagit catagits)),
);

foreach my $server (keys %server_to_resources)
{ SKIP: {
    skip('can only test server=github when in the local git repository', 1)
        if $server eq 'github' and not (-d '.git' or -d '../../.git' or -d '../../../.git');

    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/dist/no_options' },
        {
            add_files => {
                'source/dist.ini' => dist_ini(
                    {
                        name    => 'NoOptions',
                        author  => 'E. Xavier Ample <example@example.org>',
                        copyright_holder => 'E. Xavier Ample',
                        copyright_year => '2013',
                        license => 'Perl_5',
                        version => '1.0',
                    },
                    'GatherDir',
                    # our files are copied into source, so Git::GatherDir doesn't see them
                    # and besides, we would like to run these tests at install time too!
                    [ '@Author::ETHER' => {
                        server => $server,
                        '-remove' => [ 'Git::GatherDir', 'Git::NextVersion', 'PromptIfStale' ],
                      },
                    ],
                ),
            },
        },
    );

    $tzil->build;

    my $json = $tzil->slurp_file('build/META.json');
    my $meta = JSON->new->decode($json);

    cmp_deeply(
        $meta->{resources},
        $server_to_resources{$server},
        'server ' . $server . ': all meta resources are correct',
    );
} }

done_testing;
