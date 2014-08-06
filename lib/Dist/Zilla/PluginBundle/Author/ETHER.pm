use strict;
use warnings;
package Dist::Zilla::PluginBundle::Author::ETHER;
# ABSTRACT: A plugin bundle for distributions built by ETHER
# KEYWORDS: author bundle distribution tool
# vim: set ts=8 sw=4 tw=78 et :

use Moose;
with
    'Dist::Zilla::Role::PluginBundle::Easy',
    'Dist::Zilla::Role::PluginBundle::PluginRemover' => { -version => '0.102' },
    'Dist::Zilla::Role::PluginBundle::Config::Slicer';

use Dist::Zilla::Util;
use Moose::Util::TypeConstraints;
use List::Util qw(first any);
use Module::Runtime 'require_module';
use Devel::CheckBin;
use Dist::Zilla::Plugin::ReadmeAnyFromPod;  # temporary
use Path::Tiny;
use namespace::autoclean;

sub mvp_multivalue_args { qw(installer copy_file_from_release) }

# Note: no support yet for depending on a specific version of the plugin --
# but [PromptIfStale] generally makes that unnecessary
has installer => (
    isa => 'ArrayRef[Str]',
    lazy => 1,
    default => sub {
        $_[0]->payload->{installer} // [ 'MakeMaker::Fallback', 'ModuleBuildTiny::Fallback' ];
    },
    traits => ['Array'],
    handles => { installer => 'elements' },
);

