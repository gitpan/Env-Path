#!/usr/local/bin/perl
# This is analogous to the ksh 'whence' builtin, except that its
# arguments are treated as patterns. Thus "whence foo*" will print
# the paths of all programs whose names match foo*.

use Env::Path qw(:all);

for (@ARGV) {
    for (PATH->Whence($_)) {
	print "$_\n";
    }
}
