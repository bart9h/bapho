package main;

use strict;
use warnings;
use 5.010;

sub display_pic ($$$$$;$)
{#
	my ($self, $pic, $w, $h, $x, $y, $is_selected) = @_;

	my $surf = $pic->get_surface ($w, $h);

	my $dest = SDL::Rect->new (
		-x => $x + ($w - $surf->width)/2,
		-y => $y + ($h - $surf->height)/2,
		-width => $surf->width,
		-height => $surf->height,
	);

	$surf->blit (0, $self->{app}, $dest);

	if ($is_selected)
	{#  draw cursor

		my $b = 2;
		$self->{app}->fill (
			SDL::Rect->new (-x => $_->[0], -y => $_->[1], -width => $_->[2], -height => $_->[3]),
			SDL::Color->new (-r => 0xff, -g => 0xff, -b => 0xff),
		)
		foreach (
			[ $x,       $y,       $w, $b      ],  # top
			[ $x,       $y+$h-$b, $w, $b      ],  # bottom
			[ $x,       $y+$b,    $b, $h-2*$b ],  # left
			[ $x+$w-$b, $y+$b,    $b, $h-2*$b ],  # right
		);
	}#
}#

sub print
{#
	my $self = shift;
	$self->{text}->print ($self->{app}, @_);
}#

sub display_info ($)
{#
	my $self = shift;

	my $key = $self->{keys}->[$self->{cursor}];
	my $pic = $self->{collection}->{pics}->{$key};

	$self->{text}->home;

	#FIXME
	my $s = $pic->{sel};
	$s =~ s{^.*/[^.]+\.(.*)$}{$1};

	$self->print (
		font => 0,
		text => $key,
		font => 1,
		text => ".$s",
	);

	my $str = join ' / ', $self->{cursor}+1, scalar @{$self->{keys}};
	$str .= '  '.int($pic->{zoom}*100).'%';
	$self->print (text => $str);
	$self->print (text => $pic->{surface}->width().'x'.$pic->{surface}->height())
		if $pic->{surface};

	$self->print (
		font => 1,
		text => 'tags:',
	);
	$self->print (text => $_)
		foreach map { ' '.$_ } sort keys %{$pic->{tags}};
}#

sub display_tags ($)
{#
	my $self = shift;

	my $key = $self->{keys}->[$self->{cursor}];
	my $pic = $self->{collection}->{pics}->{$key};

	$self->{text}->home;

	#FIXME
	my $s = $pic->{sel};
	$s =~ s{^.*/[^.]+\.(.*)$}{$1};

	$self->print (
		font => 0,
		text => "EDIT TAGS for $key:",
	);

	my $i = 0;
	foreach (@{$self->{tags}}) {
		my @s = split //, $i==$self->{tag_cursor}  ?  '[]' : '  ';  # cursor
		my $t = exists $self->{cursor_pic}->{tags}->{$_}  ?  '*' : ' ';  # tag
		$self->print (text => $s[0].$t.$_.$t.$s[1]);
		++$i;
	}
}#

sub display
{#
	my ($self) = @_;
	my ($W, $H) = ($self->{app}->width, $self->{app}->height);

	state $bg = SDL::Color->new (-r => 0, -g => 0, -b => 0);
	$self->{app}->fill (0, $bg);

	my $key = $self->{keys}->[$self->{page_first}];
	my $pic = $self->{collection}->{pics}->{$key};

	if ($self->{zoom} < -1)
	{# thumbnails

		my $d = (sort $W, $H)[0];  # smallest window dimention
		my $n = -$self->{zoom};    # number of pictures across that dimention
		($self->{cols}, $self->{rows}) = (int($W/($d/$n)), int($H/($d/$n)));
		my ($w, $h) = (int($W/$self->{cols}), int($H/$self->{rows}));  # thumbnail area

		my $i = $self->{page_first};
		THUMB: foreach my $y (0 .. $self->{rows}-1) {
			foreach my $x (0 .. $self->{cols}-1) {
				my $key = $self->{keys}->[$i];
				my $pic = $self->{collection}->{pics}->{$key};
				$self->display_pic ($pic, $w, $h, $x*$w, $y*$h, $i==$self->{cursor});
				++$i;
				last THUMB if $i >= scalar @{$self->{keys}};
			}
		}
	}#
	else {
		$self->{rows} = $self->{cols} = 1;
		$self->display_pic ($pic, $W, $H, 0, 0);
	}

	if ($self->{tag_mode}) {
		$self->display_tags;
	}
	elsif ($self->{display_info}) {
		$self->display_info;
	}

	$self->{app}->update;
	$self->{app}->sync;
	$self->{dirty} = 0;
}#

1;
# vim600:fdm=marker:fmr={#,}#:
