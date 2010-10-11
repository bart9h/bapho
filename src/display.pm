package main;  #FIXME

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use args qw/%args/;
use Tags;

#}#

sub display
{my ($self) = @_;

	state $bg = SDL::Color->new(-r => 0, -g => 0, -b => 0);
	$self->{app}->fill(0, $bg);

	my $view = $self->{views}->[0];

	if ($view->{zoom} < -1) {
		$self->pvt__display_thumbnails;
	}
	else {
		$view->{rows} = $view->{cols} = 1;
		$self->pvt__display_pic(
			$view->pic,
			$self->{app}->width, $self->{app}->height,
			0, 0);
	}

	if ($self->{menu}->{action} eq 'tag_editor') {
		$self->pvt__display_tag_editor;
	}
	elsif ($self->{info_modes}->[0] ne 'none') {
		$self->pvt__display_info;
	}

	$self->{app}->update;
	$self->{app}->sync;
	$self->{dirty} = 0;
}#


sub pvt__display_pic
{my ($self, $pic, $w, $h, $x, $y, $is_selected) = @_;
	caller eq __PACKAGE__ or die;

	my $view = $self->{views}->[0];
	my $surf = $self->{factory}->get($pic->{sel}, $w, $h);
	$view->{cur_surf} = $surf  if $pic eq $view->pic;

	my $dest = SDL::Rect->new(
		-x => $x + ($w - $surf->{surf}->width)/2,
		-y => $y + ($h - $surf->{surf}->height)/2,
		-width => $surf->{surf}->width,
		-height => $surf->{surf}->height,
	);

	$surf->{surf}->blit(0, $self->{app}, $dest);

	sub display_cursor
	{my ($self, $x, $y, $w, $h) = @_;

		my $b = 2;
		$self->{app}->fill(
			SDL::Rect->new(-x => $_->[0], -y => $_->[1], -width => $_->[2], -height => $_->[3]),
			SDL::Color->new(-r => 0xff, -g => 0xff, -b => 0xff),
		)
		foreach (
			[ $x,       $y,       $w, $b      ],  # top
			[ $x,       $y+$h-$b, $w, $b      ],  # bottom
			[ $x,       $y+$b,    $b, $h-2*$b ],  # left
			[ $x+$w-$b, $y+$b,    $b, $h-2*$b ],  # right
		);
	}#

	$self->display_cursor($x,$y,$w,$h)  if $is_selected;
}#

sub pvt__display_thumbnails
{my ($self) = @_;
	caller eq __PACKAGE__ or die;

	my ($W, $H) = ($self->{app}->width, $self->{app}->height);
	my $view = $self->{views}->[0];

	my $d = (sort $W, $H)[0];  # smallest window dimention
	my $n = -$view->{zoom};  # number of pictures across that dimention
	($view->{cols}, $view->{rows}) = (int($W/($d/$n)), int($H/($d/$n)));
	my ($w, $h) = (int($W/$view->{cols}), int($H/$view->{rows}));  # thumbnail area

	my @pics = $view->page_pics;
	THUMB: foreach my $y (0 .. $view->{rows}-1) {
		foreach my $x (0 .. $view->{cols}-1) {
			my $pic = shift @pics or last THUMB;
			$self->pvt__display_pic($pic,
				$w, $h, $x*$w, $y*$h,
				$pic->{id} eq $view->{picitr}->{pic}->{id});
		}
	}
}#

sub pvt__print
{my ($self, @args) = @_;
	caller eq __PACKAGE__ or die;

	$self->{text}->print($self->{app}, @args);
}#

sub pvt__display_info
{my ($self) = @_;
	caller eq __PACKAGE__ or die;

	$self->{text}->home;
	my $view = $self->{views}->[0];

	$view->pic->{sel} =~ m{^.*/(?<name>[^./]+)\.(?<ext>.*)$};

	my $str = ''; #join '/', $view->{cursor}+1, scalar @{$view->{ids}};
	my $s = $view->{cur_surf};
	if ($s and $s->{width} and $s->{height}) {
		my $zoom = $s->{surf}->width/$s->{width};
		$str .= '  '.$s->{width}.'x'.$s->{height};
		$str .= '  '.int($zoom*100).'%';
	}

	my $v = scalar @{$self->{views}};
	$self->pvt__print(
		font=>0, text=>$+{name},
		font=>1, text=>".$+{ext}  $str",
		$view->pic->{tags}->get('_star')   ? (font=>0, text=>'  (*)') : (),
		$view->pic->{tags}->get('_hidden') ? (font=>0, text=>'  (!)') : (), #TODO:loopify
		$v>1 ? (font=>0, text=>"  [$v views]") : (),
	);

	given ($self->{info_modes}->[0]) {
		when (/tags/) {
			$self->pvt__print(font=>1, text=>'tags:');
			$self->pvt__print(text=>$_)
				foreach map { ' '.$_ } $view->pic->{tags}->get;
		}
		when (/exif/) {
			$self->pvt__print(font=>1, text=>'exif:');
			if (my $exif = $view->{cur_surf}->{exif}) {
				$self->pvt__print(text => $_)
					foreach map {
						"  $_: $exif->{$_}"
					} grep {
						defined $exif->{$_} and not $exif->{$_} =~ /^Unknown \(0\)$/
					} @{$args{exif_tags}};
			}
		}
	}
}#

sub pvt__display_tag_editor
{my ($self) = @_;
	caller eq __PACKAGE__ or die;

	$self->{text}->home;
	my $view = $self->{views}->[0];

	$self->pvt__print(
		font => 0,
		text => 'EDIT TAGS for '.$view->pic->{id}.':',
	);

	my $i = 0;
	foreach (@{$self->{menu}->{items}}) {
		my @C = split //, $i==$self->{menu}->{cursor}  ?  '[]' : '  ';  # cursor
		my $T = $view->pic->{tags}->get($_)  ?  '*' : ' ';  # tag
		$self->pvt__print(text => $C[0].$T.$_.$T.$C[1]);
		++$i;
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
