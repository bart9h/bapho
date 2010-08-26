#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

#}#

package folder;

sub new
{my ($path) = @_;

	unless (opendir (my $dh, $path)) {
		say "can't opendir $path: $!";
		return undef;
	}

	my @entries =
		sort { (-f $a and -d $b) ? -1 : (-d $a and -f $b) ? 1 : $a cmp $b }
		grep { not /^\./ and (-f or -d) }
		readdir($dh);
	closedir $dh;

	@entries or return undef;

	bless my $self = {
		entries => \@entries,
		cursor => 0,
	};

	return $self;
}#

sub entry
{my ($self, $idx) = @_;

	return $self->{entries}->[$idx];
}#

package dir;

sub new
{my ($basedir) = @_;

	bless my $self = {
		basedir => $basedir,
		root => undef,
		cursor => undef,
	};

	return $self;
}#

sub first
{my ($self) = @_;

}#

sub next
{my ($self) = @_;

	$self->{cursor} //= $self->first;

	my $dir;
	if (-d $path) {
		$dir = $path;
	}
	else {
		$path =~ m{^(.*)/[^/]+$} or die;
		$dir = $1;
		-d $dir or die;
	}
}#

sub prev
{my ($self) = @_;
}#

sub readdir
{my ($path) = @_;

	unless (opendir (my $dh, $path)) {
		say "can't opendir $path: $!";
		return ();
	}

	my @entries =
		sort { (-f $a and -d $b) ? -1 : (-d $a and -f $b) ? 1 : $a cmp $b }
		grep { not /^\./ and (-f or -d) }
		readdir($dh);
	closedir $dh;

	return @entries;
}#

1;
# vim600:fdm=marker:fmr={my,}#:
