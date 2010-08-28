package PictureItr;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use FileItr;

#}#

sub new
{my ($class, $path) = @_;

	bless my $self = {}, $class;
	$self->{itr} = FileItr->new($path);
	$self->{id} = path2id($self->{itr}->path) or $self->seek(1);

	$self->pvt__collect;
}#

sub seek
{my ($self, $dir) = @_;

	while($dir) {
		my $d = $dir>0?1:-1;
		while(1) {
			$self->{itr}->pvt__seek($d);
			my $id = path2id($self->{itr}->path);
			next unless defined $id;
			if ($id ne $self->{id}) {
				$self->{id} = $id;
				last;
			}
		}
		$dir -= $d;
	}

	$self->pvt__collect;
}#

sub path
{my ($self) = @_;

	$self->{itr}->path;
}#

sub path2id
{my ($path) = @_;

	$path =~ m{^(.*)\.[^.]+$};
	$1 // '';
}#

sub pvt__collect
{my ($self) = @_;

	$self->{files} = [];

	$self->{itr}->seek(-1) while path2id($self->{itr}->path) eq $self->{id};
	$self->{itr}->seek(+1);

	while (path2id($self->{itr}->path) eq $self->{id}) {
		push @{$self->{files}}, $self->{itr}->path;
		$self->{itr}->seek(+1);
	}
	$self->{itr}->seek(-1);
	$self;
}#

1;
# vim600:fdm=marker:fmr={my,}#:
