use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Warnings;

use File::pushd;
use Test::TempDir;
use Path::Tiny;
 
use Test::DZil;
 
foreach my $dist (glob(path('t/corpus/*')))
{
    my $temp = 't/tmp';# temp_root;
    mkdir $temp;
    my $source = path($dist)->absolute->stringify;
    my $target = path($temp, path($dist)->basename);
print "### temproot is ", $temp, "\n";
print "### dir is $target\n";
#mkdir $target;
#pushd $target;
     
print "### source is ", path($dist)->absolute->stringify, "\n";
    my $tzil = Builder->from_config({ dist_root => $source });
       
# XXX how to get result of build left behind?
    $tzil->build;
    #is($tzil->build_in($target), $target, "built dist with \@Author::ETHER from $dist into $target");
print "### tempdir is ", $tzil->tempdir, "\n";
print "### files: ", join("\n", glob($tzil->tempdir . '/build/*')), "\n";
}

fail('died?') if Test::Builder->new->current_test < 1;

fail 'oh noes';
done_testing;
