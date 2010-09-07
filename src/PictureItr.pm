package PictureItr;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use FileItr;
use Picture;

#}#

sub new
{my ($class, $path) = @_;

	bless my $self = {}, $class;
	$self->{itr} = FileItr->new($path);
	if ($self->{id} = path2id($self->{itr}->path)) {
		$self->pvt__build_pic;
	} else {
		$self->seek(1);
	}
}#

sub seek
{my ($self, $dir) = @_;

	while($dir) {
		my $d = $dir>0?1:-1;
		while(1) {
			$self->{itr}->pvt__seek($d);
			local $_ = $self->{itr}->path;
			next if m{/\.bapho-state$};
			next if m{/\.([^/]*-)?trash/}i;
			next if m{/\.qiv-select/};
			next if m{/Picasa.ini$};
			my $id = path2id($_);
			next if $id eq '';
			if ($id ne $self->{id}) {
				$self->{id} = $id;
				last;
			}
		}
		$dir -= $d;
	}

	$self->pvt__build_pic;
}#

sub seek_id
{my ($self, $id) = @_;

	$self->{id} = $id;
	$id =~ m{^(.*)/([^/]+)$} or die;
	my $dir = $1;
	$self->{itr} = FileItr->new($dir);
	while(1) {
		last if path2id($self->{itr}->path) eq $id;
		$self->{itr}->seek(1);
		die if $self->{itr}->{parent} ne $dir;
	}

	$self->pvt__build_pic;
}#

sub path2id
{my ($path) = @_;

	$path =~ m{^(.*)\.[^.]+$};
	$1 // '';
}#

sub pvt__build_pic
{my ($self) = @_;

	$self->{itr}->seek(-1) while path2id($self->{itr}->path) eq $self->{id};
	$self->{itr}->seek(+1);

	$self->{pic} = Picture::new($self->{id});

	for(;;) {
		$self->{pic}->add($self->{itr}->path);
		$self->{itr}->seek(+1);
		last if path2id($self->{itr}->path) ne $self->{id};
	}
	$self->{itr}->seek(-1);
	$self;
}#

1;
# vim600:fdm=marker:fmr={my,}#:
