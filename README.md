# NAME

Dist::Zilla::PluginBundle::Author::ETHER - A plugin bundle for distributions built by ETHER

# VERSION

version 0.006

# SYNOPSIS

In `dist.ini`:

    [@Author::ETHER]

# DESCRIPTION

This is a [Dist::Zilla](http://search.cpan.org/perldoc?Dist::Zilla) plugin bundle. It is approximately equivalent to the
following `dist.ini` (following the preamble):

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
    [Test::UnusedVars]

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
    [Prereqs / DevelopRequires]
    Dist::Zilla = <version used to built this bundle>
    Dist::Zilla::PluginBundle::Author::ETHER = <our own version>



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

    [GitHub::Update]
    metacpan = 1

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
many as you'd like), as described in ["ADDING STOPWORDS" in Pod::Spelling](http://search.cpan.org/perldoc?Pod::Spelling#ADDING STOPWORDS):

    =for stopwords foo bar baz

## other customizations

This bundle makes use of [Dist::Zilla::Role::PluginBundle::PluginRemover](http://search.cpan.org/perldoc?Dist::Zilla::Role::PluginBundle::PluginRemover) and
[Dist::Zilla::Role::PluginBundle::Config::Slicer](http://search.cpan.org/perldoc?Dist::Zilla::Role::PluginBundle::Config::Slicer) to allow further customization.

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
