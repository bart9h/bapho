package dir;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

#}#

sub new
{my ($path) = @_;

	bless my $self = {
		cursor => 0,
		parent => $path,
		files  => [],
	};

	if (-d $path) {
		$self->readdir;
	}
	else {
		my $file;
		if ($path =~ m{^(.*?)/([^/]+)$}) {
			$self->{parent} = $1;
			$file = $2;
		}
		else {
			die; #TODO
		}
		$self->find($file);
	}

	return $self;
}#

sub find
{my ($self, $name) = @_;

	$self->readdir or die;
	for (; $self->{cursor} < scalar @{$self->{files}}; ++$self->{cursor}) {
		last if $self->{files}->[$self->{cursor}] eq $name;
	}
}#

sub next
{my ($self) = @_;

	if (++$self->{cursor} >= scalar @{$self->{files}}) {
		$self->{parent} =~ m{^(.*?)/([^/]+)$} or die; #TODO
		$self->{parent} = $1;
		$self->{cursor} = 0;
		$self->find($2);
		$self->next;
		my $dest = $self->{files}->[$self->{cursor}];
		if (-d $dest) {
		}
	}
	$self;
}#

sub readdir
{my ($self) = @_;

	opendir(my $dh, $self->{parent})
		|| die "opendir $self->{parent}: $!";

	$self->{files} = [
		sort { (-f $a and -d $b) ? -1 : (-d $a and -f $b) ? 1 : $a cmp $b }
		grep { not /^\./ }#and (-f or -d) }
		readdir($dh)
	];
	closedir $dh;

	die 'empty dir' unless scalar @{$self->{files}};
}#

=cut
sub seek
{my ($self, $d) = @_;

	my @a = readdir($path);
	for (my $i = 0; $i <= $#path; ++$i) {
		if ($a[$i] eq '')
	}
}#

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

=cut

1;
# vim600:fdm=marker:fmr={my,}#:
