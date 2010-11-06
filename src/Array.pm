package Array;
use strict;
use warnings;

sub rotate
{my ($array_ref) = @_;

	push @$array_ref, shift @$array_ref;
}#

sub find
{my ($array_ref, $needle) = @_;

	foreach (0 .. $#$array_ref) {
		return $_ if $array_ref->[$_] eq $needle;
	}

	undef;
}#


1;
# vim600:fdm=marker:fmr={my,}#:
