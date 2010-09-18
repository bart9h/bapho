package Array;
use strict;
use warnings;

sub rotate
{my ($array_ref) = @_;

	push @$array_ref, shift @$array_ref;
}#

sub find
{my ($array_ref, $needle) = @_;

	foreach (@$array_ref) {
		if ($_ eq $needle) {
			rotate $array_ref until $array_ref->[0] eq $needle;
			return 1;
		}
	}

	return 0;
}#


1;
# vim600:fdm=marker:fmr={my,}#:
