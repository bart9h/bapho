package Text;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use args qw/%args max/;
use SDL::Video;
use SDL::Surface;
use SDL::TTF;
use SDL::TTF::Font;
use SDL::Color;

#}#

sub new
{#{my}

	(SDL::TTF::init() == 0) or die;

	bless my $self = {
		border => 8,
		fonts => [],
		font => 0,
		white  => SDL::Color->new(255, 255, 255),
		yellow => SDL::Color->new(255, 255, 0),
		black  => SDL::Color->new(0, 0, 0),
	};

	$self->home;

	my ($name, $size);
	foreach (@_) {

		my @a = split /:/;

		$name = $a[0]  unless $a[0] eq '';
		defined $name or die 'must specify font name';

		$size = $a[1]  if $a[1];
		$size or die 'size must be positive';

		my $file = `fc-match -v '$name' | grep file: | cut -d \\\" -f 2`;
		chomp $file;
		-f $file  or die "$file not found";

		push @{$self->{fonts}}, {
			fill => SDL::TTF::Font->new($file, $size),
			border => SDL::TTF::Font->new($file, $size),
		};
	}

	$self;
}#

sub home
{my ($self) = @_;

	map { $self->{$_} = $self->{border} } qw/x y x0 y0 max_x/;
	$self->set_column;
}#

sub print
{my ($self, $surf, @args) = @_;

	my $taller_font;
	my $box_width;

	$box_width += 2*$self->{border};
	foreach my $mode ('layout', 'draw') {
		my $color = $self->{white};
		for (my $i = 0;  $i < $#args;  $i += 2) {
			my ($cmd, $arg) = ($args[$i], $args[$i+1]);
			given ($cmd) {
				when (/font/) {
					$self->{font} = $arg;
				}
				when (/color/) {
					$color = $self->{$arg};
				}
				when (/text/) {
					my $font        = $self->{fonts}->[$self->{font}]->{fill}    or die;
					my $font_border = $self->{fonts}->[$self->{font}]->{border}  or die;

					my ($w) = @{ SDL::TTF::size_text($font, $arg) };

					if ($mode eq 'layout') {
						$taller_font = $font
							if not defined $taller_font
							or SDL::TTF::font_height($taller_font) > SDL::TTF::font_height($font);
						$box_width += $w;
					}
					else {
						my $x0 = $self->{x};
						my $y0 = $self->{y} + SDL::TTF::font_ascent($taller_font) - SDL::TTF::font_ascent($font);

						sub do_print
						{my ($font, $surf, $x, $y, $color, $text) = @_;

							my $ts = SDL::TTF::render_text_solid($font, $text, $color);
							my $r = SDL::Rect->new($x, $y, SDL::Surface::w($ts), SDL::Surface::w($ts));
							SDL::Video::blit_surface($ts, undef, $surf, $r);
						}#

						for(my $x = $x0-1; $x <= $x0+1; $x+=2) {
							for(my $y = $y0-1; $y <= $y0+1; $y+=2) {
								do_print($font_border, $surf, $x, $y, $self->{black}, $arg);
							}
						}

						do_print($font, $surf, $x0, $y0, $color, $arg);
						$self->{x} += $w;
					}
				}
				default { die }
			}
		}

		if ($mode eq 'layout') {
			my $height = .5*$self->{border} + SDL::TTF::font_height($taller_font);
			my $shade = SDL::Surface->new(0, $box_width, $height);
			SDL::Video::fill_rect($shade,
				SDL::Rect->new(0, 0, $shade->w, $shade->h), #FIXME: SDL::NULL should work
				SDL::Video::map_RGBA($shade->format, 0, 0, 0, 0x40)
			);
			SDL::Video::blit_surface($shade, undef, $surf,
				SDL::Rect->new($self->{x}-$self->{border}, $self->{y}, $box_width, $height)
			);
		}
	}

	$self->{max_x} = max($self->{max_x}, $self->{x});
	my $h = SDL::TTF::font_height($taller_font);
	$self->{y} += $h;
	if ($self->{y}+$h > $surf->height) { #aki tb
		$self->{y} = $self->{y0};
		$self->{x0} = $self->{max_x} + $self->{border};
		$self->{max_x} = 0;
	}
	$self->{x} = $self->{x0};
}#

sub set_column
{my ($self, $surf, @args) = @_;

	$self->{max_x} = 0;
	$self->{y0} = $self->{y};
}#

#{my system sanity check
	$_ = `which fc-match`;
	chomp;
	-x or die 'fc-match not found.  fontconfig is required.';
#}#
1;
# vim600:fdm=marker:fmr={my,}#:
