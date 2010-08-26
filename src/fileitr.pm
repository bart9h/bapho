#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

#}#

package folder;

sub new
{my ($path) = @_;

	bless my $self = {
		path    => $path,
		entries => undef,
		cursor  => undef,
	};

	return $self;
}#

sub load
{my ($self) = @_;

	return if $self->{entries};

	my $dh;
	unless (opendir ($dh, $self->{path})) {
		say "can't opendir $self->{path}: $!";
		return undef;
	}

	$self->{entries} =
		map  { ref -f $_ ? $_ : folder::new($_) }
		sort { (-f $a and -d $b) ? -1 : (-d $a and -f $b) ? 1 : $a cmp $b }
		grep { not /^\./ and (-f or -d) }
		readdir($dh);

	closedir $dh;

	$self->{cursor}  = 0;

}#

sub entry
{my ($self, $idx) = @_;

	$self->{entries}->[ $idx // $self->{cursor} ];
}#

sub size
{my ($self, $idx) = @_;

	scalar @{$self->{entries}};
}#

package dir;

sub new
{my ($basedir) = @_;

	bless my $self = {
		basedir => $basedir,
		root => folder::new($basedir),
		cursor => undef,
	};

	return $self;
}#

sub pvt__first_or_last
{my ($self, $direction) = @_;

	my $i = $self->{root};
	while(1) {
		$i->load;
		return undef  unless $i->size;
		my $idx = $direction eq 'first' ? 0 : $i->size-1;
		if (!ref $i->entry($idx)) {
			return $self->{cursor} = $i->entry($idx)
		}
		$i = $i->entry($idx);
	}
}#

sub first { $_[0]->pvt__first_or_last('first') }
sub last  { $_[0]->pvt__first_or_last('last' ) }

sub next
{my ($self) = @_;

	unless ($self->{cursor}) {
		return $self->{cursor} = $self->first;
	}

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

	$self->{cursor} //= $self->last;
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
