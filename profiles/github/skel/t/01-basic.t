use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Warnings;
use {{ $dist->name =~ s/-/::/gr }};

fail('this test is TODO!');

done_testing;
