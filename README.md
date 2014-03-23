# NAME

Dist::Zilla::PluginBundle::Author::ETHER - A plugin bundle for distributions built by ETHER

# VERSION

version 0.054

# SYNOPSIS

In your `dist.ini`:

    [@Author::ETHER]

# DESCRIPTION

This is a [Dist::Zilla](https://metacpan.org/pod/Dist::Zilla) plugin bundle. It is approximately equivalent to the
following `dist.ini` (following the preamble):

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
    check_all_prereqs = 1


    ;;; ExecFiles, ShareDir
    [ExecDir]
    dir = script

    [ShareDir]


    ;;; Finders
    [FileFinder::ByName / Examples]
    dir = examples

    ;;; Gather Files
    [Git::GatherDir]
    :version = 2.016
    exclude_filename = README.md
    exclude_filename = LICENSE
    exclude_filename = CONTRIBUTING

    [MetaYAML]
    [MetaJSON]
    [License]
    [Readme]
    [Manifest]
    [GenerateFile::ShareDir]
    -dist = Dist-Zilla-PluginBundle-Author-ETHER
    -filename = CONTRIBUTING

    [Test::Compile]
    :version = 2.036
    bail_out_on_fail = 1
    xt_mode = 1
    script_finder = :ExecFiles
    script_finder = Examples

    [Test::NoTabs]
    script_finder = :ExecFiles
    script_finder = Examples

    [EOLTests]
    [MetaTests]
    [Test::Version]
    is_strict = 1
    [Test::CPAN::Changes]
    :version = 0.008
    [Test::ChangesHasContent]
    [Test::UnusedVars]
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
    type = markdown
    filename = README.md
    location = build


    ;;; MetaData
    [GithubMeta]    ; (if server = 'github' or omitted)
    [AutoMetaResources]
    bugtracker.rt = 1
    ; (plus repository.* = 1 if server = 'gitmo' or 'p5sagit')

    ; (Authority)

    [MetaNoIndex]
    directory = t
    directory = xt
    directory = examples

    [MetaProvides::Package]
    meta_noindex = 1
    :version = 1.15000002
    finder = :InstallModules

    [MetaConfig]


    ;;; Register Prereqs
    [AutoPrereqs]
    [Prereqs::AuthorDeps]
    [MinimumPerl]

    [Prereqs / installer_requirements]
    -phase = develop
    -relationship = requires
    Dist::Zilla = <version used to built the pluginbundle>
    Dist::Zilla::PluginBundle::Author::ETHER = <version specified in dist.ini>

    [Prereqs / pluginbundle_version]
    -phase = develop
    -relationship = recommends
    Dist::Zilla::PluginBundle::Author::ETHER = <current installed version>

    ;;; Test Runner
    [RunExtraTests]
    :version = 0.019
    default_jobs = 9
    # <specified installer(s)>


    ;;; Install Tool
    <specified installer(s)>
    [InstallGuide]


    ;;; After Build
    [CheckSelfDependency]

    [Run::AfterBuild]
    run => if [ `dirname %d` != .build ]; then test -e .ackrc && grep -q -- '--ignore-dir=%d' .ackrc || echo '--ignore-dir=%d' >> .ackrc; fi


    ;;; Before Release
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
    ;(ConfirmRelease)


    ;;; Releaser
    [UploadToCPAN]


    ;;; AfterRelease
    [CopyFilesFromRelease]
    filename = README.md
    filename = LICENSE
    filename = CONTRIBUTING

    [Git::Commit]
    :version = 2.020
    add_files_in = .
    allow_dirty = Changes
    allow_dirty = README.md
    allow_dirty = LICENSE
    allow_dirty = CONTRIBUTING
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

    ; listed last, to be sure we run at the very end of each phase
    [VerifyPhases / PHASE VERIFICATION]

The distribution's code is assumed to be hosted at [github](http://github.com);
[RT](http://rt.cpan.org) is used as the issue tracker.
The home page in the metadata points to [github](http://github.com),
while the home page on [github](http://github.com) is updated on release to
point to [metacpan](http://metacpan.org).
The version and other metadata is derived directly from the local git repository.

# OPTIONS / OVERRIDES

## version

Use `V=<version>` in the shell to override the version of the distribution being built;
otherwise the version is
incremented from the last git tag.

## pod coverage

Subs can be considered "covered" for pod coverage tests by adding a directive to pod,
as described in [Pod::Coverage::TrustPod](https://metacpan.org/pod/Pod::Coverage::TrustPod):

    =for Pod::Coverage foo bar baz

## spelling stopwords

Stopwords for spelling tests can be added by adding a directive to pod (as
many as you'd like), as described in ["ADDING STOPWORDS" in Pod::Spell](https://metacpan.org/pod/Pod::Spell#ADDING-STOPWORDS):

    =for stopwords foo bar baz

## installer

The installer back-end(s) to use (can be specified more than once); defaults
to [`ModuleBuildTiny`](https://metacpan.org/pod/Dist::Zilla::Plugin::ModuleBuildTiny)
and [`MakeMaker::Fallback`](https://metacpan.org/pod/Dist::Zilla::Plugin::MakeMaker::Fallback)
(which generates a `Build.PL` for normal use, and
`Makefile.PL` as a fallback, containing an upgrade warning).

You can select other backends (by plugin name, without the `[]`), with the
`installer` option, or 'none' if you are supplying your own, as a separate
plugin.

Encouraged choices are:

    installer = ModuleBuildTiny
    installer = MakeMaker
    installer = =inc::Foo (if no configs are needed for this plugin)
    installer = none (if you are including your own later on, with configs)

## server

If provided, must be one of:

- `github`

    (default)
    metadata and release plugins are tailored to [github](http://github.com).

- `gitmo`

    metadata and release plugins are tailored to
    [gitmo@git.moose.perl.org](http://git.moose.perl.org).

- `p5sagit`

    metadata and release plugins are tailored to
    [p5sagit@git.shadowcat.co.uk](http://git.shadowcat.co.uk).

- `catagits`

    metadata and release plugins are tailored to
    [catagits@git.shadowcat.co.uk](http://git.shadowcat.co.uk).

- `none`

    no special configuration of metadata (relating to repositories etc) is done --
    you'll need to provide this yourself.

## airplane

A boolean option, that when set, removes the use of all plugins that use the
network (generally for comparing metadata against PAUSE, and querying the
remote git server), as well as blocking the use of the `release` command.
Defaults to false.

## copy\_file\_from\_release

A file, to be present in the build, which is copied back to the source
repository at release time and committed to git. Can be repeated more than
once. Defaults to: `README.md`, `LICENSE`, `CONTRIBUTING`.

## surgical\_podweaver

A boolean option, that when set, uses
[\[SurgicalPodWeaver\]](https://metacpan.org/pod/Dist::Zilla::Plugin::SurgicalPodWeaver) instead of
[\[PodWeaver\]](https://metacpan.org/pod/Dist::Zilla::Plugin::SurgicalPodWeaver), but with all the same
options. Defaults to false.

## other customizations

This bundle makes use of [Dist::Zilla::Role::PluginBundle::PluginRemover](https://metacpan.org/pod/Dist::Zilla::Role::PluginBundle::PluginRemover) and
[Dist::Zilla::Role::PluginBundle::Config::Slicer](https://metacpan.org/pod/Dist::Zilla::Role::PluginBundle::Config::Slicer) to allow further customization.
Plugins are not loaded until they are actually needed, so it is possible to
`--force`-install this plugin bundle and `-remove` some plugins that do not
install or are otherwise problematic.

# NAMING SCHEME

This distribution follows best practices for author-oriented plugin bundles; for more information,
see [KENTNL's distribution](https://metacpan.org/pod/Dist::Zilla::PluginBundle::Author::KENTNL#NAMING-SCHEME).

# SUPPORT

Bugs may be submitted through [the RT bug tracker](https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-PluginBundle-Author-ETHER)
(or [bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org](mailto:bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org)).
I am also usually active on irc, as 'ether' at `irc.perl.org`.

# AUTHOR

Karen Etheridge <ether@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Karen Etheridge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

# CONTRIBUTORS

- Randy Stauner <randy@magnificent-tears.com>
- Sergey Romanov <complefor@rambler.ru>
