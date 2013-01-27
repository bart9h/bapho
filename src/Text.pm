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
		print_error => 0,
		black => SDL::Color->new(0, 0, 0),
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
		for (my $i = 0;  $i < $#args;  $i += 2) {
			my ($cmd, $arg) = ($args[$i], $args[$i+1]);
			given ($cmd) {
				when (/font/) {
					$self->{font} = $arg;
				}
				when (/text/) {
					my $font        = $self->{fonts}->[$self->{font}]->{fill}    or die;
					my $font_border = $self->{fonts}->[$self->{font}]->{border}  or die;

					my $w;
					if (!$self->{print_error}) {
						eval {
							#FIXME $w = $font->width($arg);
							$w = 18*length($arg);
						};
						if ($@) {
							print $@;
							$self->{print_error} = 1;
						}
					}
					$w //= 12 * length $arg;

					if ($mode eq 'layout') {
						$taller_font = $font
							;#FIXME if not defined $taller_font
							#or $taller_font->height > $font->height;
						$box_width += $w;
					}
					else {
						my $x0 = $self->{x};
						my $y0 = $self->{y} + 20; #FIXME $taller_font->ascent - $font->ascent;

						sub do_print
						{my ($font, $surf, $x, $y, $text) = @_;

							my $ts = SDL::TTF::render_text_solid($font, $text, 0xffffff); #FIXME color
							SDL::Video::blit_surface(
								$ts,
								undef,
								$surf,
								[ $x, $y, SDL::Surface::w($ts), SDL::Surface::w($ts) ]
							);
						}#

						for(my $x = $x0-1; $x <= $x0+1; $x+=2) {
							for(my $y = $y0-1; $y <= $y0+1; $y+=2) {
								do_print($font_border, $surf, $x, $y, $arg);
							}
						}

						do_print($font, $surf, $x0, $y0, $arg);
						$self->{x} += $w;
					}
				}
				default { die }
			}
		}

		if ($mode eq 'layout') {
			my $height = .5*$self->{border} + 20;#FIXME $taller_font->height;
			my $shade = SDLx::Surface->new(width => $box_width, height => $height);
			$shade->draw_rect(undef, $self->{black});
			#FIXME $shade->set_alpha(SDL::Video::SDL_SRCALPHA, 0x40);
			$shade->blit($surf, undef, [ $self->{x}-$self->{border}, $self->{y}, $box_width, $height ]);
		}
	}

	$self->{max_x} = max($self->{max_x}, $self->{x});
	$self->{y} += 20;#$taller_font->height;
	if ($self->{y}+20 > $surf->height) { #aki tb
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
