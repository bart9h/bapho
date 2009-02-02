#{# use

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use SDL::App;
use SDL::TTFont;

use args qw/%args/;
use picture;
use import;

#}#

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

sub get_font ($$)
{#
	my ($name, $size) = @_;

	$_ = `which fc-match`;
	chomp;
	-x or die 'fc-match not found.  fontconfig is required.';

	$_ = `fc-match -v '$name' | grep file: | cut -d \\\" -f 2`;
	chomp;
	-f or die "$_ not found";

	SDL::TTFont->new (
		-name => $_,
		-size => $size,
		-bg => $SDL::Color::black,
		-fg => $SDL::Color::white,
	);

}#


package main;

sub display
{#
	my ($self) = @_;

	my $key = $self->{keys}->[$self->{cursor}];
	my $pic = $self->{pics}->{$key};

	state $bg = SDL::Color->new (-r => 0, -g => 0, -b => 0);
	$self->{app}->fill (0, $bg);

	my $surf = $pic->get_surface;
	my $dest = SDL::Rect->new (
		-x => ($self->{app}->width-$surf->width)/2,
		-y => ($self->{app}->height-$surf->height)/2,
		-width => $surf->width,
		-height => $surf->height,
	);

	$surf->blit (0, $self->{app}, $dest);

	if ($self->{display_info}) {
		my ($x, $y) = (8, 8);

		$self->{font1}->print ($self->{app}, $x, $y, $key);
		$y += $self->{font1}->height;

		my $str = join ' / ', $self->{cursor}+1, scalar @{$self->{keys}};
		$self->{font2}->print ($self->{app}, $x, $y, $str);
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
		when (/display_info/)   { $self->{display_info} = !$self->{display_info}; }
		default { die }
	}

	my $last = (scalar @{$self->{keys}}) - 1;
	$self->{cursor} = $last  if $self->{cursor} < 0;
	$self->{cursor} = 0      if $self->{cursor} > $last;

}#

sub handle_event ($)
{#
	my ($self, $event) = @_;

	$self->{dirty} = 1;

	given ($event->type) {
		when ($_ == SDL_KEYDOWN()) {
			given ($event->key_name) {
				when (/^(q|escape)$/) { exit(0); }
				when (/^(space|down|right)$/)  { $self->do ('image_go_next'); }
				when (/^(backspace|up|left)$/) { $self->do ('image_go_prev'); }
				when (/^(i)$/)                 { $self->do ('display_info');  }
				default {
					$self->{dirty} = 0;
					say 'unhandled key ['.$event->key_name.']';
				}
			}
		}
		when ($_ == SDL_MOUSEBUTTONDOWN()) {
			$self->do ({
					4 => 'image_go_next',
					5 => 'image_go_prev',
				}->{$event->button});
		}
		when ($_ == SDL_QUIT()) {
			exit (0);
		}
		default {
			$self->{dirty} = 0;
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

	my ($w, $h) = get_window_geometry;
	$self->{app} = SDL::App->new (
		-title => 'bapho',
		-width => $w,
		-height => $h,
		($args{fullscreen} ? '-fullscreen':'-resizeable') => 1,
	);

	$self->{display_info} = 0;
	$self->{font1} = get_font ('Bitstream Vera Sans Mono', 18);
	$self->{font2} = get_font ('Bitstream Vera Sans Mono', 14);

	use SDL::Event;
	use SDL::Constants;
	my $event = new SDL::Event;
	SDL::Event->set_key_repeat (200, 30);
	$self->{cursor} = 0;
	$self->display;

	while(1) {
		$self->handle_event ($event)  while ($event->poll);
		$self->display  if $self->{dirty};
	}

}#

1;
# vim600:fdm=marker:fmr={#,}#:
