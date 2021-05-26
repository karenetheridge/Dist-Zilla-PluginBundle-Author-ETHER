use strict;
use warnings;
package Pod::Weaver::PluginBundle::Author::ETHER;
# vim: set ts=8 sts=2 sw=2 tw=100 et :
# ABSTRACT: A plugin bundle for pod woven by ETHER

our $VERSION = '0.161';

no if "$]" >= 5.031009, feature => 'indirect';
no if "$]" >= 5.033001, feature => 'multidimensional';
no if "$]" >= 5.033006, feature => 'bareword_filehandles';
use namespace::autoclean -also => ['_exp'];
use Pod::Weaver::Config::Assembler;
use Module::Runtime 'use_module';
use PadWalker 'peek_sub';

sub _exp { Pod::Weaver::Config::Assembler->expand_package($_[0]) }

# This sub behaves somewhat like a Dist::Zilla pluginbundle's configure() -- it returns a list of strings or 1, 2
# or 3-element arrayrefs containing plugin specifications. The goal is to make this look as close to what
# weaver.ini looks like as possible.
sub configure {
    my $self = shift;

    # I wouldn't have to do this ugliness if I could have some configuration values passed in from weaver.ini or
    # the [PodWeaver] plugin's use of config_plugin (where I could define a 'licence' option)
    my $podweaver_plugin = ${ peek_sub(\&Dist::Zilla::Plugin::PodWeaver::weaver)->{'$self'} };
    my $licence_plugin = $podweaver_plugin && $podweaver_plugin->zilla->plugin_named('@Author::ETHER/License');
    my $licence_filename = $licence_plugin ? $licence_plugin->filename : 'LICENCE';

    return (
        # equivalent to [@CorePrep]
        [ '-EnsurePod5' ],
        [ '-H1Nester' ],
        '-SingleEncoding',

        [ '-Transformer' => List => { transformer => 'List' } ],
        [ '-Transformer' => Verbatim => { transformer => 'Verbatim' } ],

        [ 'Region' => 'header' ],
        'Name',
        'Version',
        [ 'Region' => 'prelude' ],
        [ 'Generic' => 'SYNOPSIS' ],
        [ 'Generic' => 'DESCRIPTION' ],
        [ 'Generic' => 'OVERVIEW' ],

        [ 'Collect' => 'ATTRIBUTES' => { command => 'attr' } ],
        [ 'Collect' => 'METHODS'    => { command => 'method' } ],
        [ 'Collect' => 'FUNCTIONS'  => { command => 'func' } ],
        [ 'Collect' => 'TYPES'      => { command => 'type' } ],
        'Leftovers',
        [ 'Region' => 'postlude' ],

        [ 'GenerateSection' => 'generate SUPPORT' => {
                title => 'SUPPORT',
                main_module_only => 0,
                text => [ <<'SUPPORT',
{{ join("\n\n",
    ($bugtracker_email && $bugtracker_email =~ /rt\.cpan\.org/)
    ? "Bugs may be submitted through L<the RT bug tracker|$bugtracker_web>\n(or L<$bugtracker_email|mailto:$bugtracker_email>)."
    : $bugtracker_web
    ? "Bugs may be submitted through L<$bugtracker_web>."
    : (),

    $distmeta->{resources}{x_MailingList} ? 'There is also a mailing list available for users of this distribution, at' . "\nL<" . $distmeta->{resources}{x_MailingList} . '>.' : (),

    $distmeta->{resources}{x_IRC}
        ? 'There is also an irc channel available for users of this distribution, at' . "\nL<"
            . do {
                # try to extract the channel
                if (my ($network, $channel) = ($distmeta->{resources}{x_IRC} =~ m!(?:://)?(\w+(?:\.\w+)*)/?(#\w+)!)) {
                    'C<' . $channel . '> on C<' . $network . '>|' . $distmeta->{resources}{x_IRC}
                }
                else {
                    $distmeta->{resources}{x_IRC}
                }
            }
            . '>.'
        : (),

    ($distmeta->{x_authority} // '') eq 'cpan:ETHER'
    ? "I am also usually active on irc, as 'ether' at C<irc.perl.org> and C<irc.libera.chat>."
    : (),
) }}
SUPPORT
                        ] },
        ],

        [ 'AllowOverride' => 'allow override SUPPORT' => {
               header_re => '^(SUPPORT|BUGS)\b',
               action => 'prepend',
               match_anywhere => 0,
            },
        ],

        'Authors',
        [ 'AllowOverride' => 'allow override AUTHOR' => {
               header_re => '^AUTHORS?\b',
               action => 'replace',
               match_anywhere => 0,
            },
        ],

        [ 'Contributors' => { ':version' => '0.008' } ],
        [ 'Legal' => { ':version' => '4.011', header => 'COPYRIGHT AND ' . $licence_filename } ],
        [ 'Region' => 'footer' ],
    );
}

sub mvp_bundle_config {
    my $self = shift || __PACKAGE__;

    return map $self->_expand_config($_), $self->configure;
}

my $prefix;
sub _prefix {
    my $self = shift;
    return $prefix if defined $prefix;
    ($prefix = (ref($self) || $self)) =~ s/^Pod::Weaver::PluginBundle:://;
    $prefix;
}

sub _expand_config {
    my ($self, $this_spec) = @_;

    die 'undefined config' if not $this_spec;
    die 'unrecognized config format: ' . ref($this_spec) if ref($this_spec) and ref($this_spec) ne 'ARRAY';

    my ($name, $class, $payload);

    if (not ref $this_spec) {
        ($name, $class, $payload) = ($this_spec, _exp($this_spec), {});
    }
    elsif (@$this_spec == 1) {
        ($name, $class, $payload) = ($this_spec->[0], _exp($this_spec->[0]), {});
    }
    elsif (@$this_spec == 2) {
        $name = ref $this_spec->[1] ? $this_spec->[0] : $this_spec->[1];
        $class = _exp(ref $this_spec->[1] ? $this_spec->[0] : $this_spec->[0]);
        $payload = ref $this_spec->[1] ? $this_spec->[1] : {};
    }
    else {
        ($name, $class, $payload) = ($this_spec->[1], _exp($this_spec->[0]), $this_spec->[2]);
    }

    $name =~ s/^[@=-]//;

    # Region plugins have the custom plugin name moved to 'region_name' parameter,
    # because we don't want our bundle name to be part of the region name.
    if ($class eq _exp('Region')) {
        $name = $this_spec->[1];
        $payload = { region_name => $this_spec->[1], %$payload };
    }

    use_module($class, $payload->{':version'}) if $payload->{':version'};

    # prepend '@Author::ETHER/' to each class name,
    # except for Generic and Collect which are left alone.
    $name = '@' . $self->_prefix . '/' . $name
        if $class ne _exp('Generic') and $class ne _exp('Collect');

    return [ $name => $class => $payload ];
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
    :version = 0.094    ; or any higher version

=head1 DESCRIPTION

=for stopwords optimizations

This is a L<Pod::Weaver> plugin bundle. It is I<approximately> equal to the
following F<weaver.ini>, minus some optimizations:

    [-EnsurePod5]
    [-H1Nester]
    [-SingleEncoding]

    [-Transformer / List]
    transformer = List

    [-Transformer / Verbatim]
    transformer = Verbatim

    [Region / header]
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

    [Collect / TYPES]
    command = type

    [Leftovers]

    [Region / postlude]

    [GenerateSection / generate SUPPORT]
    title = SUPPORT
    main_module_only = 0
    text = <template>
    [AllowOverride / allow override SUPPORT]
    header_re = ^(SUPPORT|BUGS)\b
    action = prepend
    match_anywhere = 0

    [Authors]
    [AllowOverride / allow override AUTHOR]
    header_re = ^AUTHORS?\b
    action = replace
    match_anywhere = 0

    [Contributors]
    :version = 0.008

    [Legal]
    :version = 4.011
    header = COPYRIGHT AND <licence filename>

    [Region / footer]

This is also equivalent (other than section ordering) to:

    [-Transformer / List]
    transformer = List
    [-Transformer / Verbatim]
    transformer = Verbatim

    [Region / header]
    [@Default]

    [Collect / TYPES]
    command = type

    [GenerateSection / generate SUPPORT]
    title = SUPPORT
    main_module_only = 0
    text = <template>
    [AllowOverride / allow override SUPPORT]
    header_re = ^(SUPPORT|BUGS)
    action = prepend
    match_anywhere = 0

    [Authors]
    [Contributors]
    :version = 0.008

    [Region / footer]

=head1 OPTIONS

None at this time. (The bundle is never instantiated, so this doesn't seem to
be possible without updates to L<Pod::Weaver>.)

=head1 OVERRIDING A SPECIFIC SECTION

This F<weaver.ini> will let you use a custom C<COPYRIGHT AND LICENCE> section and still use the plugin bundle:

    [@Author::ETHER]
    [AllowOverride / OverrideLegal]
    header_re = ^COPYRIGHT
    match_anywhere = 1

=head1 ADDING STOPWORDS FOR SPELLING TESTS

As noted in L<Dist::Zilla::PluginBundle::Author::ETHER>, stopwords for
spelling tests can be added by adding a directive to pod:

    =for stopwords foo bar baz

However, if the stopword appears in the module's abstract, it is moved to the
C<NAME> section, which will be above your stopword directive. You can handle
this by declaring the stopword in the special C<header> section, which will be
woven ahead of everything else:

    =for :header
    =for stopwords foo bar baz

=head1 SEE ALSO

=for :list
* L<Pod::Weaver>
* L<Pod::Weaver::PluginBundle::Default>
* L<Dist::Zilla::Plugin::PodWeaver>
* L<Dist::Zilla::PluginBundle::Author::ETHER>
* L<Dist::Zilla::MintingProfile::Author::ETHER>

=head1 NAMING SCHEME

=for stopwords KENTNL

This distribution follows best practices for author-oriented plugin bundles; for more information,
see L<KENTNL's distribution|Dist::Zilla::PluginBundle::Author::KENTNL/NAMING-SCHEME>.

=cut
