use strict;
use warnings;
package Dist::Zilla::MintingProfile::Author::ETHER;
# ABSTRACT: Mint distributions like ETHER does

use Moose;
with 'Dist::Zilla::Role::MintingProfile::ShareDir';

__PACKAGE__->meta->make_immutable;
1;
__END__

=pod

=head1 SYNOPSIS

dzil new -P Author::ETHER New::Module

=head1 DESCRIPTION

Profiles available are:

=begin :list

* C<github>

Creates a distribution hosted on L<http://github>.

* C<default>

Maps to C<github>.

=end :list

=head1 SUPPORT

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-PluginBundle-Author-ETHER>
(or L<mailto:bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=cut