has server => (
    is => 'ro', isa => enum([qw(github gitmo p5sagit catagits none)]),
    lazy => 1,
    default => sub { $_[0]->payload->{server} // 'github' },
);

has surgical_podweaver => (
    is => 'ro', isa => 'Bool',
    lazy => 1,
    default => sub { $_[0]->payload->{surgical_podweaver} // 0 },
);

has airplane => (
    is => 'ro', isa => 'Bool',
    lazy => 1,
    default => sub { $ENV{DZIL_AIRPLANE} // $_[0]->payload->{airplane} // 0 },
);

has copy_file_from_release => (
    isa => 'ArrayRef[Str]',
    lazy => 1,
    default => sub {
        $_[0]->payload->{copy_file_from_release}
            // [
                qw(LICENSE CONTRIBUTING),
                (Dist::Zilla::Plugin::ReadmeAnyFromPod->VERSION < 0.142180 ? 'README.pod' : ())
               ];
    },
    traits => ['Array'],
    handles => { copy_files_from_release => 'elements' },
);

# configs are applied when plugins match ->isa($key) or ->does($key)
my %extra_args = (
    'Dist::Zilla::Plugin::ModuleBuildTiny' => { ':version' => '0.004' },
    'Dist::Zilla::Plugin::MakeMaker::Fallback' => { ':version' => '0.008' },
    # default_jobs is no-op until Dist::Zilla 5.014
    'Dist::Zilla::Role::TestRunner' => { default_jobs => 9 },
    'Dist::Zilla::Plugin::ModuleBuild' => { mb_version => '0.28' },
    'Dist::Zilla::Plugin::ModuleBuildTiny::Fallback' => { ':version' => '0.005' },
);

# plugins that use the network when they run
my @network_plugins = qw(
    PromptIfStale
    Test::Pod::LinkCheck
    Test::Pod::No404s
    Git::Remote::Check
    CheckPrereqsIndexed
    CheckIssues
    UploadToCPAN
    Git::Push
);
my %network_plugins;
@network_plugins{ map { Dist::Zilla::Util->expand_config_package_name($_) } @network_plugins } = () x @network_plugins;

my $has_bash = can_run('bash');

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

    warn 'no "bash" executable found; skipping Run::AfterBuild commands to update .ackrc and .latest symlink', "\n"
        if not $has_bash;

    my $has_xs =()= glob('*.xs');
    warn "XS-based distribution detected.\n" if $has_xs;
    die "no Makefile.PL found in the repository root: this is not very nice for contributors!\n"
        if $has_xs and not -e 'Makefile.PL';

    my %plugin_versions;

    my @plugins = (
        # VersionProvider
        [ 'Git::NextVersion'    => { version_regexp => '^v([\d._]+)(-TRIAL)?$' } ],

        # BeforeBuild
        # [ 'EnsurePrereqsInstalled' ], # FIXME: use options to make this less annoying!
        [ 'PromptIfStale' => 'stale modules, build' => { phase => 'build', module => [ $self->meta->name ] } ],
        [ 'PromptIfStale' => 'stale modules, release' => { phase => 'release', check_all_plugins => 1, check_all_prereqs => 1 } ],

        # ExecFiles, ShareDir
        [ 'ExecDir'             => { dir => 'script' } ],
        'ShareDir',

        # Finders
        [ 'FileFinder::ByName'  => Examples => { dir => 'examples' } ],
        [ 'FileFinder::ByName'  => ExtraTestFiles => { dir => 'xt' } ],

        # Gather Files
        [ 'Git::GatherDir'      => { ':version' => '2.016', exclude_filename => [ ($has_xs ? 'Makefile.PL' : ()), 'README.md', 'README.pod', $self->copy_files_from_release ] } ],
        qw(MetaYAML MetaJSON License Readme Manifest),
        [ 'GenerateFile::ShareDir' => 'generate CONTRIBUTING' => { -dist => 'Dist-Zilla-PluginBundle-Author-ETHER', -filename => 'CONTRIBUTING', has_xs => $has_xs } ],

        [ 'Test::Compile'       => { ':version' => '2.039', bail_out_on_fail => 1, xt_mode => 1,
            script_finder => [qw(:ExecFiles @Author::ETHER/Examples)] } ],
        [ 'Test::NoTabs'        => { 'version' => '0.08', finder => [qw(:InstallModules :ExecFiles @Author::ETHER/Examples :TestFiles @Author::ETHER/ExtraTestFiles)] } ],
        'EOLTests',
        'MetaTests',
        [ 'Test::CPAN::Changes' => { ':version' => '0.008' } ],
        'Test::ChangesHasContent',
        [ 'Test::MinimumVersion' => { ':version' => '2.000003', max_target_perl => '5.008001' } ],
        'PodSyntaxTests',
        'PodCoverageTests',
        'Test::PodSpelling',
        #[Test::Pod::LinkCheck]     many outstanding bugs
        'Test::Pod::No404s',
        'Test::Kwalitee',
        'MojibakeTests',
        [ 'Test::ReportPrereqs' => { verify_prereqs => 1 } ],
        'Test::Portability',


        # Munge Files
        'Git::Describe',
        [ PkgVersion            => { ':version' => '5.010', die_on_existing_version => 1, die_on_line_insertion => 1 } ],
        [ 'Authority'           => { authority => 'cpan:ETHER' } ],
        [
            ($self->surgical_podweaver ? 'SurgicalPodWeaver' : 'PodWeaver') => {
                replacer => 'replace_with_comment',
                post_code_replacer => 'replace_with_nothing',
            }
        ],
        [ 'NextRelease'         => { ':version' => '4.300018', time_zone => 'UTC', format => '%-8v  %{yyyy-MM-dd HH:mm:ss\'Z\'}d%{ (TRIAL RELEASE)}T' } ],
        [ 'ReadmeAnyFromPod'    => { type => 'pod',
                                     (Dist::Zilla::Plugin::ReadmeAnyFromPod->VERSION < 0.142180
                                        ? ( location => 'build' )
                                        : ( location => 'root', phase => 'release' ))
                                   } ],

        # MetaData
        $self->server eq 'github'
            ? ( 'GithubMeta', do { $plugin_versions{'Dist::Zilla::Plugin::GithubMeta'} = 0; () }) : (),
        [ 'AutoMetaResources'   => { 'bugtracker.rt' => 1,
              $self->server eq 'gitmo' ? ( 'repository.gitmo' => 1 )
            : $self->server eq 'p5sagit' ? ( 'repository.p5sagit' => 1 )
            : $self->server eq 'catagits' ? ( 'repository.catagits' => 1 )
            : ()
        } ],
        # (Authority)
        [ 'MetaNoIndex'         => { directory => [ qw(t xt), grep { -d } qw(inc local perl5 fatlib examples share corpus) ] } ],
        [ 'MetaProvides::Package' => { meta_noindex => 1, ':version' => '1.15000002', finder => ':InstallModules' } ],
        'MetaConfig',
        [ 'Keywords'            => { ':version' => '0.004' } ],
        [ 'Git::Contributors'   => { ':version' => '0.002' } ],

        # Register Prereqs
        # (MakeMaker or other installer)
        'AutoPrereqs',
        'Prereqs::AuthorDeps',
        'MinimumPerl',
        [ 'Prereqs' => pluginbundle_version => {
                '-phase' => 'develop', '-relationship' => 'recommends',
                $self->meta->name => $self->VERSION,
            } ],
        ($self->surgical_podweaver ? [ 'Prereqs' => pod_weaving => {
                '-phase' => 'develop', '-relationship' => 'requires',
                'Dist::Zilla::Plugin::SurgicalPodWeaver' => 0
            } ] : ()),

        # Install Tool (some are also Test Runners)
        (map { [ $_ => { ':version' => 0 } ] }
            $self->installer), # ensure an entry in develop prereqs
        'InstallGuide',

        # Test Runners
        [ 'RunExtraTests'       => { ':version' => '0.019' } ],

        # After Build
        'CheckSelfDependency',

        ( $has_bash ?
            [ 'Run::AfterBuild' => { run => q{bash -c "if [[ `dirname %d` != .build ]]; then test -e .ackrc && grep -q -- '--ignore-dir=%d' .ackrc || echo '--ignore-dir=%d' >> .ackrc; fi; if [[ %d =~ ^%n-[.[:xdigit:]]+$ ]]; then rm -f .latest; ln -s %d .latest; fi"} } ]
            : ()),

        # Before Release
        [ 'CheckStrictVersion'  => { decimal_only => 1 } ],
        [ 'Git::Check'          => 'initial check' => { allow_dirty => [''] } ],
        'Git::CheckFor::MergeConflicts',
        [ 'Git::CheckFor::CorrectBranch' => { ':version' => '0.004', release_branch => 'master' } ],
        [ 'Git::Remote::Check'  => { branch => 'master', remote_branch => 'master' } ],
        'CheckPrereqsIndexed',
        'TestRelease',
        [ 'Git::Check'          => 'after tests' => { allow_dirty => [''] } ],
        [ 'CheckIssues' ],
        # (ConfirmRelease)

        # Releaser
        'UploadToCPAN',

        # After Release
        [ 'CopyFilesFromRelease' => { filename => [ $self->copy_files_from_release ] } ],
        [ 'Run::AfterRelease'   => 'remove old READMEs' => { run => 'rm -f README.md' } ],
        [ 'Git::Commit'         => { ':version' => '2.020', add_files_in => ['.'], allow_dirty => [ 'Changes', 'README.md', 'README.pod', $self->copy_files_from_release ], commit_msg => '%N-%v%t%n%n%c' } ],
        [ 'Git::Tag'            => { tag_format => 'v%v%t', tag_message => 'v%v%t' } ],
        $self->server eq 'github' ? (
            [ 'GitHub::Update'  => { metacpan => 1 } ],
            do { $plugin_versions{'Dist::Zilla::Plugin::GitHub::Update'} = 0; () },
        ) : (),
        'Git::Push',
    );

    # install with an author-specific URL from PAUSE, so cpanm-reporter knows where to submit the report
    # hopefully the file is available at this location soonish after release!
    my ($username, $password) = $self->_pause_config;
    push @plugins,
        [ 'Run::AfterRelease' => 'install release' => { run => 'cpanm http://' . $username . ':' . $password . '@pause.perl.org/pub/PAUSE/authors/id/' . substr($username, 0, 1).'/'.substr($username,0,2).'/'.$username.'/%a' } ] if $username and $password;

    if ($self->airplane)
    {
        warn "building in airplane mode - plugins requiring the network are skipped, and releases are not permitted\n";
        @plugins = grep {
            my $plugin = Dist::Zilla::Util->expand_config_package_name(
                !ref($_) ? $_ : ref eq 'ARRAY' ? $_->[0] : die 'wtf'
            );
            not grep { $_ eq $plugin }
            map { Dist::Zilla::Util->expand_config_package_name($_) }
            @network_plugins;
        } @plugins;

        # allow our uncommitted dist.ini edit which sets 'airplane = 1'
        push @{( first { ref eq 'ARRAY' && $_->[0] eq 'Git::Check' } @plugins )->[-1]{allow_dirty}}, 'dist.ini';

        $plugin_versions{'Dist::Zilla::Plugin::BlockRelease'} = 0;

        # halt release after pre-release checks, but before ConfirmRelease
        push @plugins, 'BlockRelease';
    }

    push @plugins, (
        # listed late, to allow all other plugins which do BeforeRelease checks to run first.
        'ConfirmRelease',
    );

    push @plugins, (
        # listed last, to be sure we run at the very end of each phase
        [ 'VerifyPhases' => 'PHASE VERIFICATION' ],
    ) if ($ENV{USER} // '') eq 'ether';

    foreach my $plugin_spec (@plugins)
    {
        next if not ref $plugin_spec or @$plugin_spec == 1;             # 'Foo' or [ 'Foo' ]
        next if @$plugin_spec == 2 and not ref $plugin_spec->[1];       # [ 'Foo' => 'Bar' ]

        my $plugin = Dist::Zilla::Util->expand_config_package_name($plugin_spec->[0]);
        require_module($plugin);
        my $payload = $plugin_spec->[-1];

        if (my @keys = grep { $plugin->isa($_) or $plugin->does($_) } keys %extra_args)
        {
            # combine all the relevant configs together
            my %configs = map { %{ $extra_args{$_} } } @keys;

            # and add to the payload of this plugin
            @{$payload}{keys %configs} = values %configs;
        }

        # also grab :version
        $plugin_versions{$plugin} = $payload->{':version'} if exists $payload->{':version'};
    }

    # ensure that additional optional plugins are declared in prereqs
    push @plugins,
        [ 'Prereqs' => bundle_options =>
            { '-phase' => 'develop', '-relationship' => 'requires', %plugin_versions } ]
                if keys %plugin_versions;

    $self->add_plugins(@plugins);

    # check for a bin/ that should probably be renamed to script/
    warn "bin/ detected - should this be moved to script/, so its contents can be installed into \$PATH?\n"
        if -d 'bin' and any { $_ eq 'ModuleBuildTiny' } $self->installer;
}

# return username, password from ~/.pause
sub _pause_config
{
    my $self = shift;

    my $file = path($ENV{HOME} // 'oops', '.pause');
    return if not -e $file;

    my ($username, $password) = map { my (undef, $val) = split ' ', $_; $val } $file->lines;
}

__PACKAGE__->meta->make_immutable;
__END__

=pod

=head1 SYNOPSIS

In your F<dist.ini>:

    [@Author::ETHER]

=head1 DESCRIPTION

This is a L<Dist::Zilla> plugin bundle. It is approximately equivalent to the
following F<dist.ini> (following the preamble):

    ;;; VersionProvider
    [Git::NextVersion]
    version_regexp = ^v([\d._]+)(-TRIAL)?$

    ;;; BeforeBuild
    [PromptIfStale / stale modules, build]
    phase = build
    module = Dist::Zilla::Plugin::Author::ETHER
    [PromptIfStale / stale modules, release]
    phase = release
    check_all_plugins = 1
    check_all_prereqs = 1


    ;;; ExecFiles, ShareDir
    [ExecDir]
    dir = script

    [ShareDir]


    ;;; Finders
    [FileFinder::ByName / Examples]
    dir = examples
    [FileFinder::ByName / ExtraTestFiles]
    dir = xt

    ;;; Gather Files
    [Git::GatherDir]
    :version = 2.016
    exclude_filename = README.md
    exclude_filename = README.pod
    exclude_filename = LICENSE
    exclude_filename = CONTRIBUTING

    [MetaYAML]
    [MetaJSON]
    [License]
    [Readme]
    [Manifest]
    [GenerateFile::ShareDir / generate CONTRIBUTING]
    -dist = Dist-Zilla-PluginBundle-Author-ETHER
    -filename = CONTRIBUTING
    has_xs => <dynamically-determined flag>

    [Test::Compile]
    :version = 2.039
    bail_out_on_fail = 1
    xt_mode = 1
    script_finder = :ExecFiles
    script_finder = Examples

    [Test::NoTabs]
    :version = 0.08
    finder = :InstallModules
    finder = :ExecFiles
    finder = Examples
    finder = :TestFiles
    finder = ExtraTestFiles

    [EOLTests]
    [MetaTests]
    [Test::CPAN::Changes]
    :version = 0.008
    [Test::ChangesHasContent]
    [Test::MinimumVersion]
    :version = 2.000003
    max_target_perl = 5.008001
    [PodSyntaxTests]
    [PodCoverageTests]
    [Test::PodSpelling]
    ;[Test::Pod::LinkCheck]     many outstanding bugs
    [Test::Pod::No404s]
    [Test::Kwalitee]
    [MojibakeTests]
    [Test::ReportPrereqs]
    verify_prereqs = 1
    [Test::Portability]


    ;;; Munge Files
    [Git::Describe]
    [PkgVersion]
    :version = 5.010
    die_on_existing_version = 1
    die_on_line_insertion = 1
    [Authority]
    authority = cpan:ETHER

    [PodWeaver] (or [SurgicalPodWeaver])
    :version = 4.005
    replacer = replace_with_comment
    post_code_replacer = replace_with_nothing

    [NextRelease]
    :version = 4.300018
    time_zone = UTC
    format = %-8v  %{uyyy-MM-dd HH:mm:ss'Z'}d%{ (TRIAL RELEASE)}T
    [ReadmeAnyFromPod]
    type = pod
    location = root
    phase = release


    ;;; MetaData
    [GithubMeta]    ; (if server = 'github' or omitted)
    [AutoMetaResources]
    bugtracker.rt = 1
    ; (plus repository.* = 1 if server = 'gitmo' or 'p5sagit')

    ; (Authority)

    [MetaNoIndex]
    directory = t
    directory = xt
    directory = inc
    directory = local
    directory = perl5
    directory = fatlib
    directory = examples
    directory = share
    directory = corpus

    [MetaProvides::Package]
    meta_noindex = 1
    :version = 1.15000002
    finder = :InstallModules

    [MetaConfig]
    [Keywords]
    :version = 0.004
    [Git::Contributors]
    :version = 0.002

    ;;; Register Prereqs
    [AutoPrereqs]
    [Prereqs::AuthorDeps]
    [MinimumPerl]

    [Prereqs / installer_requirements]
    -phase = develop
    -relationship = requires
    Dist::Zilla::PluginBundle::Author::ETHER = <version specified in dist.ini>

    [Prereqs / pluginbundle_version]
    -phase = develop
    -relationship = recommends
    Dist::Zilla::PluginBundle::Author::ETHER = <current installed version>


    ;;; Install Tool
    <specified installer(s)>
    [InstallGuide]


    ;;; Test Runner
    # <specified installer(s)>
    [RunExtraTests]
    :version = 0.019
    default_jobs = 9


    ;;; After Build
    [CheckSelfDependency]

    [Run::AfterBuild]
    run = if [[ `dirname %d` != .build ]]; then test -e .ackrc && grep -q -- '--ignore-dir=%d' .ackrc || echo '--ignore-dir=%d' >> .ackrc; fi; if [[ %d =~ ^%n-[.[:xdigit:]]+$ ]]; then rm -f .latest; ln -s %d .latest; fi


    ;;; Before Release
    [CheckStrictVersion]
    decimal_only = 1

    [Git::Check / initial check]
    allow_dirty =

    [Git::CheckFor::MergeConflicts]

    [Git::CheckFor::CorrectBranch]
    :version = 0.004
    release_branch = master

    [Git::Remote::Check]
    branch = master
    remote_branch = master

    [CheckPrereqsIndexed]
    [TestRelease]
    [Git::Check / after tests]
    allow_dirty =
    [CheckIssues]
    ;(ConfirmRelease)


    ;;; Releaser
    [UploadToCPAN]


    ;;; AfterRelease
    [CopyFilesFromRelease]
    filename = LICENSE
    filename = CONTRIBUTING

    [Run::AfterRelease / remove old READMEs]
    run = rm -f README.md

    [Git::Commit]
    :version = 2.020
    add_files_in = .
    allow_dirty = Changes
    allow_dirty = README.md
    allow_dirty = README.pod
    allow_dirty = LICENSE
    allow_dirty = CONTRIBUTING
    commit_msg = %N-%v%t%n%n%c

    [Git::Tag]
    tag_format = v%v%t
    tag_message = v%v%t

    [GitHub::Update]    ; (if server = 'github' or omitted)
    metacpan = 1

    [Git::Push]

    [Run::AfterRelease / install release]
    run = cpanm http://URMOM:mysekritpassword@pause.perl.org/pub/PAUSE/authors/id/U/UR/URMOM/%a


    ; listed late, to allow all other plugins which do BeforeRelease checks to run first.
    [ConfirmRelease]

    ; listed last, to be sure we run at the very end of each phase
    ; only performed if $ENV{USER} eq 'ether'
    [VerifyPhases / PHASE VERIFICATION]


=for Pod::Coverage configure mvp_multivalue_args

=for stopwords metacpan

The distribution's code is assumed to be hosted at L<github|http://github.com>;
L<RT|http://rt.cpan.org> is used as the issue tracker.
The home page in the metadata points to L<github|http://github.com>,
while the home page on L<github|http://github.com> is updated on release to
point to L<metacpan|http://metacpan.org>.
The version and other metadata is derived directly from the local git repository.

=head1 OPTIONS / OVERRIDES

=head2 version

Use C<< V=<version> >> in the shell to override the version of the distribution being built;
otherwise the version is
incremented from the last git tag.

=head2 pod coverage

Subs can be considered "covered" for pod coverage tests by adding a directive to pod,
as described in L<Pod::Coverage::TrustPod>:

    =for Pod::Coverage foo bar baz

=head2 spelling stopwords

=for stopwords Stopwords

Stopwords for spelling tests can be added by adding a directive to pod (as
many as you'd like), as described in L<Pod::Spell/ADDING STOPWORDS>:

    =for stopwords foo bar baz

=head2 installer

=for stopwords ModuleBuildTiny

The installer back-end(s) to use (can be specified more than once); defaults
to L<C<ModuleBuildTiny>|Dist::Zilla::Plugin::ModuleBuildTiny::Fallback>
and L<C<MakeMaker::Fallback>|Dist::Zilla::Plugin::MakeMaker::Fallback>
(which generates a F<Build.PL> for normal use with no-configure-requires
protection, and F<Makefile.PL> as a fallback, containing an upgrade warning).

You can select other backends (by plugin name, without the C<[]>), with the
C<installer> option, or 'none' if you are supplying your own, as a separate
plugin.

Encouraged choices are:

    installer = ModuleBuildTiny
    installer = MakeMaker
    installer = =inc::Foo (if no configs are needed for this plugin)
    installer = none (if you are including your own later on, with configs)

=head2 server

If provided, must be one of:

=begin :list

* C<github>
(default)
metadata and release plugins are tailored to L<github|http://github.com>.

* C<gitmo>
metadata and release plugins are tailored to
L<gitmo@git.moose.perl.org|http://git.moose.perl.org>.

* C<p5sagit>
metadata and release plugins are tailored to
L<p5sagit@git.shadowcat.co.uk|http://git.shadowcat.co.uk>.

* C<catagits>
metadata and release plugins are tailored to
L<catagits@git.shadowcat.co.uk|http://git.shadowcat.co.uk>.

* C<none>
no special configuration of metadata (relating to repositories etc) is done --
you'll need to provide this yourself.

=end :list

=head2 airplane

A boolean option, that when set, removes the use of all plugins that use the
network (generally for comparing metadata against PAUSE, and querying the
remote git server), as well as blocking the use of the C<release> command.
Defaults to false; can also be set with the environment variable C<DZIL_AIRPLANE>.

=head2 copy_file_from_release

A file, to be present in the build, which is copied back to the source
repository at release time and committed to git. Can be repeated more than
once. Defaults to: F<README.pod>, F<LICENSE>, F<CONTRIBUTING>.

=head2 surgical_podweaver

=for stopwords PodWeaver SurgicalPodWeaver

A boolean option, that when set, uses
L<[SurgicalPodWeaver]|Dist::Zilla::Plugin::SurgicalPodWeaver> instead of
L<[PodWeaver]|Dist::Zilla::Plugin::SurgicalPodWeaver>, but with all the same
options. Defaults to false.

=for stopwords customizations

=head2 other customizations

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
