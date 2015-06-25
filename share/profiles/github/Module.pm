use strict;
use warnings;
package {{ $name }};
# ABSTRACT: ...
# KEYWORDS: ...
# vim: set ts=8 sts=4 sw=4 tw=78 et :

our $VERSION = '{{ $dist->version }}';

{{
    ($zilla_plugin) = ($name =~ /^Dist::Zilla::Plugin::(.+)$/g);

$zilla_plugin ? <<'PLUGIN'
use Moose;
with 'Dist::Zilla::Role::...';

use namespace::autoclean;

around dump_config => sub
{
    my ($orig, $self) = @_;
    my $config = $self->$orig;

    $config->{+__PACKAGE__} = {
        ...
    };

    return $config;
};


__PACKAGE__->meta->make_immutable;
PLUGIN
: "\n1;\n"
}}__END__

=pod

=head1 SYNOPSIS

{{
$zilla_plugin ? <<SYNOPSIS
In your F<dist.ini>:

    [$zilla_plugin]
SYNOPSIS
: <<SYNOPSIS
    use $name;

    ...
SYNOPSIS
}}
=head1 DESCRIPTION

{{ $zilla_plugin ? 'This is a L<Dist::Zilla> plugin that' : '' }}...

=head1 {{ $zilla_plugin ? 'CONFIGURATION OPTIONS' : 'FUNCTIONS/METHODS' }}

=head2 C<foo>

...

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name={{ $dist->name }}>
(or L<bug-{{ $dist->name }}@rt.cpan.org|mailto:bug-{{ $dist->name }}@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=head1 ACKNOWLEDGEMENTS

...

=head1 SEE ALSO

=for :list
* L<foo>

=cut
