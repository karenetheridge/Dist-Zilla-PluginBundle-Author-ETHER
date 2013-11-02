# NAME

Dist::Zilla::PluginBundle::Author::ETHER - A plugin bundle for distributions built by ETHER

# VERSION

version 0.036

# SYNOPSIS

In your `dist.ini`:

    [@Author::ETHER]

# DESCRIPTION

This is a [Dist::Zilla](http://search.cpan.org/perldoc?Dist::Zilla) plugin bundle. It is approximately equivalent to the
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
    ; requires :version = 0.004, but we will be checking ourselves)
    check_all_prereqs = 1



    ;;; ExecFiles, ShareDir
    [ExecDir]
    dir = script

    [ShareDir]



    ;;; Gather Files
    [Git::GatherDir]
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

    [FileFinder::ByName / Examples]
    dir = examples

    [Test::Compile]
    :version = 2.036
    fail_on_warning = author
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
    [Test::ReportPrereqs]
    verify_prereqs = 1



    ;;; Munge Files
    [Authority]
    authority = cpan:ETHER
    [Git::Describe]
    [PkgVersion]
    :version = 4.300036
    die_on_existing_version = 1

    [PodWeaver]
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

    [MetaConfig]



    ;;; Register Prereqs
    [AutoPrereqs]
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
    # <specified installer(s)>



    ;;; Install Tool
    <specified installer(s)>
    [InstallGuide]



    ;;; After Build
    [CheckSelfDependency]

    [Run::AfterBuild]
    run => if [ `dirname %d` != .build ]; then test -e .ackrc && grep -q -- '--ignore-dir=%d' .ackrc || echo '--ignore-dir=%d' >> .ackrc; fi



    ;;; Before Release
    [Git::Check / git_check_1]
    allow_dirty =

    ;[Git::CheckFor::MergeConflicts]

    [Git::CheckFor::CorrectBranch]
    :version = 0.004
    release_branch = master

    [Git::Remote::Check]
    branch = master
    remote_branch = master

    [CheckPrereqsIndexed]
    [TestRelease]
    [Git::Check / git_check_2]
    allow_dirty =
    ;(ConfirmRelease)



    ;;; Releaser
    [UploadToCPAN]



    ;;; AfterRelease
    [CopyFilesFromRelease]
    copy = README.md
    copy = LICENSE
    copy = CONTRIBUTING

    [Git::Commit]
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

The distribution's code is assumed to be hosted at [github](http://github.com);
[RT](http://rt.cpan.org) is used as the issue tracker.
The home page in the metadata points to [github](http://github.com),
while the home page on [github](http://github.com) is updated on release to
point to [metacpan](http://metacpan.org).
The version and other metadata is derived directly from the local git repository.

# OPTIONS / OVERRIDES

## version

Use `V=<version>` to override the version of the distribution being built;
otherwise the version is
incremented from the last git tag.

## pod coverage

Subs can be considered "covered" for pod coverage tests by adding a directive to pod:

    =for Pod::Coverage foo bar baz

## spelling stopwords

Stopwords for spelling tests can be added by adding a directive to pod (as
many as you'd like), as described in ["ADDING STOPWORDS" in Pod::Spell](http://search.cpan.org/perldoc?Pod::Spell#ADDING STOPWORDS):

    =for stopwords foo bar baz

## installer

The installer back-end(s) to use (can be specified more than once); defaults
to `MakeMaker::Fallback`
and `ModuleBuildTiny` (which generates a `Build.PL` for normal use, and
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

- `github`

    (default)
    metadata and release plugins are tailored to [github](http://github.com).

- `gitmo`

    metadata and release plugins are tailored to
    [http://git.moose.perl.org](http://search.cpan.org/perldoc?gitmo@git.moose.perl.org).

- `p5sagit`

    metadata and release plugins are tailored to
    [http://git.shadowcat.co.uk](http://search.cpan.org/perldoc?p5sagit@git.shadowcat.co.uk).

- `catagits`

    metadata and release plugins are tailored to
    [http://git.shadowcat.co.uk](http://search.cpan.org/perldoc?catagits@git.shadowcat.co.uk).

- `none`

    no special configuration of metadata (relating to repositories etc) is done --
    you'll need to provide this yourself.

## other customizations

This bundle makes use of [Dist::Zilla::Role::PluginBundle::PluginRemover](http://search.cpan.org/perldoc?Dist::Zilla::Role::PluginBundle::PluginRemover) and
[Dist::Zilla::Role::PluginBundle::Config::Slicer](http://search.cpan.org/perldoc?Dist::Zilla::Role::PluginBundle::Config::Slicer) to allow further customization.
Plugins are not loaded until they are actually needed, so it is possible to
`--force`\-install this plugin bundle and `-remove` some plugins that do not
install or are otherwise problematic.

# NAMING SCHEME

This distribution follows best practices for author-oriented plugin bundles; for more information,
see [KENTNL's distribution](http://search.cpan.org/perldoc?Dist::Zilla::PluginBundle::Author::KENTNL#NAMING-SCHEME).

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
