use strict;
use warnings;
package Dist::Zilla::MintingProfile::Author::ETHER;
# ABSTRACT: Mint distributions like ETHER does

use Moose;
with 'Dist::Zilla::Role::MintingProfile::ShareDir';
use namespace::autoclean;

__PACKAGE__->meta->make_immutable;
1;
__END__

=pod

=head1 SYNOPSIS

    dzil new -P Author::ETHER -p github Foo::Bar

or:

    #!/bin/bash
    newdist() {
        local dist=$1
        local module=`perl -we"print q{$dist} =~ s/-/::/r"`
        pushd ~/git
        dzil new -P Author::ETHER -p github $module
        cd $dist
    }
    newdist Foo-Bar

=head1 DESCRIPTION

The new distribution is packaged with L<Dist::Zilla> using
L<Dist::Zilla::PluginBundle::Author::ETHER>.

Profiles available are:

=begin :list

* C<github>

Creates a distribution hosted on L<github|http://github.com>, with hooks to determine the
module version and other metadata from git. Issue tracking is disabled, as RT
is selected as the bugtracker in the distribution's metadata (via the plugin
bundle).

You will be prompted to create a repository on github immediately; if you
decline, you must create one manually before you do your first C<push>.

=end :list

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-PluginBundle-Author-ETHER>
(or L<bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org|mailto:bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=cut
