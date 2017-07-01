use strict;
use warnings;

# patch modules that hit the network, to be sure we don't do this during
# testing.
{
    use HTTP::Tiny;
    package # hide from AutoPrereqs-provides heuristic
        HTTP::Tiny;
    no warnings 'redefine';
    sub get { die "HTTP::Tiny::get called for $_[1]" }
    sub mirror { die "HTTP::Tiny::mirror called for $_[1]" }
}

{
    use LWP::UserAgent;
    package # hide from AutoPrereqs-provides heuristic
        LWP::UserAgent;
    no warnings 'redefine';
    sub new { die "LWP::UserAgent::new called for $_[1]" }
}
1;
