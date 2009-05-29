package text;
use strict;
use warnings;
use 5.010;

use SDL::TTFont;

sub home
{#
	my $self = shift;
	$self->{x} = $self->{y} = $self->{border};
}#

sub new (@)
{#
	bless my $self = {
		border => 8,
		fonts => [],
		font => 0,
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

		my $f;
		push @{$self->{fonts}}, $f=SDL::TTFont->new (
			-name => $file,
			-size => $size,
			-bg => $SDL::Color::black,
			-fg => $SDL::Color::white,
		);
	}

	$self;
}#

sub print ($$$)
{#
	my $self = shift;
	my $surf = shift;

	my $taller_font;
	my $width = 2*$self->{border};;
	foreach my $mode ('layout', 'draw') {
		for (my $i = 0;  $i < $#_;  $i += 2) {
			my ($cmd, $arg) = ($_[$i], $_[$i+1]);
			given ($cmd) {
				when (/font/) {
					$self->{font} = $arg;
				}
				when (/text/) {
					my $font = $self->{fonts}->[$self->{font}]  or die;

					if ($mode eq 'layout') {
						$taller_font = $font
							if not defined $taller_font
							or $taller_font->height > $font->height;
						$width += $font->width ($arg);
					}
					else {
						$font->print ($surf,
							$self->{x},
							$self->{y}
								+$taller_font->height  +$taller_font->descent
								-       $font->height  -       $font->descent,
							$arg);
						$self->{x} += $font->width ($arg);
					}
				}
				default { die }
			}
		}

		if ($mode eq 'layout') {
			my $height = .5*$self->{border} + $taller_font->height;
			$surf->fill (
				SDL::Rect->new (-x => 0, -y => $self->{y}, -width => $width, -height => $height),
				SDL::Color->new (-r => 0, -g => 0, -b => 0),
			);
		}
	}

	$self->{y} += $taller_font->height;
	$self->{x} = $self->{border};

}#

{# check system sanity
	$_ = `which fc-match`;
	chomp;
	-x or die 'fc-match not found.  fontconfig is required.';
}#
1;
# vim600:fdm=marker:fmr={#,}#:
