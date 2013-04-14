use strict;
use warnings;
package Dist::Zilla::PluginBundle::Author::ETHER;
# ABSTRACT: A plugin bundle for distributions built by ETHER

use Moose;
with 'Dist::Zilla::Role::PluginBundle::Easy';

sub configure
{
    my $self = shift;

    $self->add_plugins(
        [ 'Git::GatherDir' => { exclude_filename => 'LICENSE' } ],
    );

    $self->add_bundle(
        Filter => {
            '-bundle' => '@Basic',
            '-remove' => [ 'GatherDir', 'ExtraTests' ],
        },
    );

    $self->add_plugins(
        [ 'Git::NextVersion'    => { version_regexp => '^v([\d._]+)(-TRIAL)?$' } ],
        [ 'AutoMetaResources'   => { 'bugtracker.rt' => 1, homepage => 'http://metacpan.org/module/%{dist}' } ],
        'GithubMeta', #         => { homepage => 'http://metacpan.org/module/' . $main_module } ],
        [ 'Authority'           => { authority => 'cpan:ETHER' } ],
        'AutoPrereqs',
        [ 'MetaNoIndex'         => { directory => [ qw(t xt examples) ] } ],
        [ 'MetaProvides::Package' => { meta_noindex => 1 } ],

        #;[ContributorsFromGit]

        'InstallGuide',
        'MetaConfig',
        'MetaJSON',
        'Git::Describe',
        'PkgVersion',
        'MinimumPerl',

        [ 'CopyFilesFromBuild'  => { copy => 'LICENSE' } ],
        'PodWeaver',
        #;[%PodWeaver]

        [ 'ReadmeAnyFromPod'    => { type => 'markdown', filename => 'README.md', location => 'root' } ],
        'NoTabsTests',
        'EOLTests',
        'PodSyntaxTests',
        'PodCoverageTests',
        #;[Test::Pod::LinkCheck]     many outstanding bugs
        'Test::Pod::No404s',
        'Test::PodSpelling',
        [ 'Test::Compile'       => { fail_on_warning => 1, bail_out_on_fail => 1 } ],
        [ 'Test::MinimumVersion' => { ':version' => 2.000003, max_target_perl => '5.008008' } ],
        'MetaTests',
        'Test::CPAN::Changes',
        'Test::Version',
        #;[Test::UnusedVars]  ; broken in 5.16.0!
        'Test::ChangesHasContent',

        [ 'Test::CheckDeps'     => { ':version' => '0.005', fatal => 1 } ],
        'Git::CheckFor::MergeConflicts',
        'CheckPrereqsIndexed',
        'RunExtraTests',
        [ 'Git::Remote::Check'  => { remote_branch => 'master' } ],
        [ 'Git::CheckFor::CorrectBranch' => { ':version' => '0.004', release_branch => 'master' } ],
        [ 'Git::Check'          => { allow_dirty => [ qw(README.md LICENSE) ] } ],
        [ 'NextRelease'         => { ':version' => '4.300018', format => '%-8V  %{yyyy-MM-dd HH:mm:ss ZZZZ}d (%U)' } ],
        [ 'Git::Commit'         => { allow_dirty => [ qw(Changes README.md LICENSE) ], commit_msg => '%N-%v%t%n%n%c' } ],
        [ 'Git::Tag'            => { tag_format => 'v%v%t', tag_message => 'v%v%t' } ],
        'Git::Push',
        [ 'InstallRelease'      => { install_command => 'cpanm .' } ],
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

    [Git::GatherDir]
    exclude_filename = LICENSE

    [@Filter]
    -bundle = @Basic
    -remove = GatherDir
    -remove = ExtraTests

    ; use V= to override; otherwise version is incremented from last tag
    [Git::NextVersion]
    version_regexp = ^v([\d._]+)(-TRIAL)?$

    ;[GithubMeta]
    ;homepage = http://metacpan.org/module/$module

    [MetaResources]
    bugtracker.web    = http://rt.cpan.org/NoAuth/Bugs.html?Dist=$dist
    bugtracker.mailto = bug-$dist@rt.cpan.org

    [Authority]
    authority = cpan:ETHER

    [AutoPrereqs]

    [MetaNoIndex]
    directory = t
    directory = xt
    directory = examples

    [MetaProvides::Package]
    meta_noindex = 1

    ;[ContributorsFromGit]

    [InstallGuide]
    [MetaConfig]
    [MetaJSON]
    [Git::Describe]
    [PkgVersion]
    [MinimumPerl]

    [CopyFilesFromBuild]
    copy = LICENSE

    [PodWeaver]
    ;[%PodWeaver]

    [ReadmeAnyFromPod]
    type = markdown
    filename = README.md
    location = root

    [NoTabsTests]
    [EOLTests]
    [PodSyntaxTests]
    [PodCoverageTests]
    ;[Test::Pod::LinkCheck]     many outstanding bugs
    ;[Test::Pod::No404s]        ditto
    [Test::PodSpelling]

    [Test::Compile]
    fail_on_warning = 1
    bail_out_on_fail = 1

    [Test::MinimumVersion]
    :version = 2.000003
    max_target_perl = 5.008008

    [MetaTests]
    [Test::CPAN::Changes]
    [Test::Version]
    ;[Test::UnusedVars]  ; broken in 5.16.0!
    [Test::ChangesHasContent]
    ;[Test::Kwalitee]
    ;[Test::Kwalitee::Extra]

    [Test::CheckDeps]
    :version = 0.005
    fatal = 1

    [Git::CheckFor::MergeConflicts]

    [CheckPrereqsIndexed]

    [RunExtraTests]

    [Git::Remote::Check]
    remote_branch = master

    [Git::CheckFor::CorrectBranch]
    :version = 0.004
    release_branch = master

    [Git::Check]
    allow_dirty = README.md
    allow_dirty = LICENSE

    [NextRelease]
    :version = 4.300018
    format = %-8V  %{yyyy-MM-dd HH:mm:ss ZZZZ}d (%U)

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

=for Pod::Coverage configure

=head1 OPTIONS

None so far.

=head1 SUPPORT

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-PluginBundle-Author-ETHER>
(or L<mailto:bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=cut
