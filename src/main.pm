package main;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use SDL::App;

use args qw/%args dbg/;
use Array;
use display;
use Factory;
use Menu;
use Picture;
use Text;
use View;

#}#

sub pic { $_[0]->{views}->[0]->pic }

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

	if (defined $args{cursor_file} and not defined $args{startdir}) {
		$_->seek_to_file($args{cursor_file}, $self->{jaildir})
			foreach @{$self->{views}};
	}
}#

sub save_state
{my ($self) = @_;

	#TODO: save all views
	args::save_state {
		cursor_file => $self->{cursor_file} // $self->pic->{sel},
		info_toggle => $args{info_toggle},
		exif_toggle => $args{exif_toggle},
	}
}#

sub close_view
{my ($self) = @_;

	my $curr_cursor_file = $self->pic->{sel};

	shift @{$self->{views}};

	unless (@{$self->{views}}) {
		# the last view was closed
		$self->{cursor_file} = $curr_cursor_file;
		$self->quit;
	}
}#

sub quit
{my ($self) = @_;

	$self->save_state  if $args{jaildir} eq $args{basedir};
	exit(0);
}#

sub enter_tag_mode
{my ($self) = @_;

	$self->{menu}->enter('tag_editor', [ sort(Tags::all()) ]);
}#

sub enter_star_view
{my ($self) = @_;

	unshift @{$self->{views}}, View::new(
		$self->{views}->[0]->{picitr},
		['_star'], ['_hidden']);
}#

sub enter_hidden_view
{my ($self) = @_;

	unshift @{$self->{views}}, View::new($self->pic, ['_hidden'], []);
}#

