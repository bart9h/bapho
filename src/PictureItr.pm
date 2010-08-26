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

	my $id = $self->pvt__id;
	$self->{itr}->seek(-1) while $self->pvt__id eq $id;
	$self->{itr}->seek(+1);
	while ($self->pvt__id eq $id) {
		push @{$self->{files}}, $self->{itr}->path;
		$self->{itr}->seek(+1);
	}
	$self->{itr}->seek(-1);
	$self->pvt__id eq $id or die;

	print Dumper($self);
	$self;
}#

sub pvt__id
{my ($self) = @_;

	$self->{itr}->path =~ m{^(.*)\.[^.]+$} or die; #TODO
	$1;
}#

1;
# vim600:fdm=marker:fmr={my,}#:
