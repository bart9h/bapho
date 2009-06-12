package picture;

#{# use

use strict;
use warnings;
use 5.010;

use Data::Dumper;
use SDL::Surface;

use args qw/%args/;

#}#

sub extval ($)
{#
	defined $_[0]
	?
		$_[0] =~ /\.([^.]+)$/
		?
			{
				jpg => 3,
				tif => 2,
				png => 2,
				cr2 => 1,
			}->{lc $1}
			// 0
		:
			-1
	:
		-1
}#

sub new ($)
{#
	bless {
		id             => $_[0],
		files          => {},
		tags           => {},
		loaded         => 0,
		dir            => undef,  # dir where files are
		dirty          => 0,      # has to save tags?
		sel            => undef,  # which file was choosen to display
		surface        => undef,  # loaded SDL_Surface
		res            => undef,  # dimentions of the loaded surface
		zoomed_surface => undef,  # surface scaled to display size
		zoom           => undef,  # zoom factor of the zoomed_surface
	};
}#

sub add ($$)
{#
	my ($self, $path) = @_;
	die 'duplicate file'  if exists $self->{files}->{$path};

	$path =~ m{^(.*)/[^.]+\.([^/]+)} or die;
	my ($dir, $ext) = ($1, $2);
	die "$path\nalso exists in\n$self->{dir}\n"
		if defined $self->{dir} and $self->{dir} ne $dir;
	$self->{dir} //= $dir;

	given ($ext) {
		when (/^tags$/) {
			if (open F, $path) {
				$self->{tags} = {};
				foreach (<F>) {
					chomp;
					$self->{tags}->{$_} = 1;
				}
			}
		}
		when (/^ufraw$/) {
		}
		default {
			$self->{files}->{$path} = 1;
			$self->{sel} = $path  if extval($path) > extval($self->{sel});
		}
	}
}#

sub toggle_tag ($$)
{#
	my ($self, $tag) = @_;

	if (exists $self->{tags}->{$tag}) {
		delete $self->{tags}->{$tag};
	}
	else {
		$self->{tags}->{$tag} = 1;
	}

	$self->{dirty} = 1;
}#

sub tag_filename ($)
{#
	my $self = shift;
	defined $self->{dir} or die;
	"$self->{dir}/$self->{id}.tags";
}#

sub save_tags ($)
{#
	my $self = shift;

	if ($self->{dirty}) {
		unless ($args{nop}) {
			my $filename = $self->tag_filename;
			open F, '>', $filename  or die "$filename: $!";
			say "saving $filename"  if $args{verbose};
			print F "$_\n"  foreach sort keys %{$self->{tags}};
			close F;
		}
		$self->{dirty} = 0;
	}
}#

sub tags ($)
{#
	my $self = shift;
	grep {!/^_/} sort keys %{$self->{tags}};
}#

sub develop ($)
{#
	my $self = shift;

	my $file = $self->{sel};
	$file =~ s/\.[^.]+$/\.ufraw/;
	-e $file or $file = $self->{sel};

	my $cmd;
	given ($file) {
		when (/\.(cr2|ufraw)$/i) {
			$cmd = "ufraw";
		}
		default {
			$cmd = "gimp";
		}
	}
	if (defined $cmd) {
		say $cmd if $args{verbose};
		system "$cmd $file &";
	}
}#

sub delete ($)
{#
	my $self = shift;
	return if $args{nop};

	$self->{sel} =~ m{^(.*?)/([^/]+)\.[^.]+$}
		or die "strange filename ($self->{sel})";
	my ($dirname, $basename) = ($1, $2);
	my $trash = "$dirname/.bapho-trash";
	-d $trash or print `mkdir -v "$trash"`;
	while (<$dirname/$basename.*>) {
		print `mv -v "$_" "$trash/"`;
	}
}#

1;
# vim600:fdm=marker:fmr={#,}#:
