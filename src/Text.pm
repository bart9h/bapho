package Text;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use args qw/%args max/;
use SDL::TTFont;

#}#

sub new
{#{my}

	bless my $self = {
		border => 8,
		fonts => [],
		font => 0,
		print_error => 0,
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
			fill => SDL::TTFont->new(
				-name => $file,
				-size => $size,
				#-mode => SDL::TEXT_BLENDED, # XXX SDL_Perl 2.1.3: crash;
				-mode => SDL::TEXT_SHADED,   # XXX (default) only available with transparency,
											 # which is wrong because it DOES have anti-aliasing
											 # to the background color and feels wrong on other
											 # background, but here will feel so so on the shaded
											 # transparent background we will force later;
				#-mode => SDL::TEXT_SOLID,   # XXX transparent blit, without anti-aliasing
				-bg => $SDL::Color::black,
				-fg => $SDL::Color::white,
			),
			border => SDL::TTFont->new(
				-name => $file,
				-size => $size,
				-mode => SDL::TEXT_SOLID,
				-fg => $SDL::Color::black,
			),
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
							$w = $font->width($arg);
						};
						if ($@) {
							print $@;
							$self->{print_error} = 1;
						}
					}
					$w //= 12 * length $arg;

					if ($mode eq 'layout') {
						$taller_font = $font
							if not defined $taller_font
							or $taller_font->height > $font->height;
						$box_width += $w;
					}
					else {
						my $x0 = $self->{x};
						my $y0 = $self->{y} + $taller_font->ascent - $font->ascent;

						for(my $x = $x0-1; $x <= $x0+1; $x+=2) {
							for(my $y = $y0-1; $y <= $y0+1; $y+=2) {
								$font_border->print($surf, $x, $y, $arg);
							}
						}

						$font->print($surf, $x0, $y0, $arg);
						$self->{x} += $w;
				}
			}
			default { die }
			}
		}

		if ($mode eq 'layout') {
			my $height = .5*$self->{border} + $taller_font->height;
			my $shade = SDL::Surface->new(-width => $box_width, -height => $height);
			$shade->fill(0, $SDL::Color::black);
			$shade->set_alpha(SDL::SDL_SRCALPHA, 0x40);
			$shade->blit(0, $surf,
				SDL::Rect->new(-x => $self->{x}-$self->{border}, -y => $self->{y}, -width => $box_width, -height => $height),
			);
		}
	}

	$self->{max_x} = max($self->{max_x}, $self->{x});
	$self->{y} += $taller_font->height;
	if ($self->{y}+$taller_font->height > $surf->height) {
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
