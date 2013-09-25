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
use Moose::Util::TypeConstraints;
use List::MoreUtils 'any';
use namespace::autoclean;

sub mvp_multivalue_args { qw(installer) }

# Note: no support yet for depending on a specific version of the plugin
has installer => (
    isa => 'ArrayRef[Str]',
    lazy => 1,
    default => sub {
        exists $_[0]->payload->{installer}
            ? $_[0]->payload->{installer}
            : [ 'MakeMaker::Fallback', 'ModuleBuildTiny' ];
    },
    traits => ['Array'],
    handles => { installer => 'elements' },
);

has server => (
    is => 'ro', isa => enum([qw(github gitmo p5sagit catagits none)]),
    lazy => 1,
    default => sub {
        exists $_[0]->payload->{server}
            ? $_[0]->payload->{server}
            : 'github';
    },
);

has _requested_version => (
    is => 'ro', isa => 'Str',
    lazy => 1,
    default => sub {
        exists $_[0]->payload->{':version'}
            ? $_[0]->payload->{':version'}
            : '0';
    },
);

my %installer_args = (
    ModuleBuildTiny => { ':version' => '0.004' },
);

around BUILDARGS => sub
{
    my $orig = shift;
    my $self = shift;
    my $args = $self->$orig(@_);

    # remove 'none' from installer list
    return $args if not exists $args->{payload}{installer};
    @{$args->{payload}{installer}} = grep { $_ ne 'none' } @{$args->{payload}{installer}};
    return $args;
};

