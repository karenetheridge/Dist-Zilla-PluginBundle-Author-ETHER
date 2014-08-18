package # hide from PAUSE
    Helper;

use parent 'Exporter';
our @EXPORT = qw(all_plugins_in_prereqs);

use Test::More;
use List::MoreUtils 'uniq';
use Path::Tiny;
use JSON::MaybeXS;

# checks that all plugins in use are in the plugin bundle dist's runtime
# requires list
# - some plugins can be marked 'additional' - must be in recommended prereqs
#   AND the built dist's develop requires list
# - some plugins can be explicitly exempted (added manually to faciliate
#   testing)
sub all_plugins_in_prereqs
{ SKIP: {
    skip('this test requires a built dist', 1) if not -f 'META.json';

    my ($tzil, %options) = @_;

    my %additional = map { $_ => undef } @{ $options{additional} // [] };
    my %exempt = map { $_ => undef } @{ $options{exempt} // [] };

    my $pluginbundle_meta = decode_json(path('META.json')->slurp_raw);
    my $dist_meta = $tzil->distmeta;

    subtest 'all plugins in use are specified as *required* runtime prerequisites by the plugin bundle, or develop prerequisites by the distribution' => sub {
        foreach my $plugin (uniq map { $_->meta->name } @{$tzil->plugins})
        {
            note($plugin . ' is explicitly exempted; skipping'), next
                if exists $exempt{$plugin};
            next if $plugin eq 'Dist::Zilla::Plugin::FinderCode';  # added automatically by dist builder

            if (exists $additional{$plugin})
            {
                ok(
                    exists $dist_meta->{prereqs}{develop}{requires}{$plugin},
                    $plugin . ' is a develop prereq of the distribution',
                ) or diag 'got dist metadata: ', explain $dist_meta;

                ok(
                    exists $pluginbundle_meta->{prereqs}{runtime}{recommends}{$plugin},
                    $plugin . ' is a runtime recommendation of the plugin bundle',
                ) or diag 'got plugin bundle metadata: ', explain $pluginbundle_meta;
            }
            else
            {
                ok(
                    exists $pluginbundle_meta->{prereqs}{runtime}{requires}{$plugin},
                    $plugin . ' is a runtime prereq of the plugin bundle',
                ) or diag 'got plugin bundle metadata: ', explain $pluginbundle_meta;
            }
        }
    }
} }

1;
