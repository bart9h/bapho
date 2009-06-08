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

sub get_dummy_surface
{#
	state $surf;

	unless ($surf) {
		say ':(';
		$surf = SDL::Surface->new (-width => 256, -height => 256);
		$surf->fill (
			SDL::Rect->new (-width => 128, -height => 128, -x => 64, -y => 64),
			SDL::Color->new (-r => 200, -g => 0, -b => 0),
		);
	}

	return $surf;
}#

sub zoom ($$)
{#
	my ($surface, $zoom) = @_;
	die "SDL::Tool::Graphic::zoom requires an SDL::Surface\n"
		unless ( ref($surface) && $surface->isa('SDL::Surface'));

	my $tmp = SDL::Surface->new;
	$$tmp = SDL::GFXZoom ($$surface, $zoom, $zoom, 1);
	return $tmp;
}#

sub new ($)
{#
	bless {
		id => $_[0],
		files => {},
		tags => {},
		loaded => 0,
		dir => undef,             # dir where files are
		dirty => 0,               # has to save tags
		sel => undef,             # which file was choosen to display
		surface => undef,         # loaded SDL_Surface
		res => undef,             # dimentions of the loaded surface
		zoomed_surface => undef,  # surface scaled to display size
		zoom => undef,            # zoom factor of the zoomed_surface
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

sub load ($)
{#
	my ($self) = @_;

	say "loading $self->{sel}"  if $args{verbose};

	if ($self->{sel} =~ m/\.cr2$/i)
	{# load preview or thumbnail image from exif

		use Image::ExifTool;
		my $exif = Image::ExifTool->new;
		$exif->Options (Binary => 1);

		my $info = $exif->ImageInfo ($self->{sel});

		my $tag = 'PreviewImage';
		if (defined $info->{$tag}) {

			my $tmp = '/tmp/bapho.jpg';

			open F, '>', $tmp or die $!;
			print F ${$info->{$tag}};
			close F;

			my $surf = SDL::Surface->new (-name => $tmp);

			unlink $tmp;

			return $surf;
		}
	}#
	else {
		eval { SDL::Surface->new (-name => $self->{sel}) };
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
		my $filename = $self->tag_filename;
		open F, '>', $filename  or die "$filename: $!";
		say "saving $filename"  if $args{verbose};
		print F "$_\n"  foreach sort keys %{$self->{tags}};
		close F;
		$self->{dirty} = 0;
	}
}#

sub get_surface ($$)
{#
	my ($self, $width, $height) = @_;

	unless ($self->{loaded}) {
		$self->{loaded} = time;
		$self->{surface} = ($self->load or get_dummy_surface);
	}

	my $res = "${width}x${height}";
	if (not $self->{res} or $self->{res} ne $res) {
		$self->{res} = $res;

		my $zoom_x = $width/$self->{surface}->width;
		my $zoom_y = $height/$self->{surface}->height;
		$self->{zoom} = (sort $zoom_x, $zoom_y)[0];

		return $self->{zoomed_surface} = zoom ($self->{surface}, $self->{zoom});
	}
	else {
		die unless defined $self->{zoomed_surface};
		return $self->{zoomed_surface};
	}
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
