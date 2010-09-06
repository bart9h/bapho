package FileItr;

#{my documentation

=head1 SYNOPSIS

	my $file = FileItr->new("/some/path");
	$file->seek(+1);
	say $file->path;

=cut

#}#

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

#}#

sub new
{my ($class, $path) = @_;

	bless my $self = {
		cursor => 0,
		parent => $path,
		files  => [],
	}, $class;

	if (-d $path) {
		$self->pvt__readdir;
		$self->pvt__down(1);
	}
	else {
		$self->pvt__up;
	}

	$self;
}#

sub path
{my ($self) = @_;

	$self->{parent}.'/'.$self->{files}->[$self->{cursor}];
}#

sub seek
{my ($self, $dir) = @_;

	while($dir) {
		my $d = $dir>0?1:-1;
		$self->pvt__seek($d);
		$dir -= $d;
	}
	$self;
}#


sub pvt__seek
{my ($self, $dir) = @_;

	$self->{cursor} += $dir;
	if ($self->{cursor} >= 0 and $self->{cursor} < scalar @{$self->{files}}) {
		$self->pvt__down($dir);
	}
	else {
		$self->pvt__up;
		$self->pvt__seek($dir);
		$self->pvt__down($dir);
	}
}#

sub pvt__up
{my ($self) = @_;

	$self->{parent} =~ m{^(.*?)/([^/]+)$} or die; #TODO
	$self->{parent} = $1;
	$self->pvt__find($2);
}#

sub pvt__down
{my ($self, $dir) = @_;

	while (-d $self->path) {
		$self->{parent} = $self->path;
		$self->pvt__readdir;
		$self->{cursor} = scalar @{$self->{files}} - 1
			if $dir == -1;
	}
}#

sub pvt__find
{my ($self, $name) = @_;

	$self->pvt__readdir;
	for (; $self->{cursor} < scalar @{$self->{files}}; ++$self->{cursor}) {
		last if $self->{files}->[$self->{cursor}] eq $name;
	}
	$self;
}#

sub pvt__readdir
{my ($self) = @_;

	opendir(my $dh, $self->{parent})
		|| die "opendir $self->{parent}: $!";

	$self->{files} = [
		sort { (-f $a and -d $b) ? -1 : (-d $a and -f $b) ? 1 : $a cmp $b }
		grep { not /^\./ } #and (-f $_ or -d $_) }
		readdir($dh)
	];
	closedir $dh;

	die "empty dir \"$self->{parent}\""  unless scalar @{$self->{files}};  #TODO: nao morrer
	$self->{cursor} = 0;
	$self;
}#

1;
# vim600:fdm=marker:fmr={my,}#:
