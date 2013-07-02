package main;  #FIXME

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;
use SDL;
use SDL::Color;

use args qw/%args/;
use Tags;

#}#

sub display
{my ($self) = @_;

	sub render_all
	{my ($self, @args) = @_;

		my $view = $self->{views}->[0];

		if ($view->{zoom} < -1) {
			$self->render_thumbnails;
		}
		else {
			$view->{rows} = $view->{cols} = 1;
			$self->render_pic(
				$view->pic,
				$self->{app}->w, $self->{app}->h,
				0, 0);
		}

		if ($self->{menu}->{action} eq 'tag_editor') {
			$self->render_tag_editor;
		}
		elsif ($args{exif_toggle}) {
			$self->render_title;
			$self->render_exif;
		}
		elsif ($args{info_toggle}) {
			$self->render_title;
			$self->render_tags;
		}
	}#

	sub render_pic
	{our ($self, $pic, $w, $h, $x, $y, $is_cursor) = @_; #{my}

		my $view = $self->{views}->[0];
		my $surf = $self->{factory}->get($pic->{sel}, $w, $h);
		$view->{cur_surf} = $surf  if $pic eq $view->pic;

		SDL::Video::blit_surface($surf->{surf}, undef, $self->{app},
			SDL::Rect->new(
				$x + ($w - $surf->{surf}->w)/2,
				$y + ($h - $surf->{surf}->h)/2,
				$surf->{surf}->w,
				$surf->{surf}->h,
			)
		);

		sub render_cursor
		{#{my}

			my $b = 2;
			SDL::Video::fill_rect($self->{app},
				SDL::Rect->new($_->[0], $_->[1], $_->[2], $_->[3]),
				$self->{white}
			)
			foreach (
				[ $x,       $y,       $w, $b      ],  # top
				[ $x,       $y+$h-$b, $w, $b      ],  # bottom
				[ $x,       $y+$b,    $b, $h-2*$b ],  # left
				[ $x+$w-$b, $y+$b,    $b, $h-2*$b ],  # right
			);
		}#

		sub render_selection
		{#{my}

			my $b = 3;
			my $r = SDL::Rect->new($x+$w-1-6*$b, $y+$b, 5*$b, 5*$b);
			SDL::Video::fill_rect($self->{app}, $r, $self->{black});
			$r->x($r->x+1); $r->y($r->y+1); $r->w($r->w-2); $r->h($r->h-2);
			SDL::Video::fill_rect($self->{app}, $r, $self->{white});
			$r->x($x+$w-1-5*$b); $r->y($y+3*$b); $r->w(3*$b); $r->h($b);
			SDL::Video::fill_rect($self->{app}, $r, $self->{black});
			$r->x($x+$w-1-4*$b); $r->y($y+2*$b); $r->w($b); $r->h(3*$b);
			SDL::Video::fill_rect($self->{app}, $r, $self->{black});
		}#

		render_cursor     if $is_cursor;
		render_selection  if $view->is_selected($pic);
	}#

	sub render_thumbnails
	{my ($self) = @_;

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
				$self->render_pic($pic,
					$w, $h, $x*$w, $y*$h,
					$pic->{id} eq $view->{picitr}->{pic}->{id});
			}
		}
	}#

	sub render_title
	{my ($self) = @_;

		$self->{text}->home;
		my $view = $self->{views}->[0];

		$view->pic->{sel} =~ m{^.*/(?<name>[^./]+)\.(?<ext>.*)$};

		my $str = ''; #join '/', $view->{cursor}+1, scalar @{$view->{ids}};
		my $s = $view->{cur_surf};
		if ($s and $s->{width} and $s->{height}) {
			my $zoom = $s->{surf}->w/$s->{width};
			$str .= '  '.$s->{width}.'x'.$s->{height};
			$str .= '  '.int($zoom*100).'%';
		}

		my $v = scalar @{$self->{views}};
		my $n = $view->pic->{tags}->get_nstars;
		$self->print(
			font=>0, text=>$+{name},
			font=>1, text=>".$+{ext}  $str",
			$n ? (font=>0, text=>'  ('.'*'x$n.')') : (),
			$view->pic->{tags}->get('_hidden') ? (font=>0, text=>'  (!)') : (), #TODO:loopify
			$v>1 ? (font=>0, text=>"  [$v views]") : (),
		);
	}#

	sub render_tags
	{my ($self) = @_;

		$self->print(font=>1, text=>'tags:');
		$self->{text}->set_column;
		$self->print(text=>$_)
			foreach map { ' '.$_ } $self->{views}->[0]->pic->{tags}->get;
	}#

	sub render_exif
	{my ($self) = @_;

		$self->print(font=>1, text=>'exif:');
		if (my $exif = $self->{views}->[0]->{cur_surf}->{exif}) {
			$self->{text}->set_column;
			$self->print(text => $_)
				foreach map { "  $_: $exif->{$_}" }
				grep { defined $exif->{$_} and not $exif->{$_} =~ /^Unknown \(0\)$/ }
				@{$args{exif_tags}};
		}
	}#

	sub render_tag_editor
	{my ($self) = @_;

		my $view = $self->{views}->[0];

		$view->pic->{sel} =~ m{^.*/(?<name>[^./]+)\.(?<ext>.*)$};

		$self->{text}->home;
		$self->print(
			font => 0,
			text => 'EDIT TAGS for '.$+{name}.':',
		);
		$self->{text}->set_column;

		my $i = 0;
		foreach (@{$self->{menu}->{items}}) {
			my @C = split //, $i==$self->{menu}->{cursor}? '[]':'  ';#cursor
			my $T = $view->pic->{tags}->get($_)? '*':' ';#tag
			$self->print(text => $C[0].$T.$_.$T.$C[1]);
			++$i;
		}
	}#

	sub print
	{my ($self, @args) = @_;

		$self->{text}->print($self->{app}, @args);
	}#

	SDL::Video::fill_rect($self->{app},
		SDL::Rect->new(0, 0, $self->{app}->w, $self->{app}->h), #FIXME: SDL::NULL should work
		$self->{black}
	);

	$self->render_all;
	$self->{app}->update;
	$self->{app}->sync;
	$self->{dirty} = 0;
}#


1;
# vim600:fdm=marker:fmr={my,}#:
