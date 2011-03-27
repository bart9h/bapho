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
{my ($class, $path) = @_;

	bless my $self = {}, $class;
	$self->pvt__init($path);
	return $self;
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

sub up
{my ($self) = @_;

	$self->{itr}->up or return undef;
	$self->pvt__build_pic;
	return $self;
}#

sub down
{my ($self) = @_;

	my $bk_path = $self->{itr}->path;
	$self->{itr}->down or return undef;
	while(1) {
		$self->pvt__build_pic;
		return $self if $self->{pic}->{sel};
		unless ($self->{itr}->next) {
			$self->{itr}->{path} = $bk_path;
			$self->pvt__build_pic;
			return undef;
		}
	}
}#

sub first
{my ($self) = @_;

	$self->{itr}->first or return undef;
	while(1) {
		$self->pvt__build_pic;
		return $self if $self->{pic}->{sel};
		$self->{itr}->next or return undef;
	}
}#

sub last
{my ($self) = @_;

	$self->{itr}->last or return undef;
	while(1) {
		$self->pvt__build_pic;
		return $self if $self->{pic}->{sel};
		$self->{itr}->prev or return undef;
	}
}#

sub next { $_[0]->dup->seek(+1) }
sub prev { $_[0]->dup->seek(-1) }
sub path { join ',', sort keys %{$_[0]->{pic}->{files}} }
sub dup  { PictureItr->new($_[0]->{itr}->path) }

sub path2id
{my ($path) = @_;

	$path =~ m{^(.*?/?[^./]+)\.[^/]+$};
	$1 // $path;
}#

sub pvt__init
{my ($self, $path, $dir) = @_;
caller eq __PACKAGE__ or croak;

	$self->{itr} = FileItr->new($path);

	$self->{pic}->{sel} = undef;
	if ($self->{id} = path2id($self->{itr}->path)) {
		$self->pvt__build_pic;
	}

	until ($self->{pic}->{sel}) {
		$self->seek($dir // 1);
	}

	$self->{id} = path2id($self->{itr}->path);
	$self->pvt__build_pic;
}#

sub pvt__build_pic
{my ($self) = @_;
caller eq __PACKAGE__ or croak;

	$self->{pic} = Picture::new($self->{id});

	if (-d $self->{itr}->path) {
		$self->{pic}->{sel} = $self->{itr}->path;
		#TODO ...?
		return;
	}

	for(;;) { # Seek backwards

		# until the start of current dir
		$self->{itr}->prev or last;

		# or when the id change
		defined $self->{itr}->path or die;
		if (path2id($self->{itr}->path) ne $self->{id}) {
			# (in this case, step forward to get back at the first file with my id).
			my $next = $self->{itr}->next;
			$self->{itr} = $next if defined $next;
			last;
		}
	}

	for(;;) { # Then seek forward again

		# collecing the files
		$self->{pic}->add($self->{itr}->path);

		# until the end of the dir
		$self->{itr}->next or last;

		# or when the id change
		defined $self->{itr}->path or die;
		if (path2id($self->{itr}->path) ne $self->{id}) {
			# (in this case, step backward to point itr to a file with my id).
			$self->{itr}->prev;
			last;
		}
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
