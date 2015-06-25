use strict;
use warnings;
package Dist::Zilla::PluginBundle::Author::ETHER;
# ABSTRACT: A plugin bundle for distributions built by ETHER
# KEYWORDS: author bundle distribution tool
# vim: set ts=8 sts=4 sw=4 tw=78 et :

our $VERSION = '0.097';

use Moose;
with
    'Dist::Zilla::Role::PluginBundle::Easy',
    'Dist::Zilla::Role::PluginBundle::PluginRemover' => { -version => '0.103' },
    'Dist::Zilla::Role::PluginBundle::Config::Slicer';

use Dist::Zilla::Util;
use Moose::Util::TypeConstraints qw(enum subtype where);
use List::Util 1.33 qw(first any);
use Module::Runtime 'require_module';
use Devel::CheckBin 'can_run';
use Path::Tiny;
use CPAN::Meta::Requirements;
use Term::ANSIColor 'colored';
use namespace::autoclean -also => ['_uniq'];

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
    default => sub { $ENV{DZIL_AIRPLANE} || $_[0]->payload->{airplane} // 0 },
);

has copy_file_from_release => (
    isa => 'ArrayRef[Str]',
    lazy => 1,
    default => sub { $_[0]->payload->{copy_file_from_release} // [] },
    traits => ['Array'],
    handles => { copy_files_from_release => 'elements' },
);

around copy_files_from_release => sub {
    my $orig = shift; my $self = shift;
    _uniq($self->$orig(@_), qw(LICENSE CONTRIBUTING Changes ppport.h));
};

has changes_version_columns => (
    is => 'ro', isa => subtype('Int', where { $_ > 0 && $_ < 20 }),
    lazy => 1,
    default => sub { $_[0]->payload->{changes_version_columns} // 10 },
);

# configs are applied when plugins match ->isa($key) or ->does($key)
my %extra_args = (
    'Dist::Zilla::Plugin::MakeMaker' => { 'eumm_version' => '0' },
    'Dist::Zilla::Plugin::ModuleBuildTiny' => { ':version' => '0.009', version_method => 'conservative' },
    'Dist::Zilla::Plugin::MakeMaker::Fallback' => { ':version' => '0.012' },
    # default_jobs is no-op until Dist::Zilla 5.014
    'Dist::Zilla::Role::TestRunner' => { default_jobs => 9 },
    'Dist::Zilla::Plugin::ModuleBuild' => { mb_version => '0.28' },
    'Dist::Zilla::Plugin::ModuleBuildTiny::Fallback' => { ':version' => '0.006' },
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

# files that might be in the repository that should never be gathered
my @never_gather = qw(
    Makefile.PL ppport.h README.md README.pod META.json
    cpanfile TODO CONTRIBUTING LICENSE inc/ExtUtils/MakeMaker/Dist/Zilla/Develop.pm
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

    warn '[@Author::ETHER] no "bash" executable found; skipping Run::AfterBuild commands to update .ackrc and .latest symlink', "\n"
        if not $has_bash;

    # NOTE! since the working directory has not changed to $zilla->root yet,
    # if running this code via a different mechanism than dzil <command>, file
    # operations may be looking at the wrong directory! Take this into
    # consideration when running tests!

    my $has_xs =()= glob('*.xs');
    warn '[@Author::ETHER] XS-based distribution detected.', "\n" if $has_xs;
    die '[@Author::ETHER] no Makefile.PL found in the repository root: this is not very nice for contributors!', "\n"
        if $has_xs and not -e 'Makefile.PL';

    # check for a bin/ that should probably be renamed to script/
    warn '[@Author::ETHER] ' . colored('bin/ detected - should this be moved to script/, so its contents can be installed into $PATH?', 'bright_red') . "\n"
        if -d 'bin' and any { $_ eq 'ModuleBuildTiny' } $self->installer;

    warn '[@Author::ETHER] You are using [ModuleBuild] as an installer, WTF?!'
        if any { $_ eq 'ModuleBuild' } $self->installer;

    # this is better than injecting a perl prereq for 5.008, to allow MBT to
    # become more 5.006-compatible in the future without forcing the distribution to be re-released.
    die 'Module::Build::Tiny should not be used in distributions that are targeting perl 5.006!'
        if any { /ModuleBuildTiny/ } $self->installer
            and (not exists $self->payload->{'Test::MinimumVersion.max_target_perl'}
                 or $self->payload->{'Test::MinimumVersion.max_target_perl'} < '5.008');

    my $remove = $self->payload->{ $self->plugin_remover_attribute } // [];
    my %removed; @removed{@$remove} = (!!1) x @$remove;

    my @plugins = (
        # VersionProvider
        [ 'RewriteVersion::Transitional' => { ':version' => '0.004', global => 1, fallback_version_provider => 'Git::NextVersion', version_regexp => '^v([\d._]+)(-TRIAL)?$',
                (map { (my $key = $_) =~ s/Git::NextVersion\.//; $key => $self->payload->{$_} } grep { /^Git::NextVersion\./ } keys %{ $self->payload }) } ],

        # BeforeBuild
        # [ 'EnsurePrereqsInstalled' ], # FIXME: use options to make this less annoying!
        [ 'PromptIfStale' => 'stale modules, build' => { phase => 'build', module => [ $self->meta->name ] } ],
        [ 'PromptIfStale' => 'stale modules, release' => { phase => 'release', check_all_plugins => 1, check_all_prereqs => 1 } ],

        # ExecFiles
        (-d ($self->payload->{'ExecDir.dir'} // 'script') || any { /^ExecDir\./ } keys %{ $self->payload })
            ? [ 'ExecDir'       => { dir => 'script' } ] : (),

        # Finders
        [ 'FileFinder::ByName'  => Examples => { dir => 'examples' } ],
        [ 'FileFinder::ByName'  => ExtraTestFiles => { dir => 'xt' } ],

        # Gather Files
        [ 'Git::GatherDir'      => { ':version' => '2.016', do {
                my @filenames = grep { -e } @never_gather;
                @filenames ? ( exclude_filename => \@filenames ) : ()
            },
        } ],

        qw(MetaYAML MetaJSON License Readme Manifest),
        [ 'GenerateFile::ShareDir' => 'generate CONTRIBUTING' => { -dist => 'Dist-Zilla-PluginBundle-Author-ETHER', -filename => 'CONTRIBUTING', has_xs => $has_xs } ],
        'InstallGuide',

        [ 'Test::Compile'       => { ':version' => '2.039', bail_out_on_fail => 1, xt_mode => 1,
            script_finder => [qw(:ExecFiles @Author::ETHER/Examples)] } ],
        [ 'Test::NoTabs'        => { ':version' => '0.08', finder => [qw(:InstallModules :ExecFiles @Author::ETHER/Examples :TestFiles @Author::ETHER/ExtraTestFiles)] } ],
        [ 'Test::EOL'           => { ':version' => '0.17', finder => [qw(:InstallModules :ExecFiles @Author::ETHER/Examples :TestFiles @Author::ETHER/ExtraTestFiles)] } ],
        'MetaTests',
        [ 'Test::CPAN::Changes' => { ':version' => '0.008' } ],
        'Test::ChangesHasContent',
        [ 'Test::MinimumVersion' => { ':version' => '2.000003', max_target_perl => '5.006' } ],
        'PodSyntaxTests',
        'PodCoverageTests',
        [ 'Test::PodSpelling'   => { ':version' => '2.006001' } ],
        #[Test::Pod::LinkCheck]     many outstanding bugs
        'Test::Pod::No404s',
        [ 'Test::Kwalitee'      => { ':version' => '2.06', filename => 'xt/author/kwalitee.t' } ],
        'MojibakeTests',
        [ 'Test::ReportPrereqs' => { ':version' => '0.019', verify_prereqs => 1,
            exists $removed{PodCoverageTests} ? () : ( include => [ 'Pod::Coverage' ] ),
          } ],
        'Test::Portability',
        [ 'Test::CleanNamespaces' => { ':version' => '0.006' } ],


        # Munge Files
        [ 'Git::Describe'       => { ':version' => '0.004', on_package_line => 1 } ],
        # [RewriteVersion::Transitional], for the transitional usecase
        [
            ($self->surgical_podweaver ? 'SurgicalPodWeaver' : 'PodWeaver') => {
                $self->surgical_podweaver ? () : ( ':version' => '4.005' ),
                -f 'weaver.ini' ? () : ( config_plugin => '@Author::ETHER' ),
                replacer => 'replace_with_comment',
                post_code_replacer => 'replace_with_nothing',
            }
        ],
        [ 'ReadmeAnyFromPod'    => { ':version' => '0.142180', type => 'pod', location => 'root', phase => 'release' } ],

        # MetaData
        $self->server eq 'github' ? [ 'GithubMeta' => { homepage => 0, issues => 0 } ] : (),
        [ 'AutoMetaResources'   => { 'bugtracker.rt' => 1,
              $self->server eq 'gitmo' ? ( 'repository.gitmo' => 1 )
            : $self->server eq 'p5sagit' ? ( 'repository.p5sagit' => 1 )
            : $self->server eq 'catagits' ? ( 'repository.catagits' => 1 )
            : ()
        } ],
        [ 'AuthorityFromModule' => { ':version' => '0.002' } ],
        [ 'Authority'           => { ':version' => '1.009', authority => 'cpan:ETHER', do_munging => 0 } ],
        [ 'MetaNoIndex'         => { directory => [ qw(t xt), grep { -d } qw(inc local perl5 fatlib examples share corpus demo) ] } ],
        [ 'MetaProvides::Package' => { ':version' => '1.15000002', finder => ':InstallModules', meta_noindex => 1, inherit_version => 0, inherit_missing => 0 } ],
        'MetaConfig',
        [ 'Keywords'            => { ':version' => '0.004' } ],
        [ 'Git::Contributors'   => { ':version' => '0.004', order_by => 'commits' } ],

        # Register Prereqs
        # (MakeMaker or other installer)
        'AutoPrereqs',
        'Prereqs::AuthorDeps',
        [ 'MinimumPerl'         => { ':version' => '1.006', configure_finder => ':NoFiles' } ],
        [ 'Prereqs' => pluginbundle_version => {
                '-phase' => 'develop', '-relationship' => 'recommends',
                $self->meta->name => $self->VERSION,
            } ],
        ($self->surgical_podweaver ? [ 'Prereqs' => pod_weaving => {
                '-phase' => 'develop', '-relationship' => 'requires',
                'Dist::Zilla::Plugin::SurgicalPodWeaver' => 0
            } ] : ()),

        # Install Tool (some are also Test Runners)
        $self->installer,

        # Test Runners (load after installers to avoid a rebuild)
        [ 'RunExtraTests'       => { ':version' => '0.024' } ],

        # After Build
        'CheckSelfDependency',

        ( $has_bash ?
            [ 'Run::AfterBuild' => '.ackrc' => { ':version' => '0.038', quiet => 1, run => q{bash -c "test -e .ackrc && grep -q -- '--ignore-dir=.latest' .ackrc || echo '--ignore-dir=.latest' >> .ackrc; if [[ `dirname '%d'` != .build ]]; then test -e .ackrc && grep -q -- '--ignore-dir=%d' .ackrc || echo '--ignore-dir=%d' >> .ackrc; fi"} } ]
            : ()),
        [ 'Run::AfterBuild'     => '.latest' => { ':version' => '0.038', quiet => 1, eval => q!if ('%d' =~ /^%n-[.[:xdigit:]]+$/) { unlink '.latest'; symlink '%d', '.latest'; }! } ],


        # Before Release
        [ 'CheckStrictVersion'  => { decimal_only => 1 } ],
        [ 'Git::Check'          => 'initial check' => { allow_dirty => [''] } ],
        'Git::CheckFor::MergeConflicts',
        [ 'Git::CheckFor::CorrectBranch' => { ':version' => '0.004', release_branch => 'master' } ],
        [ 'Git::Remote::Check'  => { branch => 'master', remote_branch => 'master' } ],
        'CheckPrereqsIndexed',
        'TestRelease',
        [ 'Git::Check'          => 'after tests' => { allow_dirty => [''] } ],
        'CheckIssues',
        # (ConfirmRelease)

        # Releaser
        'UploadToCPAN',

        # After Release
        [ 'CopyFilesFromRelease' => { filename => [ $self->copy_files_from_release ] } ],
        ( -e 'README.md' ?
            [ 'Run::AfterRelease' => 'remove old READMEs' => { ':version' => '0.038', quiet => 1, eval => q!unlink 'README.md'! } ]
            : ()),
        [ 'Git::Commit'         => 'release snapshot' => { ':version' => '2.020', add_files_in => ['.'], allow_dirty => [ grep { -e } _uniq('README.md', 'README.pod', $self->copy_files_from_release) ], commit_msg => '%N-%v%t%n%n%c' } ],
        [ 'Git::Tag'            => { tag_format => 'v%v', tag_message => 'v%v%t' } ],
        $self->server eq 'github' ? [ 'GitHub::Update' => { ':version' => '0.40', metacpan => 1 } ] : (),

        [ 'BumpVersionAfterRelease::Transitional' => { ':version' => '0.004', global => 1 } ],
        [ 'NextRelease'         => { ':version' => '5.033', time_zone => 'UTC', format => '%-' . ($self->changes_version_columns - 2) . 'v  %{yyyy-MM-dd HH:mm:ss\'Z\'}d%{ (TRIAL RELEASE)}T' } ],
        [ 'Git::Commit'         => 'post-release commit' => { ':version' => '2.020', allow_dirty => [ 'Changes' ], allow_dirty_match => '^lib/.*\.pm$', commit_msg => 'increment $VERSION after %v release' } ],
        'Git::Push',
    );

    # install with an author-specific URL from PAUSE, so cpanm-reporter knows where to submit the report
    # hopefully the file is available at this location soonish after release!
    my ($username, $password) = $self->_pause_config;
    push @plugins,
        [ 'Run::AfterRelease' => 'install release' => { ':version' => '0.031', fatal_errors => 0, run => 'cpanm http://' . $username . ':' . $password . '@pause.perl.org/pub/PAUSE/authors/id/' . substr($username, 0, 1).'/'.substr($username,0,2).'/'.$username.'/%a' } ] if $username and $password;

    if ($self->airplane)
    {
        warn '[@Author::ETHER] ' . colored('building in airplane mode - plugins requiring the network are skipped, and releases are not permitted', 'yellow') . "\n";
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

        # halt release after pre-release checks, but before ConfirmRelease
        push @plugins, 'BlockRelease';
    }

    push @plugins, (
        [ 'Run::AfterRelease'   => 'release complete' => { ':version' => '0.038', quiet => 1, eval => [ qq{print "release complete!\\xa"} ] } ],
        # listed late, to allow all other plugins which do BeforeRelease checks to run first.
        'ConfirmRelease',
    );

    my $plugin_requirements = CPAN::Meta::Requirements->new;
    foreach my $plugin_spec (@plugins = map { ref $_ ? $_ : [ $_ ] } @plugins)
    {
        next if $removed{$plugin_spec->[0]};

        my $plugin = Dist::Zilla::Util->expand_config_package_name($plugin_spec->[0]);
        require_module($plugin);

        push @$plugin_spec, {} if not ref $plugin_spec->[-1];
        my $payload = $plugin_spec->[-1];

        if (my @keys = grep { $plugin->isa($_) or $plugin->does($_) } keys %extra_args)
        {
            # combine all the relevant configs together
            my %configs = map { %{ $extra_args{$_} } } @keys;

            # and add to the payload of this plugin
            @{$payload}{keys %configs} = values %configs;
        }

        # record develop prereq
        $plugin_requirements->add_minimum($plugin => $payload->{':version'} // 0);
    }

    # ensure that additional optional plugins are declared in prereqs
    unshift @plugins,
        [ 'Prereqs' => bundle_plugins =>
            { '-phase' => 'develop', '-relationship' => 'requires',
              %{ $plugin_requirements->as_string_hash } } ];

    push @plugins, (
        # listed last, to be sure we run at the very end of each phase
        [ 'VerifyPhases' => 'PHASE VERIFICATION' ],
    ) if ($ENV{USER} // '') eq 'ether';

    $self->add_plugins(@plugins);
}

# return username, password from ~/.pause
sub _pause_config
{
    my $self = shift;

    my $file = path($ENV{HOME} // 'oops', '.pause');
    return if not -e $file;

    my ($username, $password) = map { my (undef, $val) = split ' ', $_; $val } $file->lines;
}

sub _uniq { keys %{ +{ map { $_ => undef } @_ } } }

__PACKAGE__->meta->make_immutable;
__END__

=pod

=head1 SYNOPSIS

In your F<dist.ini>:

    [@Author::ETHER]

=head1 DESCRIPTION

=for stopwords optimizations

This is a L<Dist::Zilla> plugin bundle. It is I<very approximately> equal to the
following F<dist.ini> (following the preamble), minus some optimizations:

    ;;; VersionProvider
    [RewriteVersion::Transitional]
    :version = 0.004
    global = 1
    fallback_version_provider = Git::NextVersion
    version_regexp = ^v([\d._]+)(-TRIAL)?$


    ;;; BeforeBuild
    [PromptIfStale / stale modules, build]
    phase = build
    module = Dist::Zilla::Plugin::Author::ETHER
    [PromptIfStale / stale modules, release]
    phase = release
    check_all_plugins = 1
    check_all_prereqs = 1


    ;;; ExecFiles
    [ExecDir]
    dir = script    ; only if script dir exists


    ;;; Finders
    [FileFinder::ByName / Examples]
    dir = examples
    [FileFinder::ByName / ExtraTestFiles]
    dir = xt


    ;;; Gather Files
    [Git::GatherDir]
    :version = 2.016
    exclude_filename = CONTRIBUTING
    exclude_filename = LICENSE
    exclude_filename = META.json
    exclude_filename = Makefile.PL
    exclude_filename = README.md
    exclude_filename = README.pod
    exclude_filename = TODO
    exclude_filename = cpanfile
    exclude_filename = inc/ExtUtils/MakeMaker/Dist/Zilla/Develop.pm
    exclude_filename = ppport.h

    [MetaYAML]
    [MetaJSON]
    [License]
    [Readme]
    [Manifest]
    [GenerateFile::ShareDir / generate CONTRIBUTING]
    -dist = Dist-Zilla-PluginBundle-Author-ETHER
    -filename = CONTRIBUTING
    has_xs = <dynamically-determined flag>
    [InstallGuide]

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

    [Test::EOL]
    :version = 0.17
    finder = :InstallModules
    finder = :ExecFiles
    finder = Examples
    finder = :TestFiles
    finder = ExtraTestFiles

    [MetaTests]
    [Test::CPAN::Changes]
    :version = 0.008
    [Test::ChangesHasContent]
    [Test::MinimumVersion]
    :version = 2.000003
    max_target_perl = 5.006
    [PodSyntaxTests]
    [PodCoverageTests]
    [Test::PodSpelling]
    ;[Test::Pod::LinkCheck]     many outstanding bugs
    [Test::Pod::No404s]
    [Test::Kwalitee]
    :version = 2.06
    filename = xt/author/kwalitee.t
    [MojibakeTests]
    [Test::ReportPrereqs]
    :version = 0.019
    verify_prereqs = 1
    include = Pod::Coverage
    [Test::Portability]
    [Test::CleanNamespaces]
    :version = 0.006


    ;;; Munge Files
    [Git::Describe]
    :version = 0.004
    on_package_line = 1

    [PodWeaver] (or [SurgicalPodWeaver])
    :version = 4.005
    config_plugin = @Author::ETHER ; unless weaver.ini is present
    replacer = replace_with_comment
    post_code_replacer = replace_with_nothing

    [ReadmeAnyFromPod]
    :version = 0.142180
    type = pod
    location = root
    phase = release


    ;;; MetaData
    [GithubMeta]    ; (if server = 'github' or omitted)
    homepage = 0
    issues = 0

    [AutoMetaResources]
    bugtracker.rt = 1
    ; (plus repository.* = 1 if server = 'gitmo' or 'p5sagit')

    [AuthorityFromModule]
    :version = 0.002
    [Authority]
    :version = 1.009
    authority = cpan:ETHER
    do_munging = 0

    [MetaNoIndex]
    directory = corpus
    directory = demo
    directory = examples
    directory = fatlib
    directory = inc
    directory = local
    directory = perl5
    directory = share
    directory = t
    directory = xt

    [MetaProvides::Package]
    :version = 1.15000002
    finder = :InstallModules
    meta_noindex = 1
    inherit_version = 0
    inherit_missing = 0

    [MetaConfig]
    [Keywords]
    :version = 0.004
    [Git::Contributors]
    :version = 0.004
    order_by = commits


    ;;; Register Prereqs
    [AutoPrereqs]
    [Prereqs::AuthorDeps]
    [MinimumPerl]
    :version = 1.006
    configure_finder = :NoFiles

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


    ;;; Test Runner
    ; <specified installer(s)>
    [RunExtraTests]
    :version = 0.024
    default_jobs = 9


    ;;; After Build
    [CheckSelfDependency]

    [Run::AfterBuild / .ackrc]
    :version = 0.38
    quiet = 1
    run = bash -c "test -e .ackrc && grep -q -- '--ignore-dir=.latest' .ackrc || echo '--ignore-dir=.latest' >> .ackrc; if [[ `dirname '%d'` != .build ]]; then test -e .ackrc && grep -q -- '--ignore-dir=%d' .ackrc || echo '--ignore-dir=%d' >> .ackrc; fi; if [[ %d =~ ^%n-[.[:xdigit:]]+$ ]]; then rm -f .latest; ln -s %d .latest; fi"
    [Run::AfterBuild / .latest]
    :version = 0.038
    quiet = 1
    eval = if ('%d' =~ /^%n-[.[:xdigit:]]+$/) { unlink '.latest'; symlink '%d', '.latest'; }


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
    filename = CONTRIBUTING
    filename = Changes
    filename = LICENSE
    filename = ppport.h

    [Run::AfterRelease / remove old READMEs]
    :version = 0.038
    quiet = 1
    eval = unlink 'README.md'

    [Git::Commit / release snapshot]
    :version = 2.020
    add_files_in = .
    allow_dirty = CONTRIBUTING
    allow_dirty = Changes
    allow_dirty = LICENSE
    allow_dirty = README.md
    allow_dirty = README.pod
    allow_dirty = ppport.h
    commit_msg = %N-%v%t%n%n%c

    [Git::Tag]
    tag_format = v%v
    tag_message = v%v%t

    [GitHub::Update]    ; (if server = 'github' or omitted)
    :version = 0.40
    metacpan = 1

    [BumpVersionAfterRelease::Transitional]
    :version = 0.004
    global = 1

    [NextRelease]
    :version = 5.033
    time_zone = UTC
    format = %-8v  %{uyyy-MM-dd HH:mm:ss'Z'}d%{ (TRIAL RELEASE)}T

    [Git::Commit / post-release commit]
    :version = 2.020
    allow_dirty = Changes
    allow_dirty_match = ^lib/.*\.pm$
    commit_msg = increment $VERSION after %v release

    [Git::Push]

    [Run::AfterRelease / install release]
    :version = 0.031
    fatal_errors = 0
    run = cpanm http://URMOM:mysekritpassword@pause.perl.org/pub/PAUSE/authors/id/U/UR/URMOM/%a

    [Run::AfterRelease / release complete]
    :version = 0.038
    quiet = 1
    eval = print "release complete!\\xa"

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
otherwise the version is incremented after each release, in the F<*.pm> files.

=head2 pod coverage

Subs can be considered "covered" for pod coverage tests by adding a directive to pod,
as described in L<Pod::Coverage::TrustPod>:

    =for Pod::Coverage foo bar baz

=head2 spelling stopwords

=for stopwords Stopwords

Stopwords for spelling tests can be added by adding a directive to pod (as
many as you'd like), as described in L<Pod::Spell/ADDING STOPWORDS>:

    =for stopwords foo bar baz

See also L<[Test::PodSpelling]|Dist::Zilla::Plugin::Test::PodSpelling/stopwords>.

=head2 installer

=for stopwords ModuleBuildTiny

Available since 0.007.

The installer back-end(s) to use (can be specified more than once); defaults
to L<C<ModuleBuildTiny>|Dist::Zilla::Plugin::ModuleBuildTiny::Fallback>
and L<C<MakeMaker::Fallback>|Dist::Zilla::Plugin::MakeMaker::Fallback>
(which generates a F<Build.PL> for normal use with no-configure-requires
protection, and F<Makefile.PL> as a fallback, containing an upgrade warning).
For toolchain-grade modules, you should only use F<Makefile.PL>-generating installers.

You can select other backends (by plugin name, without the C<[]>), with the
C<installer> option, or 'none' if you are supplying your own, as a separate
plugin(s).

Encouraged choices are:

    installer = ModuleBuildTiny
    installer = MakeMaker
    installer = =inc::Foo (if no configs are needed for this plugin)
    installer = none (if you are including your own later on, with configs)

=head2 server

Available since 0.019.

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

Available since 0.053.

A boolean option, that when set, removes the use of all plugins that use the
network (generally for comparing metadata against PAUSE, and querying the
remote git server), as well as blocking the use of the C<release> command.
Defaults to false; can also be set with the environment variable C<DZIL_AIRPLANE>.

=head2 copy_file_from_release

Available in this form since 0.076.

A file, to be present in the build, which is copied back to the source
repository at release time and committed to git. Can be repeated more than
once. Defaults to: F<LICENSE>, F<CONTRIBUTING>; defaults are appended to,
rather than overwritten.

=head2 surgical_podweaver

=for stopwords PodWeaver SurgicalPodWeaver

Available since 0.051.

A boolean option, that when set, uses
L<[SurgicalPodWeaver]|Dist::Zilla::Plugin::SurgicalPodWeaver> instead of
L<[PodWeaver]|Dist::Zilla::Plugin::SurgicalPodWeaver>, but with all the same
options. Defaults to false.

=head2 changes_version_columns

Available since 0.076.

An integer that specifies how many columns (right-padded with whitespace) are
allocated in Changes entries to the version string. Defaults to 10.

=for stopwords customizations

=head2 other customizations

This bundle makes use of L<Dist::Zilla::Role::PluginBundle::PluginRemover> and
L<Dist::Zilla::Role::PluginBundle::Config::Slicer> to allow further customization.
Plugins are not loaded until they are actually needed, so it is possible to
C<--force>-install this plugin bundle and C<-remove> some plugins that do not
install or are otherwise problematic.

If a F<weaver.ini> is present in the distribution, pod is woven using it;
otherwise, the behaviour is as with a F<weaver.ini> containing the single line
C<[@Author::ETHER]>.

=head1 NAMING SCHEME

=for stopwords KENTNL

This distribution follows best practices for author-oriented plugin bundles; for more information,
see L<KENTNL's distribution|Dist::Zilla::PluginBundle::Author::KENTNL/NAMING-SCHEME>.

=head1 SEE ALSO

=for :list
* L<Pod::Weaver::PluginBundle::Author::ETHER>
* L<Dist::Zilla::MintingProfile::Author::ETHER>

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-PluginBundle-Author-ETHER>
(or L<bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org|mailto:bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=cut
