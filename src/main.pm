package main;
use import;
use picture;

#{# use

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use SDL::App;

use args qw/%args/;

#}#

sub display
{#
	my ($self) = @_;

	my $pic = $self->{pics}->{$self->{keys}->[$self->{cursor}]};

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
	$self->{app}->update;
	$self->{app}->sync;
}#

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

sub do ($)
{#
	my ($self, $event) = @_;
	return unless defined $event;

	given ($event) {
		when (/image_go_next/)     { $self->{cursor}++; }
		when (/image_go_prev/) { $self->{cursor}--; }
		default { die }
	}

	my $last = (scalar @{$self->{keys}}) - 1;
	$self->{cursor} = $last  if $self->{cursor} < 0;
	$self->{cursor} = 0      if $self->{cursor} > $last;

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

	use SDL::Event;
	my $event = new SDL::Event;
	SDL::Event->set_key_repeat (200, 30);
	$self->{cursor} = 0;
	$self->display;
	while(1)
	{# main loop

		my $oldcursor = $self->{cursor};

		while ($event->poll)
		{# handle events

			if ($event->type == SDL_QUIT()) {
				exit (0);
			}
			elsif ($event->type == SDL_KEYDOWN())
			{#
				given ($event->key_name) {
					when (/^q$/) { exit(0); }
					when (/^(space|down|right)$/)  { $self->do ('image_go_next'); }
					when (/^(backspace|up|left)$/) { $self->do ('image_go_prev'); }
					default { say "[$event->key_name]"; }
				}
			}#
			elsif ($event->type == SDL_MOUSEBUTTONDOWN())
			{#
				$self->do ({
						4 => 'image_go_next',
						5 => 'image_go_prev',
					}->{$event->button});
			}#

		}#

		if ($oldcursor != $self->{cursor}) {
			$oldcursor = $self->{cursor};
			$self->display;
		}

	}#

}#

1;
# vim600:fdm=marker:fmr={#,}#:
