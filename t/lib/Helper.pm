package # hide from PAUSE
    Helper;

use parent 'Exporter';
our @EXPORT = qw(all_plugins_are_required);

use Test::More;
use List::MoreUtils 'uniq';
use Scalar::Util 'blessed';
use Path::Tiny;
use JSON;
use Test::Deep '!blessed';

# checks that all plugins in use are in our runtime or test requires list
# optionally take a list of plugins to exempt
sub all_plugins_are_required
{ SKIP: {
    skip('this test requires a built dist', 1) if not -f 'META.json';

    my ($tzil, @extra_plugins) = @_;
    my @used_plugins = uniq map { blessed $_ } @{$tzil->plugins};

    my $meta = JSON->new->decode(path('META.json')->slurp_utf8);
    my @prereqs = uniq (keys %{$meta->{prereqs}{runtime}{requires}}), (keys %{$meta->{prereqs}{test}{requires}});

    cmp_deeply(
        \@used_plugins,
        subbagof(
            @prereqs,
            @extra_plugins,
            'Dist::Zilla::Plugin::FinderCode',  # added automatically by dist builder
        ),
        'all plugins in use are specified as *required* prerequisites',
    );
} }

1;