sub do_menu
{my ($self, $command) = @_;

	return 0 unless $self->{menu}->{action};

	$self->{dirty} = $self->{menu}->do($command);
	my $activated = $self->{menu}->{activated};

	given ($self->{menu}->{action}) {
		when (/^tag_editor$/) {
			if (defined $activated) {
				$self->pic->{tags}->toggle($activated);
				$self->{last_tag} = $activated
					if $self->pic->{tags}->get($activated);
			}
			elsif (not $self->{dirty}) {
				$self->{dirty} = 1;
				given ($command) {
					when (/^(t|toggle info)$/) {
						$self->{menu}->leave;
					}
					when (/^e$/ and not $args{fullscreen}) {
						my $filename = $self->pic->{id}.'.tags';
						-e $filename or FileItr->dirty();
						system "\$EDITOR $filename";
						$self->pic->add($filename);
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

sub action_has_tag
{my ($action, $tag) = @_;

	defined Array::find($action->{tags}, $tag);
}#

sub add_tag_to_actions
{my ($tag, $actions) = @_;

	foreach (keys %{$actions}) {
		my $a = $actions->{$_};
		$a->{tags} //= [];
		push @{$a->{tags}}, $tag;
	}

	%{$actions};
}#

sub do
{my ($self, $command) = @_;

	return unless defined $command;
	return if $self->do_menu($command);

	my ($app, $view) = ($self, $self->{views}->[0]);
	my %actions = (#{my

		add_tag_to_actions('global',
		{#{my}
			quit => {
				keys => [],
				code => sub { $app->quit },
			},
			toggle_fullscreen => {
				keys => [ 'f', 'f11' ],
				code => sub { $app->fullscreen_toggle },
				tags => [ 'global' ],
			},
			info_toggle => {
				keys => [ 'i' ],
				code => sub {
					$args{info_toggle} = !$args{info_toggle};
					$args{exif_toggle} = 0;
				},
			},
			exif_toggle => {
				keys => [ 'e' ],
				code => sub {
					$args{exif_toggle} = !$args{exif_toggle};
				},
			},
		}), #}#

		add_tag_to_actions('browser',
		{#{my}
			previous_picture => {
				keys => [ 'left', 'h' ],
				code => sub { $view->seek('-1') },
			},
			next_picture => {
				keys => [ 'right', 'l' ],
				code => sub { $view->seek('+1') },
			},
			date_seek => {
				keys => [ 'd', 'm', 'y', 'shift-d', 'shift-m', 'shift-y' ],
				code => sub { $view->seek_levels($command, { d=>1, m=>2, y=>3 }) },
			},
			previous_line => {
				keys => [ 'up', 'k' ],
				code => sub { $view->seek('-line') },
			},
			next_line => {
				keys => [ 'down', 'j' ],
				code => sub { $view->seek('+line') },
			},
			previous_page => {
				keys => [ 'page_up', 'backspace' ],
				code => sub { $view->seek('-page') },
			},
			next_page => {
				keys => [ 'page_down', 'space' ],
				code => sub { $view->seek('+page') },
			},
			first_picture => {
				keys => [ 'home', 'g-g' ],
				code => sub { $view->seek('first') },
			},
			last_picture => {
				keys => [ 'end', 'shift-g' ],
				code => sub { $view->seek('last') },
			},
			zoom_in => {
				keys => [ '=', '[+]' ],
				code => sub { $view->{zoom}++; $view->{zoom} =  1 if $view->{zoom} == -1; },
				tags => [ 'pic' ],
			},
			zoom_out => {
				keys => [ '-', '[-]' ],
				code => sub { $view->{zoom}--; $view->{zoom} = -2 if $view->{zoom} ==  0; },
				tags => [ 'pic' ],
			},
			zoom_reset => {
				keys => [  ],
				code => sub { $view->{zoom} = 1 },
				tags => [ 'pic' ],
			},
			switch_views => {
				keys => [ 'tab' ],
				code => sub { Array::rotate $app->{views} },
			},
			starred_view => {
				keys => [ 'control-s' ],
				code => sub { $app->enter_star_view },
			},
			hidden_view => {
				keys => [ 'control-shift-h' ],
				code => sub { $app->enter_hidden_view },
			},
			close_view => {
				keys => [ 'control-w', 'escape', 'q' ],
				code => sub { $app->close_view },
			},
		}), #}#

		add_tag_to_actions('pic',
		{#{my}
			selection_toggle => {
				keys => [ 'x' ],
				code => sub { $view->toggle_selection },
			},
			selection_toggle_all_visible => {
				keys => [ 'shift-x' ],
				code => sub { $view->toggle_selection_page },
			},
			edit_file => {
				keys => [ 'control-d' ],
				code => sub { $view->pic->develop },
			},
			print_files => {
				keys => [ 'p' ],
				code => sub { $view->pic->print }
			},
			print_files_selected => {
				keys => [ ';-p' ],
				code => sub { $_->print foreach($view->selected_pics) }
			},
			toggle_star => {
				keys => [ 's' ],
				code => sub { $view->pic->{tags}->toggle('_star') },
			},
			toggle_hidden => {
				keys => [ 'shift-1' ],
				code => sub { $view->pic->{tags}->toggle('_hidden') },
			},
			tag_edit => {
				keys => [ 't' ],
				code => sub { $app->enter_tag_mode },
			},
			repeat_last_tag => {
				keys => [ '.' ],
				code => sub { $view->pic->{tags}->toggle($app->{last_tag}) },
			},
			delete_picture => {
				keys => [ 'delete' ],
				code => sub { $view->delete_current },
			},
			enter_folder => {
				keys => [ 'enter', 'return' ],
				code => sub { $view->seek('down') },
			},
			leave_folder => {
				keys => [ 'escape' ],
				code => sub { $view->seek('up') },
			},
			play => {
				keys => [ 'shift-p' ],
				code => sub { $view->pic->play },
			},
		}), #}#

		add_tag_to_actions('menu',
		{#{my}

		}), #}#

	);#}#

	ACTION:
	foreach my $action (keys %actions) {
		foreach ($action, @{$actions{$action}->{keys}}) {
			if ($command eq $_) {
				&{$actions{$action}->{code}}($command);
				$view->adjust_page_and_cursor;
				$self->{dirty} = 1;
				last ACTION;
			}
		}
	}
}#

sub handle_event
{my ($self, $event) = @_;

	state $shift   = 0;
	state $control = 0;

	use SDL::Constants;
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
			if ($key =~ /^[g;]$/) {
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
			say 'resizing to '.join('x',$event->resize_w,$event->resize_h) if dbg;
			$self->{app}->resize($event->resize_w, $event->resize_h);
			$self->{dirty} = 1;
		}
		when ($_ == SDL_QUIT()) {
			$self->quit;
		}
	}
}#

sub new
{#{my constructor}

	sub fixlink { -l $_[0] ? readlink $_[0] : $_[0] }

	$args{basedir} = fixlink $args{basedir};

	if ($args{import}) {
		use import;
		exit(import::import_any($args{files}) ? 0 : 1);
	}

	if (exists $args{files}) {
		die 'only one startdir supported'  if scalar @{$args{files}} != 1;
		my $dir = $args{files}->[0];
		unless ($dir =~ m{^/}) {
			my $pwd = `pwd`; chomp $pwd;
			$dir = $pwd."/$dir";
		}
		$args{startdir} = fixlink $dir;
	}

	$args{jaildir} //=
		defined $args{startdir} ?
			$args{startdir} =~ m|^$args{basedir}/| ?
				$args{basedir}
				: $args{startdir}
			: $args{basedir};

	my ($w, $h) = get_window_geometry;
	bless my $self = {

		views      => [],
		factory    => Factory::new,
		menu       => Menu::new,
		key_hold   => '',
		last_tag   => '',
		dirty      => 1,

		# rendering state
		info_toggle => 1,
		exif_toggle => 0,
		text => Text::new(
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

	push @{$self->{views}}, View::new(
		PictureItr->new($args{startdir} // $args{basedir}),
		[ (split /,/, $args{include}) ],
		[ (split /,/, $args{exclude}), '_hidden' ]
	);

	#TODO
	#if (scalar @{$self->{views}[0]{ids}} == 0) {
	#	say 'no pictures matching the filter';
	#	return;
	#}

	$self->load_state;
	$self;
}#

sub main
{my @args = @_;

	args::read_args(@args);

	my $self = new;

	SDL::ShowCursor(0);

	use SDL::Event;
	my $event = new SDL::Event;
	SDL::Event->set_key_repeat(200, 30);

	while(1) {

		if ($self->{dirty}) {
			$self->display;
			$self->{dirty} = 0;
		}

		$event->wait;
		do {
			$self->handle_event($event);
		} while ($event->poll);
	}

}#

1;
# vim600:fdm=marker:fmr={my,}#:
