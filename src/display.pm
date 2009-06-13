package main;

use strict;
use warnings;
use 5.010;

sub display_pic ($$$$$;$)
{#
	my ($self, $pic_idx, $w, $h, $x, $y, $is_selected) = @_;

	my $id = $self->{ids}->[$pic_idx];
	my $surf = $self->{collection}->get_surface ($id, $w, $h);
	$self->{cur_surf} = $surf  if $pic_idx == $self->{cursor};

	my $dest = SDL::Rect->new (
		-x => $x + ($w - $surf->{surf}->width)/2,
		-y => $y + ($h - $surf->{surf}->height)/2,
		-width => $surf->{surf}->width,
		-height => $surf->{surf}->height,
	);

	$surf->{surf}->blit (0, $self->{app}, $dest);

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

	$self->{text}->home;

	#FIXME
	my $s = $self->pic->{sel};
	$s =~ s{^.*/[^.]+\.(.*)$}{$1};

	$self->print (
		font=>0, text=>$self->pic->{id},
		font=>1, text=>".$s",
		$self->pic->{tags}->{_star} ? (font=>0, text=>'  (*)') : (),
	);

	my $str = join ' / ', $self->{cursor}+1, scalar @{$self->{ids}};
	$str .= '  '.int($self->{cur_surf}->{zoom}*100).'%';
	$self->print (font=>1, text=>$str);

	if ($self->{cur_surf}) {
		my $s = $self->{cur_surf}->{surf};
		$self->print (text=>$s->width().'x'.$s->height());
	}

	$self->print (
		font => 1,
		text => 'tags:',
	);
	$self->print (text => $_)
		foreach map { ' '.$_ } $self->pic->get_tags;
}#

sub display_tag_editor ($)
{#
	my $self = shift;

	$self->{text}->home;

	$self->print (
		font => 0,
		text => 'EDIT TAGS for '.$self->pic->{id}.':',
	);

	my $i = 0;
	foreach (sort keys %{$self->{collection}->{tags}}) {
		my @s = split //, $i==$self->{menu}->{cursor}  ?  '[]' : '  ';  # cursor
		my $t = exists $self->pic->{tags}->{$_}  ?  '*' : ' ';  # tag
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

	if ($self->{zoom} < -1)
	{# thumbnails

		my $d = (sort $W, $H)[0];  # smallest window dimention
		my $n = -$self->{zoom};    # number of pictures across that dimention
		($self->{cols}, $self->{rows}) = (int($W/($d/$n)), int($H/($d/$n)));
		my ($w, $h) = (int($W/$self->{cols}), int($H/$self->{rows}));  # thumbnail area

		my $i = $self->{page_first};
		THUMB: foreach my $y (0 .. $self->{rows}-1) {
			foreach my $x (0 .. $self->{cols}-1) {
				$self->display_pic ($i, $w, $h, $x*$w, $y*$h, $i==$self->{cursor});
				++$i;
				last THUMB if $i >= scalar @{$self->{ids}};
			}
		}
	}#
	else {
		$self->{rows} = $self->{cols} = 1;
		$self->display_pic ($self->{cursor}, $W, $H, 0, 0);
	}

	if ($self->{menu}->{action} eq 'tag_editor') {
		$self->display_tag_editor;
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
