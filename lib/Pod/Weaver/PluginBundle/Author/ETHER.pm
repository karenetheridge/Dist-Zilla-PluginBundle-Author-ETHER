use strict;
use warnings;
package Pod::Weaver::PluginBundle::Author::ETHER;
# ABSTRACT: A plugin bundle for pod woven by ETHER
# vim: set ts=8 sts=4 sw=4 tw=78 et :

our $VERSION = '0.095';

use namespace::autoclean -also => ['_exp'];

use Pod::Weaver::Config::Assembler;
sub _exp { Pod::Weaver::Config::Assembler->expand_package($_[0]) }

sub mvp_bundle_config {
  return (
    [ '@Author::ETHER/CorePrep',        _exp('@CorePrep'), {} ],
    [ '@Author::ETHER/SingleEncoding',  _exp('-SingleEncoding'), {} ],
    [ '@Author::ETHER/Name',            _exp('Name'),      {} ],
    [ '@Author::ETHER/Version',         _exp('Version'),   {} ],

    [ '@Author::ETHER/prelude',         _exp('Region'),    { region_name => 'prelude'  } ],
    [ 'SYNOPSIS',                       _exp('Generic'),   {} ],
    [ 'DESCRIPTION',                    _exp('Generic'),   {} ],
    [ 'OVERVIEW',                       _exp('Generic'),   {} ],

    [ 'ATTRIBUTES',                     _exp('Collect'),   { command => 'attr'   } ],
    [ 'METHODS',                        _exp('Collect'),   { command => 'method' } ],
    [ 'FUNCTIONS',                      _exp('Collect'),   { command => 'func'   } ],

    [ '@Author::ETHER/Leftovers',       _exp('Leftovers'), {} ],

    [ '@Author::ETHER/postlude',        _exp('Region'),    { region_name => 'postlude' } ],

    [ '@Author::ETHER/Authors',         _exp('Authors'),   {} ],
    [ '@Author::ETHER/Contributors',    _exp('Contributors'), { ':version' => '0.008' } ],
    [ '@Author::ETHER/Legal',           _exp('Legal'),     {} ],

    [ '@Author::ETHER/List',            _exp('-Transformer'), { 'transformer' => 'List' } ],
  )
}

1;
__END__

=pod

=head1 SYNOPSIS

In your F<weaver.ini>:

    [@Author::ETHER]

Or in your F<dist.ini>

    [PodWeaver]
    config_plugin = @Author::ETHER

It is also used automatically when your F<dist.ini> contains:

    [@Author::ETHER]
    :version = 0.094

=head1 DESCRIPTION

=for stopwords optimizations

This is a L<Pod::Weaver> plugin bundle. It is I<approximately> equal to the
following F<weaver.ini>, minus some optimizations:

    [@CorePrep]

    [-SingleEncoding]

    [Name]
    [Version]

    [Region / prelude]

    [Generic / SYNOPSIS]
    [Generic / DESCRIPTION]
    [Generic / OVERVIEW]

    [Collect / ATTRIBUTES]
    command = attr

    [Collect / METHODS]
    command = method

    [Collect / FUNCTIONS]
    command = func

    [Leftovers]

    [Region / postlude]

    [Authors]
    [Contributors]
    :version = 0.008

    [Legal]

    [-Transformer / List]
    transformer = List

This is also equivalent (other than section ordering) to:

    [@Default]
    [Contributors]
    :version = 0.008

    [-Transformer / List]
    transformer = List

=head1 OPTIONS / OVERRIDES

None at this time. (The bundle is never instantiated, so this doesn't seem to
be possible without updates to L<Pod::Weaver>.)

=head1 SEE ALSO

=for :list
L<Pod::Weaver>
L<Pod::Weaver::PluginBundle::Default>
L<Dist::Zilla::Plugin::PodWeaver>

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-PluginBundle-Author-ETHER>
(or L<bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org|mailto:bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=head1 NAMING SCHEME

=for stopwords KENTNL

This distribution follows best practices for author-oriented plugin bundles; for more information,
see L<KENTNL's distribution|Dist::Zilla::PluginBundle::Author::KENTNL/NAMING-SCHEME>.

=cut
