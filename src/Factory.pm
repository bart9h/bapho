package Factory;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use SDL::Surface;
use Image::ExifTool;

use args qw/%args/;

#}#

sub new
{#{my constructor}

	sub get_cache_size
	{#{my}

		if ($args{cache_size_mb}) {
			$args{cache_size_mb}*1024*1024;
		}
		else {
			my ($total_kb, $free_kb);
			if (open F, '/proc/meminfo') {
				while (<F>) {
					if (m/^MemTotal:\s+(\d+)\s+kB/) {
						$total_kb = $1;
					}
					elsif (m/^MemFree:\s+(\d+)\s+kB/) {
						$free_kb = $1;
					}
				}
				close F;
			}
			$total_kb and $free_kb or die;

			# 1/4 of total memory, or half the free memory
			my ($a, $b) = ($total_kb/4, $free_kb/2);
			return ($a>$b ? $a : $b)*1024;
		}
	}#

	bless {
		items => {},  # $filename => { $res => {surf=>,last_time_used=>,width=>,height=>} }
		loaded_files => 0,
		bytes_used => 0,
		max_bytes => get_cache_size,
	};
}#

sub get
{my ($self, $path, $width, $height) = @_;

	$self->{items}->{$path} //= {};

	my $res = pvt__res_key($width,$height);

	$self->{items}->{$path}->{$res} //= $self->pvt__create_surf($path, $width, $height);

	$self->{items}->{$path}->{$res}->{last_time_used} = time;

	#TODO: find a better time to call this?
	$self->garbage_collector;

	return
	$self->{items}->{$path}->{$res};
}#

sub garbage_collector
{my ($self) = @_;

	return if $self->{bytes_used} < $self->{max_bytes};

	foreach (
		sort {
			$a->{last_time_used} <=> $b->{last_time_used};
		} map {
			my $filename = $_;
			map {
				my $res = $_;
				{
					filename => $filename,
					res => $res,
					last_time_used => $self->{items}->{$filename}->{$res}->{last_time_used},
				}
			} keys %{$self->{items}->{$filename}};
		} keys %{$self->{items}}
	)
	{
		last if $self->{bytes_used} < $self->{max_bytes};
		say 'freeing '.$_->{filename}.' '.$_->{res}
			if $args{verbose};
		$self->{bytes_used} -= pvt__surf_bytes($self->{items}->{$_->{filename}}->{$_->{res}}->{surf});
		delete $self->{items}->{$_->{filename}}->{$_->{res}};
		$self->{loaded_files} -= 1;
	}
}#


sub pvt__res_key
{my ($width, $height) = @_;
	caller eq __PACKAGE__ or die;

	sprintf "%05dx%05d", $width, $height;
}#

sub pvt__load_exif_preview
{my ($path, $width, $height) = @_;
	caller eq __PACKAGE__ or die;

	my $exif = Image::ExifTool->new;
	$exif->Options(Binary => 1);
	my $info = $exif->ImageInfo($path);

	my $tag = ($width<=160 && $height<=120) ? 'ThumbnailImage' : 'PreviewImage';
	#FIXME: better method to do this (thumbnail size may vary)

	if (defined $info->{$tag}) {

		my $tmp = $args{temp_dir}.'/bapho-exifpreview.jpg';

		open F, '>', $tmp or die $!;
		print F ${$info->{$tag}};
		close F;

		my $surf = SDL::Surface->new(-name => $tmp);

		unlink $tmp;

		return ($surf, $info);
	}
}#

sub pvt__load_file
{my ($path, $width, $height) = @_;
	caller eq __PACKAGE__ or die;

	# width,height is only a hint to load the thumbnail instead,
	# when available (.cr2).  Returned surface is not scaled.

	say "loading $path"  if $args{verbose};

	my $item = {};

	if ($path =~ m/\.cr2$/i) {
		my ($surf, $exif) = pvt__load_exif_preview($path, $width, $height);
		$item = {
			surf   => $surf,
			width  => $exif->{ExifImageWidth},
			height => $exif->{ExifImageHeight},
			exif   => { map { $_ => $exif->{$_} } @{$args{exif_tags}} },
		};
	}
	else {
		$item->{surf} = eval { SDL::Surface->new(-name => $path) };
		if ($item->{surf}) {
			$item->{width}  = $item->{surf}->width;
			$item->{height} = $item->{surf}->height;
		}

		my $exif = Image::ExifTool->new;
		$item->{exif} = $exif->ImageInfo($path);
	}

	$item;
}#

sub pvt__get_dummy_surface
{#{my}
	caller eq __PACKAGE__ or die;

	state $surf;

	unless ($surf) {
		say ':(';
		$surf = SDL::Surface->new(-width => 256, -height => 256);
		$surf->fill(
			SDL::Rect->new(-width => 128, -height => 128, -x => 64, -y => 64),
			SDL::Color->new(-r => 200, -g => 0, -b => 0),
		);
	}

	return $surf;
}#

sub pvt__zoom
{my ($surface, $zoom) = @_;
	caller eq __PACKAGE__ or die;

	die "SDL::Tool::Graphic::zoom requires an SDL::Surface\n"
		unless (ref($surface) and $surface->isa('SDL::Surface'));

	my $tmp = SDL::Surface->new;
	$$tmp = SDL::GFXZoom($$surface, $zoom, $zoom, 1);
	return $tmp;
}#

sub pvt__surf_bytes  # estimate number of bytes used by the surface
{my ($surf) = @_;
	caller eq __PACKAGE__ or die;

	$surf->pitch * $surf->height;
}#

sub pvt__create_surf
{my ($self, $path, $width, $height) = @_;
	caller eq __PACKAGE__ or die;

	sub handicap
	{#{my ugly hack: 1 hour least-recently-used handicap}

		60*60
	}#

	sub add_picture
	{my ($self, $path, $picture) = @_;

		my $res = pvt__res_key($picture->{surf}->width, $picture->{surf}->height);
		$self->{items}->{$path}->{$res} = $picture;
		$self->{bytes_used} += pvt__surf_bytes($picture->{surf});
		$self->{loaded_files} += 1;
	}#

	my $origin;
	{#{my}
		my $res = pvt__res_key($width,$height);

		# First res larger than asked, or the largest one.
		foreach (sort keys %{$self->{items}->{$path}}) {
			$origin = $self->{items}->{$path}->{$_};
			last if $_ gt $res;
		}

		# If none were loaded, create new.
		unless (defined $origin) {

			$origin = pvt__load_file($path,$width,$height);
			$origin->{last_time_used} = time - handicap;

			if ($origin->{surf}) {
				$self->add_picture($path, $origin);
			}
			else {
				$origin->{surf} = pvt__get_dummy_surface;
			}
		}
	}#

	my $zoom = eval {
		my $zoom_x =  $width  / $origin->{surf}->width;
		my $zoom_y =  $height / $origin->{surf}->height;
		(sort $zoom_x, $zoom_y)[0];
	};

	if ($zoom >= 1) {
		return $origin;
	}
	else {
		my $item = { %$origin };
		$item->{surf} = pvt__zoom($origin->{surf}, $zoom);
		$self->add_picture($path, $item);
		$origin->{last_time_used} = time - handicap;
		return $item;
	}

}#

1;
# vim600:fdm=marker:fmr={my,}#: