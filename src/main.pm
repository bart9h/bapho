use strict;
use warnings;
use 5.010;

use args qw/%args/;
use picture;
use text;

use SDL::App;

sub load_files
{#
	my %pics = ();

	die if $args{dir_fmt} =~ m{\.};

	use File::Find;
	find (
		{
			no_chdir => 1,
			wanted => sub
			{
				return if -d;
				my $pic = picture::new ($_);
				$pics{$pic->{key}} = $pic  if $pic;
			},
		},
		$args{basedir}.'/'
	);

	die 'no pictures found'  unless scalar keys %pics;
	return \%pics;
}#

sub get_window_geometry
{#
	my ($w, $h) = (0, 0);

	if (defined $args{geometry}) {
		($w, $h) = $args{geometry} =~ /(\d+)x(\d+)/ ? ($1, $2) : (0, 0)
	}

	if ($args{fullscreen}) {
		if ($w == 0) {
			($w, $h) = `xdpyinfo` =~ /\b(\d{2,})x(\d{2,})\b/s ? ($1, $2) : (0, 0);
			for (2 .. 10)
			{#  fix multi-monitor
				$_ = 12 - $_;
				if ($w > $_*$h) {
					$w = int ($w/$_);
					last;
				}
			}#
		}
	}
	else {
	}

	($w, $h);
}#


package main;

sub display_pic ($$$$$)
{#
	my ($self, $pic, $w, $h, $x, $y) = @_;

	my $surf = $pic->get_surface ($w, $h);

	my $dest = SDL::Rect->new (
		-x => $x + ($w - $surf->width)/2,
		-y => $y + ($h - $surf->height)/2,
		-width => $surf->width,
		-height => $surf->height,
	);

	$surf->blit (0, $self->{app}, $dest);
}#

sub display
{#
	my ($self) = @_;
	my ($W, $H) = ($self->{app}->width, $self->{app}->height);

	state $bg = SDL::Color->new (-r => 0, -g => 0, -b => 0);
	$self->{app}->fill (0, $bg);

	my $key = $self->{keys}->[$self->{cursor}];
	my $pic = $self->{pics}->{$key};

	if ($self->{zoom} < -1)
	{# thumbnails

		my $d = (sort $W, $H)[0];  # smallest window dimention
		my $n = -$self->{zoom};    # number of pictures across that dimention
		my ($nx, $ny) = (int($W/($d/$n)), int($H/($d/$n)));  # grid size
		my ($w,  $h)  = (int($W/$nx),     int($H/$ny));      # thumbnail size

		my $i = $self->{cursor};
		THUMB: foreach my $y (0 .. $ny-1) {
			foreach my $x (0 .. $nx-1) {
				my $key = $self->{keys}->[$i++];
				my $pic = $self->{pics}->{$key};
				$self->display_pic ($pic, $w, $h, $x*$w, $y*$h);
				last THUMB if $i >= scalar @{$self->{keys}};
			}
		}
	}#
	else {
		$self->display_pic ($pic, $W, $H, 0, 0);
	}

	if ($self->{display_info}) {

		$self->{text}->home;

		$self->{text}->print ($self->{app},
			font => 0,
			text => $key,
			font => 1,
			text => ".$pic->{ext}",
		);

		my $str = join ' / ', $self->{cursor}+1, scalar @{$self->{keys}};
		$str .= '  '.int($pic->{zoom}*100).'%';
		$self->{text}->print ($self->{app}, text => $str);
	}

	$self->{app}->update;
	$self->{app}->sync;
	$self->{dirty} = 0;
}#

sub do ($)
{#
	my ($self, $event) = @_;
	return unless defined $event;

	given ($event) {
		when (/image_go_next/)  { $self->{cursor}++; }
		when (/image_go_prev/)  { $self->{cursor}--; }
		when (/toggle_info/)    { $self->{display_info} = !$self->{display_info}; }
		when (/zoom_in/)        { $self->{zoom}++; $self->{zoom} =  0 if $self->{zoom} == -1; }
		when (/zoom_out/)       { $self->{zoom}--; $self->{zoom} = -2 if $self->{zoom} == -1; }
		when (/zoom_reset/)     { $self->{zoom} = 1; }
		default { die }
	}

	my $last = (scalar @{$self->{keys}}) - 1;
	$self->{cursor} = $last  if $self->{cursor} < 0;
	$self->{cursor} = 0      if $self->{cursor} > $last;

	1;
}#

sub handle_event ($)
{#
	my ($self, $event) = @_;

	given ($event->type) {
		when ($_ == SDL_KEYDOWN()) {
			$self->{dirty} = 1;
			given ($event->key_name) {
				when (/^(q|escape)$/) { exit(0); }
				when (/^(space|down|right)$/)  { $self->do ('image_go_next'); }
				when (/^(backspace|up|left)$/) { $self->do ('image_go_prev'); }
				when (/^(i)$/)                 { $self->do ('toggle_info'); }
				when (/^(-)$/)                 { $self->do ('zoom_out'); }
				when (/^(=)$/)                 { $self->do ('zoom_in'); }
				default {
					$self->{dirty} = 0;
					say 'unhandled key ['.$event->key_name.']';
				}
			}
		}
		when ($_ == SDL_MOUSEBUTTONDOWN()) {
			$self->{dirty} = $self->do (
				{
					3 => 'toggle_info',
					4 => 'image_go_next',
					5 => 'image_go_prev',
				}->{$event->button}
			);
		}
		when ($_ == SDL_QUIT()) {
			exit (0);
		}
	}
}#

sub main (@)
{#
	if (@_) {
		import::import_files (@_);
		return;
	}

	bless my $self = {};

	$self->{pics} = load_files;
	$self->{keys} = [ sort keys %{$self->{pics}} ];
	$self->{zoom} = 1;

	my ($w, $h) = get_window_geometry;
	$self->{app} = SDL::App->new (
		-title => 'bapho',
		-width => $w,
		-height => $h,
		($args{fullscreen} ? '-fullscreen':'-resizeable') => 1,
	);

	$self->{display_info} = 0;
	$self->{text} = text::new (
		'Bitstream Vera Sans Mono:18',
		':14',
	);

	use SDL::Event;
	use SDL::Constants;
	my $event = new SDL::Event;
	SDL::Event->set_key_repeat (200, 30);
	$self->{cursor} = 0;
	$self->display;

	while(1) {
		$event->wait;
		do {
			$self->handle_event ($event);
		} while ($event->poll);

		$self->display  if $self->{dirty};
	}

}#

1;
# vim600:fdm=marker:fmr={#,}#:
