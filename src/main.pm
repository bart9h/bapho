package main;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use SDL::App;

use args qw/%args/;
use collection;
use display;
use menu;
use picture;
use text;
use view;

#}#

sub rotate
{my ($array_ref) = @_;

	push @$array_ref, shift @$array_ref;
}#

sub get_root_geometry
{my ($self) = @_;

	state ($w, $h);

	unless ($w and $h) {

		`xdpyinfo` =~ /\b(\d{2,})x(\d{2,})\b/s
			or return (0, 0);
		($w, $h) = ($1, $2);

		for (2 .. 10)
		{#{my ugly hack: fix multi-monitor}
			$_ = 12 - $_;
			if ($w > $_*$h) {
				$w = int($w/$_);
				last;
			}
		}#

	}

	($w, $h);
}#

sub get_window_geometry
{my ($self) = @_;

	if (defined $args{geometry}) {
		$args{geometry} =~ /(\d+)x(\d+)/
		? ($1, $2)
		: (0, 0)
	}
	elsif ($args{fullscreen}) {
		get_root_geometry;
	}
	else {
		(0, 0);
	}
}#

sub fullscreen_toggle
{my ($self) = @_;

	$args{fullscreen} = not $args{fullscreen};

	my ($w, $h);
	if ($args{fullscreen}) {
		($w, $h) = $args{geometry} ? get_window_geometry : get_root_geometry;
	}
	else {
		if ($args{geometry}) {
			($w, $h) = get_window_geometry;
		}
		else {
			($w, $h) = get_root_geometry;
			$w /= 2;
			$h /= 2;
		}
	}

	# This two different orders for in and out of fullscreen
	# is to avoid changing screen resolutions.
	if ($args{fullscreen}) {
		$self->{app}->resize($w, $h);
		$self->{app}->fullscreen;
	}
	else {
		$self->{app}->fullscreen;
		$self->{app}->resize($w, $h);
	}
}#

sub load_state
{my ($self) = @_;

	args::load_state;

	my $id = $args{cursor_id};
	if (defined $id) {
		$_->seek_id($id)
			foreach @{$self->{views}};
	}
}#

sub close_view
{my ($self) = @_;

	my $cursor_id = $self->{views}->[0]->pic->{id};

	shift @{$self->{views}};

	@{$self->{views}} or $self->quit ($cursor_id);
}#

sub quit
{my ($self, $cursor_id) = @_;

	my $P = $self->{collection}->{pics};
	foreach (keys %{$P}) {
		$P->{$_}->save_tags;
	}

	#TODO: save all views
	args::save_state {
		cursor_id => $cursor_id // $self->{views}->[0]->pic->{id},
	};

	exit(0);
}#

sub enter_tag_mode
{my ($self) = @_;

	$self->{menu}->enter('tag_editor', [ sort keys %{$self->{collection}->{tags}} ]);
}#

sub enter_star_view
{my ($self) = @_;

	unshift @{$self->{views}}, view::new($self->{collection}, ['_star'], ['_hidden']);
}#

sub enter_hidden_view
{my ($self) = @_;

	unshift @{$self->{views}}, view::new($self->{collection}, ['_hidden'], []);
}#

sub do_menu
{my ($self, $command) = @_;

	$self->{dirty} = 1;
	return 0 unless $self->{menu}->{action};
	my $view = $self->{views}->[0];

	$self->{dirty} = $self->{menu}->do($command);
	my $activated = $self->{menu}->{activated};

	given ($self->{menu}->{action}) {
		when (/^tag_editor$/) {
			if (defined $activated) {
				$view->pic->toggle_tag($activated);
				$self->{last_tag} = $activated
					if $view->pic->{tags}->{$activated};
			}
			elsif (not $self->{dirty}) {
				$self->{dirty} = 1;
				given ($command) {
					when (/^(t|toggle info)$/) {
						$self->{menu}->leave;
						$view->pic->save_tags;
					}
					when (/^e$/ and not $args{fullscreen}) {
						$view->pic->save_tags;
						my $filename = $view->pic->get_tag_filename;
						system "\$EDITOR $filename";
						$view->pic->add($filename);
						$view->{collection}->update_tags;
						$self->enter_tag_mode;
						$self->display;
					}
					default {
						$self->{dirty} = 0;
					}
				}
			}
		}
	}

	return 1;
}#

sub do
{my ($self, $command) = @_;

	return unless defined $command;
	return if $self->do_menu($command);

	my ($app, $view) = ($self, $self->{views}->[0]);
	my %actions = (#{my

		edit_file => {
			keys => [ qw/control-d/ ],
			code => sub { $view->pic->develop },
		},
		toggle_fullscreen => {
			keys => [ qw/f f11/ ],
			code => sub { $app->fullscreen_toggle },
		},
		print_files => {
			keys => [ qw/p/ ],
			code => sub { say join "\n", keys %{$view->pic->{files}} },
		},
		toggle_star => {
			keys => [ qw/s/ ],
			code => sub { $view->pic->toggle_tag('_star') },
		},
		toggle_hidden => {
			keys => [ qw/shift-1/ ],
			code => sub { $view->pic->toggle_tag('_hidden') },
		},
		starred_view => {
			keys => [ qw/control-s/ ],
			code => sub { $app->enter_star_view },
		},
		hidden_view => {
			keys => [ qw/control-shift-h/ ],
			code => sub { $self->enter_hidden_view },
		},
		close_view => {
			keys => [ qw/control-w escape q/ ],
			code => sub { $self->close_view },
		},
		tag_edit => {
			keys => [ qw/t/ ],
			code => sub { $app->enter_tag_mode },
		},
		date_seek => {
			keys => [ qw/d m y shift-d shift-m shift-y/ ],
			code => sub { $view->seek_date($command) },
		},
		repeat_last_tag => {
			keys => [ qw/./ ],
			code => sub { $view->pic->set_tag($app->{last_tag}) },
		},

		previous_picture => {
			keys => [ qw/left h/ ],
			code => sub { $view->{cursor}-- },
		},
		next_picture => {
			keys => [ qw/right l/ ],
			code => sub { $view->{cursor}++ },
		},
		previous_line => {
			keys => [ qw/up k/ ],
			code => sub { $view->{cursor} -= $view->{cols} },
		},
		next_line => {
			keys => [ qw/down j/ ],
			code => sub { $view->{cursor} += $view->{cols} },
		},
		previous_page => {
			keys => [ qw/page_up backspace/ ],
			code => sub { $view->{cursor} -= $view->{rows}*$view->{cols} },
		},
		next_page => {
			keys => [ qw/page_down space/ ],
			code => sub { $view->{cursor} += $view->{rows}*$view->{cols} },
		},
		first_picture => {
			keys => [ qw/home g-g/ ],
			code => sub { $view->{cursor} = 0 },
		},
		last_picture => {
			keys => [ qw/end G/ ],
			code => sub { $view->{cursor} = scalar @{$view->{ids}} - 1 },
		},

		delete_picture => {
			keys => [ qw/delete/ ],
			code => sub { $view->delete_current },
		},
		info_toggle => {
			keys => [ qw/i/ ],
			code => sub { rotate $app->{info_modes} },
		},
		switch_views => {
			keys => [ qw/tab/ ],
			code => sub { rotate $app->{views}; $app->{views}->[0]->update },
		},
		zoom_in => {
			keys => [ qw/= [+]/ ],
			code => sub { $view->{zoom}++; $view->{zoom} =  1 if $view->{zoom} == -1; },
		},
		zoom_out => {
			keys => [ qw/- [-]/ ],
			code => sub { $view->{zoom}--; $view->{zoom} = -2 if $view->{zoom} ==  0; },
		},
		zoom_reset => {
			keys => [ qw// ],
			code => sub { $view->{zoom} = 1 },
		},
		quit => {
			keys => [ qw/q escape/ ],
			code => sub { $app->quit },
		},

	);#}#

	ACTION:
	foreach my $action (keys %actions) {
		foreach ($action, @{$actions{$action}->{keys}}) {
			if ($command eq $_) {
				$self->{dirty} = 1;
				&{$actions{$action}->{code}}($command);
				$view->adjust_page_and_cursor;
				last ACTION;
			}
		}
	}
}#

sub handle_event
{my ($self, $event) = @_;

	state $shift   = 0;
	state $control = 0;

	given ($event->type) {
		when ($_ == SDL_KEYDOWN()) {
			my $key = $event->key_name;
			$shift   = 1  if $key =~ m{^(left|right)\ shift$};
			$control = 1  if $key =~ m{^(left|right)\ ctrl$};
			$key =   'shift-'.$key  if $shift;
			$key = 'control-'.$key  if $control;

			if ($self->{key_hold}) {
				$key = "$self->{key_hold}-$key";
				$self->{key_hold} = '';
			}
			if ($key =~ /^[g]$/) {
				$self->{key_hold} = $key;
			}
			else {
				$key =~ s/\ /_/g;
				$self->do($key);
			}
		}
		when ($_ == SDL_KEYUP()) {
			$shift   = 0  if $event->key_name =~ m{^(left|right)\ shift$};
			$control = 0  if $event->key_name =~ m{^(left|right)\ ctrl$};
		}
		when ($_ == SDL_MOUSEBUTTONDOWN()) {
			$self->do(
				{
					3 => 'info_toggle',
					4 => 'page_down',
					5 => 'page_up',
				}->{$event->button} // 'button-'.$event->button
			);
		}
		when ($_ == SDL_VIDEORESIZE()) {
			$self->{app}->resize($event->resize_w, $event->resize_h);
			$self->{dirty} = 1;
		}
		when ($_ == SDL_QUIT()) {
			$self->quit;
		}
	}
}#

sub main
{my @args = @_;

	args::read_args(@args);

	# fix symlinked basedir
	if (-l $args{basedir}) {
		$args{basedir} = readlink $args{basedir};
	}

	if ($args{import}) {
		use import;
		exit(import::import_any($args{files}) ? 0 : 1);
	}
	else {
		if (exists $args{files}) {
			die 'only one startdir supported'  if scalar @{$args{files}} != 1;
			my $dir = $args{files}->[0];
			my $pwd = `pwd`;  chomp $pwd;
			$dir =~ m{^/}  or $dir = $pwd."/$dir";
			$args{startdir} = $dir;
		}
	}

	my ($w, $h) = get_window_geometry;
	bless my $self = {

		# data
		collection => collection::new,

		views      => [],
		menu       => menu::new,
		key_hold   => '',
		last_tag   => '',
		dirty      => 1,

		# rendering state
		info_modes => [ qw/none title tags exif/ ],
		text => text::new(
			'Bitstream Vera Sans Mono:20',
			':18',
		),

		# SDL window
		app => SDL::App->new(
			-title => 'bapho',
			-width => $w,
			-height => $h,
			($args{fullscreen} ? '-fullscreen':'-resizeable') => 1,
		),

	};

	push @{$self->{views}}, view::new($self->{collection}, [], ['_hidden']);

	$self->load_state;

	SDL::ShowCursor(0);

	# prepare to enter main loop
	use SDL::Event;
	use SDL::Constants;
	my $event = new SDL::Event;
	SDL::Event->set_key_repeat(200, 30);

	while(1) {

		$self->display  if $self->{dirty};

		$event->wait;
		do {
			$self->handle_event($event);
		} while ($event->poll);
	}

}#

1;
# vim600:fdm=marker:fmr={my,}#:
