package PictureItr;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use FileItr;

#}#

sub new
{my ($path) = @_;

	bless my $self = {
		itr   => FileItr::new($path),
		files => [],
	};

	$self->pvt__collect;

	print Dumper($self);
	$self;
}#

sub seek
{my ($self, $dir) = @_;

	while($dir) {
		my $d = $dir>0?1:-1;
		my $id = $self->pvt__id;
		$self->{itr}->pvt__seek($d) until $self->pvt__id ne $id;
		$dir -= $d;
	}

	$self->pvt__collect;
	print Dumper($self);
	$self;
}#

sub pvt__collect
{my ($self) = @_;

	$self->{files} = [];

	my $id = $self->pvt__id;
	$self->{itr}->seek(-1) while $self->pvt__id eq $id;
	$self->{itr}->seek(+1);

	while ($self->pvt__id eq $id) {
		push @{$self->{files}}, $self->{itr}->path;
		$self->{itr}->seek(+1);
	}
	$self->{itr}->seek(-1);

	$self->pvt__id eq $id or die;
}#

sub pvt__id
{my ($self) = @_;

	$self->{itr}->path =~ m{^(.*)\.[^.]+$} or die; #TODO
	$1;
}#

1;
# vim600:fdm=marker:fmr={my,}#:
