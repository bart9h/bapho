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
	$self->pvt__init($path);
}#

sub seek
{my ($self, $dir) = @_;

	my $bk_path = $self->{pic}->{sel};

	while($dir) {
		my $d = $dir>0?1:-1;
		while(1) {
			unless ($self->{itr}->seek($d)) {
				$self->pvt__init($bk_path);
				return undef;
			}
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

		$self->pvt__build_pic;
		next unless $self->{pic}->{sel};

		$dir -= $d;
	}

	$self;
}#

sub next { PictureItr->new($_[0]->{itr}->path)->seek(+1) }
sub prev { PictureItr->new($_[0]->{itr}->path)->seek(-1) }
sub path { join ',', sort keys %{$_[0]->{pic}->{files}} }

sub path2id
{my ($path) = @_;

	$path =~ m{^(.*)\.[^.]+$};
	$1 // '';
}#

sub pvt__init
{my ($self, $path) = @_;

	$self->{itr} = FileItr->new($path);

	if ($self->{id} = path2id($self->{itr}->path)) {
		$self->pvt__build_pic;
	}
	else {
		$self->seek(1);
	}

	until ($self->{pic}->{sel}) {
		$self->seek(1);
	}

	$self;
}#

sub pvt__build_pic
{my ($self) = @_;

	$self->{pic} = Picture::new($self->{id});

	for(;;) { # Seek backwards

		# until the start of current dir
		last if $self->{itr}->{cursor} == 0;
		$self->{itr}->{cursor}--;

		# or when the id change
		if (path2id($self->{itr}->path) ne $self->{id}) {
			# (in this case, step forward to get back at the first file with my id).
			$self->{itr}->{cursor}++;
			last;
		}
	}

	for(;;) { # Then seek backwards again

		# collecing the files
		$self->{pic}->add($self->{itr}->path);

		# until the end of the dir
		last if $self->{itr}->{cursor} == scalar @{$self->{itr}->{files}} - 1;
		$self->{itr}->{cursor}++;

		# or when the id change
		if (path2id($self->{itr}->path) ne $self->{id}) {
			# (in this case, step backward to point itr to a file with my id).
			$self->{itr}->{cursor}--;
			last;
		}
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
