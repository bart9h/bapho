package picture;

#{# use

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use SDL::Surface;

use args qw/%args/;

#}#

sub new ($)
{#
	my $path = shift;

	if ($path =~ m|^
		$args{basedir}
		(.*/)?
		(?<key>[^.]+)\.
		([^.]+\.)*
		(?<ext>[^.]+)
	$|x) {
		bless {
			key => $+{key},
			ext => $+{ext},
			path => $path,
			loaded => 0,
			surface => undef,
		};
	}
	else {
		warn "strange filename ($path)";
		return undef;
	}
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

sub load ($)
{#
	my ($self) = @_;

	say "loading $self->{path}"  if $args{verbose};

	if ($self->{path} =~ m/\.cr2$/i)
	{# load preview or thumbnail image from exif

		use Image::ExifTool;
		my $exif = Image::ExifTool->new;
		$exif->Options (Binary => 1);

		my $info = $exif->ImageInfo ($self->{path});

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
		eval { SDL::Surface->new (-name => $self->{path}) };
	}
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

	given ($self->{ext}) {
		when (/^(cr2|ufraw)$/i) { system "ufraw $self->{path}"; }
		default { system "gimp $self->{path} &"; }
	}
}#

1;
# vim600:fdm=marker:fmr={#,}#:
