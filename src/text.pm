package text;
use strict;
use warnings;
use 5.010;

use SDL::TTFont;

sub reset
{#
	my $self = shift;
	$self->{x} = $self->{y} = $self->{border};
}#

sub new (@)
{#
	bless my $self = {
		border => 8,
		fonts => [],
	};

	$self->reset;

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

		push @{$self->{fonts}}, SDL::TTFont->new (
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
	my ($self, $surf, $font_idx, $text) = @_;

	my $font = $self->{fonts}->[$font_idx]  or die;

	$font->print ($surf, $self->{x}, $self->{y}, $text);
	$self->{y} += $font->height;

}#

{# check system sanity
	$_ = `which fc-match`;
	chomp;
	-x or die 'fc-match not found.  fontconfig is required.';
}#
1;
# vim600:fdm=marker:fmr={#,}#:
