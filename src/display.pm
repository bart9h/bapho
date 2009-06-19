package main;  #FIXME

use strict;
use warnings;
use 5.010;

sub display
{my ($self) = @_;

	state $bg = SDL::Color->new (-r => 0, -g => 0, -b => 0);
	$self->{app}->fill (0, $bg);

	if ($self->{zoom} < -1) {

		$self->pvt__display_thumbnails;
	}
	else {
		$self->{rows} = $self->{cols} = 1;
		$self->pvt__display_pic (
			$self->{cursor},
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
{my ($self, $pic_idx, $w, $h, $x, $y, $is_selected) = @_;
	caller eq __PACKAGE__ or die;

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

	sub display_cursor
	{my ($self, $x, $y, $w, $h) = @_;

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

	$self->display_cursor($x,$y,$w,$h)  if $is_selected;
}#

sub pvt__display_thumbnails
{my ($self) = @_;
	caller eq __PACKAGE__ or die;

	my ($W, $H) = ($self->{app}->width, $self->{app}->height);

	my $d = (sort $W, $H)[0];  # smallest window dimention
	my $n = -$self->{zoom};    # number of pictures across that dimention
	($self->{cols}, $self->{rows}) = (int($W/($d/$n)), int($H/($d/$n)));
	my ($w, $h) = (int($W/$self->{cols}), int($H/$self->{rows}));  # thumbnail area

	my $i = $self->{page_first};
	THUMB: foreach my $y (0 .. $self->{rows}-1) {
		foreach my $x (0 .. $self->{cols}-1) {
			$self->pvt__display_pic ($i,
				$w, $h, $x*$w, $y*$h,
				$i==$self->{cursor});
			++$i;
			last THUMB if $i >= scalar @{$self->{ids}};
		}
	}
}#

sub pvt__print
{my ($self, @args) = @_;
	caller eq __PACKAGE__ or die;

	$self->{text}->print ($self->{app}, @args);
}#

sub pvt__display_info
{my ($self) = @_;
	caller eq __PACKAGE__ or die;

	$self->{text}->home;

	#FIXME
	my $s = $self->pic->{sel};
	$s =~ s{^.*/[^.]+\.(.*)$}{$1};

	$self->pvt__print (
		font=>0, text=>$self->pic->{id},
		font=>1, text=>".$s",
		$self->pic->{tags}->{_star} ? (font=>0, text=>'  (*)') : (),
	);

	my $str = join ' / ', $self->{cursor}+1, scalar @{$self->{ids}};
	$str .= '  '.int($self->{cur_surf}->{zoom}*100).'%';
	$self->pvt__print (font=>1, text=>$str);

	if ($self->{cur_surf}) {
		my $s = $self->{cur_surf}->{surf};
		$self->pvt__print (text=>$s->width().'x'.$s->height());
	}

	if ($self->{info_modes}->[0] eq 'tags') {
		$self->pvt__print (
			font => 1,
			text => 'tags:',
		);
		$self->pvt__print (text => $_)
			foreach map { ' '.$_ } $self->pic->get_tags;
	}
}#

sub pvt__display_tag_editor
{my ($self) = @_;
	caller eq __PACKAGE__ or die;

	$self->{text}->home;

	$self->pvt__print (
		font => 0,
		text => 'EDIT TAGS for '.$self->pic->{id}.':',
	);

	my $i = 0;
	foreach (sort keys %{$self->{collection}->{tags}}) {
		my @s = split //, $i==$self->{menu}->{cursor}  ?  '[]' : '  ';  # cursor
		my $t = exists $self->pic->{tags}->{$_}  ?  '*' : ' ';  # tag
		$self->pvt__print (text => $s[0].$t.$_.$t.$s[1]);
		++$i;
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
