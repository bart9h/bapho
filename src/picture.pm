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

	unless ($path =~ m{$args{basedir}/([^.]+?)\.([^.]+)$}) {
		warn "strange filename ($path)";
		return undef;
	}

	bless {
		key => $1,
		ext => $2,
		path => $path,
		loaded => 0,
		surface => undef,
	};
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

	$surf;
}#

sub load_file ($)
{#
	my ($path) = @_;

	say "loading $path";

	if ($path =~ m/\.cr2$/i)
	{# load preview or thumbnail image from exif

		use Image::ExifTool;
		my $exif = Image::ExifTool->new;
		$exif->Options (Binary => 1);

		my $info = $exif->ImageInfo ($path);

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
		return SDL::Surface->new (-name => $path);
	}
}#

sub get_surface ($$)
{#
	my ($self, $width, $height) = @_;

	unless ($self->{loaded}) {
		$self->{loaded} = 1;
		$self->{surface} = load_file ($self->{path}) or get_dummy_surface;
	}

	my $res = "${width}x${height}";
	if (not $self->{res} or $self->{res} ne $res) {
		$self->{res} = $res;

		my $zoom_x = $width/$self->{surface}->width;
		my $zoom_y = $height/$self->{surface}->height;
		$self->{zoom} = (sort $zoom_x, $zoom_y)[0];
		use SDL::Tool::Graphic;
		return SDL::Tool::Graphic->zoom ($self->{surface}, $self->{zoom}, $self->{zoom}, 1);
	}
	else {
		return $self->{surface};
	}
}#

1;
# vim600:fdm=marker:fmr={#,}#:
