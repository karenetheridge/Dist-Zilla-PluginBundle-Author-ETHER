use strict;
use warnings;
package Dist::Zilla::PluginBundle::Author::ETHER;
# ABSTRACT: A plugin bundle for distributions built by ETHER

use Moose;
with
    'Dist::Zilla::Role::PluginBundle::Easy',
    'Dist::Zilla::Role::PluginBundle::Config::Slicer';

sub mvp_multivalue_args { qw(stopwords) }

has stopwords => (
    is => 'ro', isa => 'ArrayRef',
    lazy => 1,
    default => sub {
        exists $_[0]->payload->{stopwords} ? $_[0]->payload->{stopwords} : [];
    },
);

sub configure
{
    my $self = shift;

    $self->add_plugins(
        # VersionProvider
        [ 'Git::NextVersion'    => { version_regexp => '^v([\d._]+)(-TRIAL)?$' } ],

        # MetaData
        'GithubMeta',
        [ 'AutoMetaResources'   => { 'bugtracker.rt' => 1 } ],
        [ 'Authority'           => { authority => 'cpan:ETHER' } ],
        [ 'MetaNoIndex'         => { directory => [ qw(t xt examples) ] } ],
        [ 'MetaProvides::Package' => { meta_noindex => 1 } ],
        'MetaConfig',
        #[ContributorsFromGit]

        # ExecFiles, ShareDir
        'ExecDir',
        'ShareDir',

        # Gather Files
        [ 'Git::GatherDir'      => { exclude_filename => 'LICENSE' } ],
        (map { [ $_ ] } qw(MetaYAML MetaJSON License Readme Manifest)),
        [ 'Test::Compile'       => { fail_on_warning => 1, bail_out_on_fail => 1 } ],
        [ 'Test::CheckDeps'     => { fatal => 1 } ],
        'NoTabsTests',
        'EOLTests',
        'MetaTests',
        'Test::Version',
        'Test::CPAN::Changes',
        'Test::ChangesHasContent',
        [ 'Test::MinimumVersion' => { max_target_perl => '5.008008' } ],
        'PodSyntaxTests',
        'PodCoverageTests',
        [ 'Test::PodSpelling'   => { stopwords => $self->stopwords } ],
        #[Test::Pod::LinkCheck]     many outstanding bugs
        'Test::Pod::No404s',

        # Prune Files
        'PruneCruft',
        'ManifestSkip',
        # (ReadmeAnyFromPod)

        # Munge Files
        # (Authority)
        'Git::Describe',
        'PkgVersion',
        'PodWeaver',
        #[%PodWeaver]
        [ 'NextRelease'         => { format => '%-8V  %{yyyy-MM-dd HH:mm:ss ZZZZ}d (%U)' } ],

        # Register Prereqs
        # (MakeMaker)
        'AutoPrereqs',
        'MinimumPerl',

        # Install Tool
        [ 'ReadmeAnyFromPod'    => { type => 'markdown', filename => 'README.md', location => 'root' } ],
        'MakeMaker',
        'InstallGuide',

        # After Build
        [ 'CopyFilesFromBuild'  => { copy => 'LICENSE' } ],

        # Test Runner
        'RunExtraTests',

        # Before Release
        [ 'Git::Check'          => { allow_dirty => [ qw(README.md LICENSE) ] } ],
        'Git::CheckFor::MergeConflicts',
        [ 'Git::CheckFor::CorrectBranch' => { release_branch => 'master' } ],
        [ 'Git::Remote::Check'  => { remote_branch => 'master' } ],
        'CheckPrereqsIndexed',
        'TestRelease',
        # (ConfirmRelease)

        # Releaser
        'UploadToCPAN',

        # After Release
        [ 'Git::Commit'         => { allow_dirty => [ qw(Changes README.md LICENSE) ], commit_msg => '%N-%v%t%n%n%c' } ],
        [ 'Git::Tag'            => { tag_format => 'v%v%t', tag_message => 'v%v%t' } ],
        'Git::Push',
        [ 'InstallRelease'      => { install_command => 'cpanm .' } ],

        # listed late, to allow all other plugins which do BeforeRelease checks to run first.
        'ConfirmRelease',
    );
}

