use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;
use Test::Warnings;
use {{ $dist->name =~ s/-/::/gr }};

...;

