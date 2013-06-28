use strict;
use warnings;
package Dist::Zilla::PluginBundle::Author::ETHER;
# ABSTRACT: A plugin bundle for distributions built by ETHER

use Moose;
with
    'Dist::Zilla::Role::PluginBundle::Easy',
    'Dist::Zilla::Role::PluginBundle::PluginRemover' => { -version => '0.102' },
    'Dist::Zilla::Role::PluginBundle::Config::Slicer';

use Dist::Zilla::Util;
use namespace::autoclean;

# Note: no support yet for depending on a specific version of the plugin
has installer => (
    is => 'ro', isa => 'Str',
    lazy => 1,
    default => sub {
        exists $_[0]->payload->{installer}
            ? $_[0]->payload->{installer}
            : 'ModuleBuildTiny';
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
        qw(MetaYAML MetaJSON License Readme Manifest),
        [ 'Test::Compile'       => { ':version' => '2.002', fail_on_warning => 1, bail_out_on_fail => 1 } ],
        [ 'Test::CheckDeps'     => { ':version' => '0.007', fatal => 1, level => 'suggests' } ],

        'NoTabsTests',
        'EOLTests',
        'MetaTests',
        'Test::Version',
        [ 'Test::CPAN::Changes' => { ':version' => '0.008' } ],
        'Test::ChangesHasContent',
        'Test::UnusedVars',
        [ 'Test::MinimumVersion' => { ':version' => '2.0000003', max_target_perl => '5.008008' } ],
        'PodSyntaxTests',
        'PodCoverageTests',
        'Test::PodSpelling',
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
        [ 'NextRelease'         => { ':version' => '4.300018', format => '%-8V  %{yyyy-MM-dd HH:mm:ss ZZZZ}d (%U)' } ],

        # Register Prereqs
        # (MakeMaker or other installer)
        'AutoPrereqs',
        'MinimumPerl',
        [ 'Prereqs' => installer_requirements => {
                # this is mostly pointless as by the time this runs, we're
                # already trying to load the installer plugin
                '-phase' => 'develop', '-relationship' => 'requires',
                'Dist::Zilla' => Dist::Zilla->VERSION,
                blessed($self) => $self->VERSION,
                $self->installer ne 'none'
                    ? ( Dist::Zilla::Util->expand_config_package_name($self->installer) => 0 )
                    : (),
            } ],

        # Install Tool
        [ 'ReadmeAnyFromPod'    => { type => 'markdown', filename => 'README.md', location => 'root' } ],
        $self->installer ne 'none' ? $self->installer : (),
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
        [ 'GitHub::Update'      => { metacpan => 1 } ],
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

    [Test::Compile]
    fail_on_warning = 1
    bail_out_on_fail = 1

    [Test::CheckDeps]
    :version = 0.007
    fatal = 1
    level = suggests

    [NoTabsTests]
    [EOLTests]
    [MetaTests]
    [Test::Version]
    [Test::CPAN::Changes]
    [Test::ChangesHasContent]
    [Test::UnusedVars]

    [Test::MinimumVersion]
    :version = 2.000003
    max_target_perl = 5.008008

    [PodSyntaxTests]
    [PodCoverageTests]
    [Test::PodSpelling]
    ;[Test::Pod::LinkCheck]     many outstanding bugs
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
    [Prereqs / DevelopRequires]
    Dist::Zilla = <version used to built this bundle>
    Dist::Zilla::PluginBundle::Author::ETHER = <our own version>


    ;;; Install Tool
    [ReadmeAnyFromPod]
    type = markdown
    filename = README.md
    location = root

    <specified installer> or [ModuleBuildTiny]
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

    [GitHub::Update]
    metacpan = 1

    [Git::Push]

    [InstallRelease]
    install_command = cpanm .


    ; listed late, to allow all other plugins which do BeforeRelease checks to run first.
    [ConfirmRelease]


=for Pod::Coverage configure mvp_multivalue_args

=for stopwords metacpan

The distribution's code is assumed to be hosted at L<github|http://github.com>;
L<RT|http://rt.cpan.org> is used as the issue tracker.
The home page in the metadata points to L<github|http://github.com>,
while the home page on L<github|http://github.com> is updated on release to
point to L<metacpan|http://metacpan.org>.
The version and other metadata is derived directly from the local git repository.

=head1 OPTIONS / OVERRIDES

=for stopwords Stopwords

=head2 version

Use C<< V=<version> >> to override the version of the distribution being built;
otherwise the version is
incremented from the last git tag.

=head2 pod coverage

Subs can be considered "covered" for pod coverage tests by adding a directive to pod:

    =for Pod::Coverage foo bar baz

=head2 spelling stopwords

Stopwords for spelling tests can be added by adding a directive to pod (as
many as you'd like), as described in L<Pod::Spelling/ADDING STOPWORDS>:

    =for stopwords foo bar baz

=head2 installer

=for stopwords ModuleBuildTiny

The installer back-end selected by default is (currently)
L<[ModuleBuildTiny]|Dist::Zilla::Plugin::ModuleBuildTiny>.
You can select other backends (by plugin name, without the C<[]>), with the
C<installer> option, or 'none' if you are supplying your own, as a separate
plugin.

Encouraged choices are:

    installer = ModuleBuildTiny
    installer = MakeMaker
    installer = =inc::Foo (if no configs are needed for this plugin)
    installer = none

=head2 other customizations

=for stopwords customizations

This bundle makes use of L<Dist::Zilla::Role::PluginBundle::PluginRemover> and
L<Dist::Zilla::Role::PluginBundle::Config::Slicer> to allow further customization.

=head1 NAMING SCHEME

=for stopwords KENTNL's

This distribution follows best practices for author-oriented plugin bundles; for more information,
see L<KENTNL's distribution|Dist::Zilla::PluginBundle::Author::KENTNL/NAMING-SCHEME>.

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-PluginBundle-Author-ETHER>
(or L<bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org|mailto:bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=cut