__PACKAGE__->meta->make_immutable;
__END__

=pod

=head1 SYNOPSIS

In C<dist.ini>:

    [@Author::ETHER]

=head1 DESCRIPTION

This is a L<Dist::Zilla> plugin bundle. It is approximately equivalent to the
following C<dist.ini> (following the preamble):

    ;;; VersionProvider
    [Git::NextVersion]
    version_regexp = ^v([\d._]+)(-TRIAL)?$


    ;;; MetaData
    [GithubMeta]
    [AutoMetaResources]
    bugtracker.rt = 1

    [Authority]
    authority = cpan:ETHER

    [MetaNoIndex]
    directory = t
    directory = xt
    directory = examples

    [MetaProvides::Package]
    meta_noindex = 1

    [MetaConfig]


    ;;; ExecFiles, ShareDir
    [ExecDir]
    [ShareDir]


    ;;; Gather Files
    [Git::GatherDir]
    exclude_filename = LICENSE

    [MetaYAML]
    [MetaJSON]
    [License]
    [Readme]
    [Manifest]

    [GatherDir::Template / profile.ini]
    root   = profiles/github/build_templates
    prefix = profiles/github

    [Test::Compile]
    fail_on_warning = 1
    bail_out_on_fail = 1

    [Test::CheckDeps]
    :version = 0.005
    fatal = 1

    [NoTabsTests]
    [EOLTests]
    [MetaTests]
    [Test::CPAN::Changes]
    [Test::ChangesHasContent]
    [Test::Version]

    [Test::MinimumVersion]
    :version = 2.000003
    max_target_perl = 5.008008

    [PodSyntaxTests]
    [PodCoverageTests]
    [Test::PodSpelling]
    [Test::Pod::No404s]


    ;;; Munge Files
    ; (Authority)
    [Git::Describe]
    [PkgVersion]
    [PodWeaver]
    [NextRelease]
    :version = 4.300018
    format = %-8V  %{yyyy-MM-dd HH:mm:ss ZZZZ}d (%U)


    ;;; Register Prereqs
    [AutoPrereqs]
    [MinimumPerl]


    ;;; Install Tool
    [ReadmeAnyFromPod]
    type = markdown
    filename = README.md
    location = root

    [MakeMaker]
    [InstallGuide]


    ;;; After Build
    [CopyFilesFromBuild]
    copy = LICENSE


    ;;; TestRunner
    [RunExtraTests]


    ;;; Before Release
    [Git::Check]
    allow_dirty = README.md
    allow_dirty = LICENSE

    [Git::CheckFor::MergeConflicts]

    [Git::CheckFor::CorrectBranch]
    :version = 0.004
    release_branch = master

    [Git::Remote::Check]
    remote_branch = master

    [CheckPrereqsIndexed]
    [TestRelease]
    ;(ConfirmRelease)


    ;;; Releaser
    [UploadToCPAN]


    ;;; AfterRelease
    [Git::Commit]
    allow_dirty = Changes
    allow_dirty = README.md
    allow_dirty = LICENSE
    commit_msg = %N-%v%t%n%n%c

    [Git::Tag]
    tag_format = v%v%t
    tag_message = v%v%t

    [Git::Push]

    [InstallRelease]
    install_command = cpanm .


    ; listed late, to allow all other plugins which do BeforeRelease checks to run first.
    [ConfirmRelease]


=for Pod::Coverage configure mvp_multivalue_args

The distribution's code is assumed to be hosted at github; the version and
other metadata is derived directly from the local git repository.

=head1 OPTIONS / OVERRIDES

Use V=<version> to override the version of the distribution being built; otherwise the version is
incremented from the last git tag.

Subs can be considered "covered" for pod coverage tests by adding a directive to pod:

    =for Pod::Coverage foo bar baz

Stopwords for spelling tests can be added with the C<dist.ini> option:

    stopwords = foo
    stopwords = bar

=head1 NAMING SCHEME

This distribution follows best practices for author-oriented plugin bundles; for more information,
see L<KENTNL's distribution|Dist::Zilla::PluginBundle::Author::KENTNL/NAMING-SCHEME>.

=head1 SUPPORT

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-PluginBundle-Author-ETHER>
(or L<mailto:bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=cut
