package PictureItr;

#{my uses

use strict;
use warnings;
use 5.010;
use Carp;
use Data::Dumper;

use FileItr;
use Picture;

#}#

sub new
{my ($class, $path, $jaildir) = @_;

	bless my $self = {
		jaildir => $jaildir,
	}, $class;

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
			next if m{/\.bapho-};
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

sub next { $_[0]->dup->seek(+1) }
sub prev { $_[0]->dup->seek(-1) }
sub path { join ',', sort keys %{$_[0]->{pic}->{files}} }
sub dup  { PictureItr->new($_[0]->{pic}->{sel}, $_[0]->{jaildir}) }

sub first
{my ($self) = @_;

	$self->{itr}->first;
	$self->pvt__init($self->{itr}->path);
}#

sub last
{my ($self) = @_;

	$self->{itr}->last;
	$self->pvt__init($self->{itr}->path, -1);
}#

sub path2id
{my ($path) = @_;

	$path =~ m{^(.*?/?[^./]+)\.[^/]+$};
	$1 // '';
}#

sub pvt__init
{my ($self, $path, $dir) = @_;
caller eq __PACKAGE__ or croak;
confess unless $path;
$dir //= 1;

	$self->{itr} = FileItr->new($path, $self->{jaildir});

	$self->{pic}->{sel} = undef;
	if ($self->{id} = path2id($self->{itr}->path)) {
		$self->pvt__build_pic;
	}

	until ($self->{pic}->{sel}) {
		$self->seek($dir);
	}

	$self;
}#

sub pvt__build_pic
{my ($self) = @_;
caller eq __PACKAGE__ or croak;

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

	for(;;) { # Then seek forward again

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
