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
		key => $_[0],
		files => {},
		tags => {},
		loaded => 0,
		sel => undef,
		surface => undef,
	};
}#

sub add ($$)
{#
	my ($self, $path) = @_;
	die 'duplicate file'  if exists $self->{files}->{$path};

	$path =~ m{^(.*)/[^.]+\.([^/]+)} or die;
	my ($dir, $ext) = ($1, $2);
	die "$path\nalso exists in\n$self->{dir}\n"
		if exists $self->{dir} and $self->{dir} ne $dir;
	$self->{dir} //= $dir;

	given ($ext) {
		when (/^tags$/) {
			if (open F, $path) {
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

sub save_tags ($)
{#
	my $self = shift;
	return unless $self->{dirty};
	my $filename = "$self->{dir}/$self->{key}.tags";
	open F, '>', $filename  or die "$filename: $!";
	print F "$_\n"  foreach sort keys %{$self->{tags}};
	close F;
	$self->{dirty} = 0;
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

		return $self->{zoomed} = zoom ($self->{surface}, $self->{zoom});
	}
	else {
		die unless defined $self->{zoomed};
		return $self->{zoomed};
	}
}#

sub develop ($)
{#
	my $self = shift;

	my $file = $self->{sel};
	$file =~ s/\.[^.]+$/\.ufraw/;
	-e $file or $file = $self->{sel};

	given ($file) {
		when (/\.(cr2|ufraw)$/i) {
			system "ufraw $file &";
		}
		default {
			system "gimp $file &";
		}
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