sub configure
{
    my $self = shift;

    $self->add_plugins(
        # VersionProvider
        [ 'Git::NextVersion'    => { version_regexp => '^v([\d._]+)(-TRIAL)?$' } ],

        # BeforeBuild
        [ 'PromptIfStale' => 'build' => { phase => 'build', module => [ blessed($self) ] } ],
        [ 'PromptIfStale' => 'release' => { phase => 'release', check_all_plugins => 1, check_all_prereqs => 1 } ],

        # ExecFiles, ShareDir
        [ 'ExecDir'             => { dir => 'script' } ],
        'ShareDir',

        # Finders
        [ 'FileFinder::ByName' => Examples => { dir => 'examples' } ],

        # Gather Files
        [ 'Git::GatherDir'      => { exclude_filename => 'LICENSE' } ],
        qw(MetaYAML MetaJSON License Readme Manifest),
        [ 'Test::Compile'       => { ':version' => '2.023', fail_on_warning => 'author', bail_out_on_fail => 1, script_finder => [qw(:ExecFiles @Author::ETHER/Examples)] } ],
        [ 'Test::CheckDeps'     => { fatal => 1, level => 'suggests' } ],
        [ 'Test::NoTabs'        => { script_finder => [qw(:ExecFiles @Author::ETHER/Examples)] } ],
        'EOLTests',
        'MetaTests',
        [ 'Test::Version'       => { is_strict => 1 } ],
        [ 'Test::CPAN::Changes' => { ':version' => '0.008' } ],
        'Test::ChangesHasContent',
        'Test::UnusedVars',
        [ 'Test::MinimumVersion' => { ':version' => '2.000003', max_target_perl => '5.008008' } ],
        'PodSyntaxTests',
        'PodCoverageTests',
        'Test::PodSpelling',
        #[Test::Pod::LinkCheck]     many outstanding bugs
        'Test::Pod::No404s',
        'Test::Kwalitee',
        'MojibakeTests',
        'Test::ReportPrereqs',

        # Prune Files
        'PruneCruft',
        'ManifestSkip',
        # (ReadmeAnyFromPod)

        # Munge Files
        # (Authority)
        'Git::Describe',
        [ PkgVersion            => { ':version' => '4.300036', die_on_existing_version => 1 } ],
        'PodWeaver',
        [ 'NextRelease'         => { ':version' => '4.300018', time_zone => 'UTC', format => '%-8V  %{yyyy-MM-dd HH:mm:ss\'Z\'}d (%U)' } ],

        # MetaData
        $self->server eq 'github' ? ( [ 'GithubMeta' ] ) : (),
        [ 'AutoMetaResources'   => { 'bugtracker.rt' => 1,
              $self->server eq 'gitmo' ? ( 'repository.gitmo' => 1 )
            : $self->server eq 'p5sagit' ? ( 'repository.p5sagit' => 1 )
            : $self->server eq 'catagits' ? ( 'repository.catagits' => 1 )
            : ()
        } ],
        [ 'Authority'           => { authority => 'cpan:ETHER' } ],
        [ 'MetaNoIndex'         => { directory => [ qw(t xt examples) ] } ],
        [ 'MetaProvides::Package' => { meta_noindex => 1 } ],
        'MetaConfig',
        #[ContributorsFromGit]

        # Register Prereqs
        # (MakeMaker or other installer)
        'AutoPrereqs',
        'MinimumPerl',
        [ 'Prereqs' => installer_requirements => {
                '-phase' => 'develop', '-relationship' => 'requires',
                'Dist::Zilla' => Dist::Zilla->VERSION,
                blessed($self) => $self->_requested_version,

                # this is mostly pointless as by the time this runs, we're
                # already trying to load the installer plugin
                ( map {
                    Dist::Zilla::Util->expand_config_package_name($_) =>
                        ($installer_args{$_} // {})->{':version'} // 0
                } $self->installer ),
            } ],

        # Install Tool
        [ 'ReadmeAnyFromPod'    => { type => 'markdown', filename => 'README.md', location => 'root' } ],
        ( map { [ $_ => $installer_args{$_} // () ] } $self->installer ),
        'InstallGuide',

        # After Build
        [ 'CopyFilesFromBuild'  => { copy => 'LICENSE' } ],
        [ 'Run::AfterBuild' => { run => q!if [[ %d =~ %n ]]; then test -e .ackrc && grep -q -- '--ignore-dir=%d' .ackrc || echo '--ignore-dir=%d' >> .ackrc; fi! } ],

        # Test Runner
        'RunExtraTests',

        # Before Release
        [ 'Git::Check'          => { allow_dirty => [ qw(README.md LICENSE) ] } ],
        'Git::CheckFor::MergeConflicts',
        [ 'Git::CheckFor::CorrectBranch' => { ':version' => '0.004', release_branch => 'master' } ],
        [ 'Git::Remote::Check'  => { branch => 'master', remote_branch => 'master' } ],
        'CheckPrereqsIndexed',
        'TestRelease',
        # (ConfirmRelease)

        # Releaser
        'UploadToCPAN',

        # After Release
        [ 'Git::Commit'         => { allow_dirty => [ qw(Changes README.md LICENSE) ], commit_msg => '%N-%v%t%n%n%c' } ],
        [ 'Git::Tag'            => { tag_format => 'v%v%t', tag_message => 'v%v%t' } ],
        $self->server eq 'github' ? ( [ 'GitHub::Update' => { metacpan => 1 } ] ) : (),
        'Git::Push',
        [ 'InstallRelease'      => { install_command => 'cpanm .' } ],

        # listed late, to allow all other plugins which do BeforeRelease checks to run first.
        'ConfirmRelease',
    );

    # check for a bin/ that should probably be renamed to script/
    warn 'bin/ detected - should this be moved to script/, so its contents can be installed into $PATH?'
        if -d 'bin' and any { $_ eq 'ModuleBuildTiny' } $self->installer;
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

    ;;; BeforeBuild
    [PromptIfStale / build]
    phase = build
    module = Dist::Zilla::Plugin::Author::ETHER
    [PromptIfStale / release]
    phase = release
    check_all_plugins = 1
    ; requires :version = 0.004, but we will be checking ourselves)
    check_all_prereqs = 1


    ;;; ExecFiles, ShareDir
    [ExecDir]
    dir = script

    [ShareDir]


    ;;; Gather Files
    [Git::GatherDir]
    exclude_filename = LICENSE

    [MetaYAML]
    [MetaJSON]
    [License]
    [Readme]
    [Manifest]

    [FileFinder::ByName / Examples]
    dir = examples

    [Test::Compile]
    :version = 2.023
    fail_on_warning = author
    bail_out_on_fail = 1
    script_finder = :ExecFiles
    script_finder = Examples

    [Test::CheckDeps]
    fatal = 1
    level = suggests

    [Test::NoTabs]
    script_finder = :ExecFiles
    script_finder = Examples

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
    [Test::Kwalitee]
    [MojibakeTests]


    ;;; Munge Files
    ; (Authority)
    [Git::Describe]
    [PkgVersion]
    :version = 4.300036
    die_on_existing_version = 1

    [PodWeaver]
    [NextRelease]
    :version = 4.300018
    time_zone = UTC
    format = %-8V  %{yyyy-MM-dd HH:mm:ss'Z'}d (%U)


    ;;; MetaData
    [GithubMeta]    ; (if server = 'github' or omitted)
    [AutoMetaResources]
    bugtracker.rt = 1
    ; (plus repository.* = 1 if server = 'gitmo' or 'p5sagit')

    [Authority]
    authority = cpan:ETHER

    [MetaNoIndex]
    directory = t
    directory = xt
    directory = examples

    [MetaProvides::Package]
    meta_noindex = 1

    [MetaConfig]


    ;;; Register Prereqs
    [AutoPrereqs]
    [MinimumPerl]

    [Prereqs / installer_requirements]
    -phase = develop
    -relationship = requires
    Dist::Zilla = <version used to built this bundle>
    Dist::Zilla::PluginBundle::Author::ETHER = <version specified in dist.ini>


    ;;; Install Tool
    [ReadmeAnyFromPod]
    type = markdown
    filename = README.md
    location = root

    <specified installer(s)>
    [InstallGuide]


    ;;; After Build
    [CopyFilesFromBuild]
    copy = LICENSE

    [Run::AfterBuild]
    run => if [[ %d =~ %n ]]; then test -e .ackrc && grep -q -- '--ignore-dir=%d' .ackrc || echo '--ignore-dir=%d' >> .ackrc; fi


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
    branch = master
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

    [GitHub::Update]    ; (if server = 'github' or omitted)
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
many as you'd like), as described in L<Pod::Spell/ADDING STOPWORDS>:

    =for stopwords foo bar baz

=head2 installer

=for stopwords ModuleBuildTiny

The installer back-end(s) to use (can be specified more than once); defaults
to C<MakeMaker::Fallback>
and C<ModuleBuildTiny> (which generates a F<Build.PL> for normal use, and
F<Makefile.PL> as a fallback, containing an upgrade warning).

You can select other backends (by plugin name, without the C<[]>), with the
C<installer> option, or 'none' if you are supplying your own, as a separate
plugin.

Encouraged choices are:

    installer = ModuleBuildTiny
    installer = MakeMaker
    installer = =inc::Foo (if no configs are needed for this plugin)
    installer = none (if you are including your own later on, with configs)

=head2 server

=begin :list

* C<github>
(default)
metadata and release plugins are tailored to L<github|http://github.com>.

* C<gitmo>
metadata and release plugins are tailored to
L<http://git.moose.perl.org|gitmo@git.moose.perl.org>.

* C<p5sagit>
metadata and release plugins are tailored to
L<http://git.shadowcat.co.uk|p5sagit@git.shadowcat.co.uk>.

* C<catagits>
metadata and release plugins are tailored to
L<http://git.shadowcat.co.uk|catagits@git.shadowcat.co.uk>.

* C<none>
no special configuration of metadata (relating to repositories etc) is done --
you'll need to provide this yourself.

=end :list

=head2 other customizations

=for stopwords customizations

This bundle makes use of L<Dist::Zilla::Role::PluginBundle::PluginRemover> and
L<Dist::Zilla::Role::PluginBundle::Config::Slicer> to allow further customization.
Plugins are not loaded until they are actually needed, so it is possible to
C<--force>-install this plugin bundle and C<-remove> some plugins that do not
install or are otherwise problematic.

=head1 NAMING SCHEME

=for stopwords KENTNL

This distribution follows best practices for author-oriented plugin bundles; for more information,
see L<KENTNL's distribution|Dist::Zilla::PluginBundle::Author::KENTNL/NAMING-SCHEME>.

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-PluginBundle-Author-ETHER>
(or L<bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org|mailto:bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=cut
