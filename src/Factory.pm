package Factory;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use SDL::Surface;
use SDL::Image;
use SDL::GFX::Rotozoom ();
use Image::ExifTool;
use Folder;
use Video;

use args qw/%args dbg/;

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

	sub res_key
	{my ($width, $height) = @_;

		sprintf "%05dx%05d", $width, $height;
	}#

	sub create_surf
	{my ($self, $path, $width, $height) = @_;

		sub load_exif_preview
		{my ($path, $width, $height) = @_;

			state $exiftool //= Image::ExifTool->new;
			$exiftool->Options(Binary => 1);
			my $exif = $exiftool->ImageInfo($path);

			my $tag = ($width<=160 && $height<=120) ? 'ThumbnailImage' : 'PreviewImage';
			#FIXME: better method to do this (thumbnail size may vary)

			say "using $tag" if dbg 'file';

			if (defined $exif->{$tag}) {

				my $tmp = $args{temp_dir}.'/bapho-exifpreview.jpg';

				open F, '>', $tmp or die $!;
				print F ${$exif->{$tag}};
				close F;

				my $surf = SDL::Image::load($tmp);

				unlink $tmp;

				return ($surf, $exif);
			}
		}#

		sub load_file
		{my ($self, $path, $width, $height) = @_;
		# The $width and $height arguments are only a hint
		# to maybe load a thumbnail instead, if available (raw preview).
		# Returned surface is NOT scaled to $width x $height.

			say "loading $path"  if dbg;

			my $item = {};
			my $exif;

			if ($path =~ m{\.cr2$}) {
				($item->{surf}, $exif) = load_exif_preview($path, $width, $height);
			}
			elsif (Picture::is_vid($path)) {
				$item->{surf} = Video::load_sample_frame($path);
			}
			elsif (-d $path) {
				$item->{surf} = Folder::render_surf($path, $width, $height, $self);
			}
			else {
				#$item->{surf} = eval { SDL::Image::load($path) };
				$item->{surf} = SDL::Image::load($path);

				state $exiftool //= Image::ExifTool->new;
				$exif = $exiftool->ImageInfo($path);
			}

			if ($exif) {
				$item->{exif} = { map { $_ => $exif->{$_} } @{$args{exif_tags}} };
				$item->{width}  //= $exif->{ExifImageWidth};
				$item->{height} //= $exif->{ExifImageHeight};
			}

			if ($item->{surf}) {
				$item->{width}  //= $item->{surf}->w;
				$item->{height} //= $item->{surf}->h;
			}

			$item;
		}#

		sub origin_handicap
		{#{my ugly hack: 1 hour least-recently-used handicap}
		#
		# Surfaces used as source for a zoom should be more likely to be discarded.
		# Current solution is to substract this value to the last_time_used.

			60*60
		}#

		sub add_picture
		{my ($self, $path, $picture) = @_;

			my $res = res_key($picture->{surf}->w, $picture->{surf}->h);
			$self->{items}->{$path}->{$res} = $picture;
			$self->{bytes_used} += $picture->{surf}->pitch * $picture->{surf}->h;
			$self->{loaded_files} += 1;
		}#

		sub get_dummy_surface
		{#{my}

			state $surf;

			unless ($surf) {
				say ':(';
				$surf = SDL::Surface->new(0, 256, 256);
				SDL::Video::fill_rect(
					$surf,
					SDL::Rect->new(64, 64, 128, 128),
					SDL::Video::map_RGB($surf->format, 200, 0, 0),
				);
			}

			return $surf;
		}#

		sub zoom
		{my ($surface, $zoom) = @_;

			die "SDL::Tool::Graphic::zoom requires an SDL::Surface\n"
				unless (ref($surface) and $surface->isa('SDL::Surface'));

			return SDL::GFX::Rotozoom::zoom_surface($surface, $zoom, $zoom, SDL::GFX::Rotozoom::SMOOTHING_ON);
		}#

		my $origin;
		{#{my}
			my $res = res_key($width,$height);

			# First res larger than asked, or the largest one.
			foreach (sort keys %{$self->{items}->{$path}}) {
				$origin = $self->{items}->{$path}->{$_};
				last if $_ gt $res;
			}

			# If none were loaded, create new.
			unless (defined $origin) {

				$origin = $self->load_file($path,$width,$height);

				if ($origin->{surf}) {
					$self->add_picture($path, $origin);
				}
				else {
					$origin->{surf} = get_dummy_surface;
				}
			}
		}#

		my $zoom = eval {
			my $zoom_x =  $width  / $origin->{surf}->w;
			my $zoom_y =  $height / $origin->{surf}->h;
			(sort $zoom_x, $zoom_y)[0];
		};

		if ($zoom >= 1) {
			return $origin;
		}
		else {
			my $item = { %$origin };
			$item->{surf} = zoom($origin->{surf}, $zoom);
			$self->add_picture($path, $item);
			$origin->{last_time_used} = time - origin_handicap;
			return $item;
		}

	}#

	$self->{items}->{$path} //= {};

	my $res = res_key($width,$height);

	$self->{items}->{$path}->{$res} //= $self->create_surf($path, $width, $height);

	$self->{items}->{$path}->{$res}->{last_time_used} = time;

	#TODO: find a better time to call this?
	$self->garbage_collector;

	return
	$self->{items}->{$path}->{$res};
}#

sub garbage_collector
{my ($self) = @_;

	printf "%.02f (%.0f%%) used / %.02f max MB\n",
			$self->{bytes_used}/(1024*1024),
			$self->{bytes_used}*100.0/$self->{max_bytes},
			$self->{max_bytes}/(1024*1024)
		if dbg 'cache,memory,gc';

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

		my $surf = $self->{items}->{$_->{filename}}->{$_->{res}}->{surf};
		my $surf_bytes = $surf->pitch * $surf->h;
		printf "freeing %.2f MB from $_->{filename} @ $_->{res}\n", $surf_bytes/(1024*1024)
			if dbg 'cache,memory,gc';
		$self->{bytes_used} -= $surf_bytes;
		delete $self->{items}->{$_->{filename}}->{$_->{res}};
		$self->{loaded_files} -= 1;
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
