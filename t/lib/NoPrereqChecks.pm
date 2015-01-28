use strict;
use warnings;

# patch this plugin, to make darned sure it doesn't run for users during
# tests, because it's going to fail if they haven't satisfied develop prereqs.
if (eval { require Dist::Zilla::Plugin::EnsurePrereqsInstalled; 1 })
{
    require Moose::Util;
    my $meta = Moose::Util::find_meta('Dist::Zilla::Plugin::EnsurePrereqsInstalled');
    $meta->make_mutable;
    $meta->add_around_method_modifier(register_component => sub { die 'loading [EnsurePrereqsInstalled]!' });
}

1;
