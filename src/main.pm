package main;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use SDLx::App;
use SDL::Mouse;

use args qw/%args dbg/;
use Array;
use display;
use Factory;
use Menu;
use Picture;
use Text;
use View;

#}#

sub view { $_[0]->{views}->[$_[0]->{current_view}] }

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

	my ($w, $h) = (0, 0);
	if ($args{fullscreen}) {
		($w, $h) = get_root_geometry;
	}
	elsif (defined $args{geometry}) {
		if ($args{geometry} =~ /(\d+)x(\d+)/) {
			($w, $h) = ($1, $2);
		}
	}
	else {
		($w, $h) = get_root_geometry;
		$w /= 2;
		$h /= 2;
	}

	return ($w, $h);
}#

sub fullscreen_toggle
{my ($self) = @_;

	$args{fullscreen} = not $args{fullscreen};


	# This two different orders for in and out of fullscreen
	# is to avoid changing screen resolutions.
	if ($args{fullscreen}) {
		$self->{app}->resize(get_window_geometry);
		SDL::Video::wm_toggle_fullscreen($self->{app});
		SDL::Mouse::show_cursor(0);
	}
	else {
		SDL::Video::wm_toggle_fullscreen($self->{app});
		$self->{app}->resize(get_window_geometry);
		SDL::Mouse::show_cursor(1);
	}
}#

sub load_state
{my ($self) = @_;

	args::load_state;

	# restore view from args
	my $i = 1;
	while (defined $args{"view_${i}_cursor"}) {
		my $view = View::new(
			PictureItr->new($args{startdir} // $args{basedir}, $self->{jaildir}),
			[ (split /,/, $args{"view_${i}_and"}) ],
			[ (split /,/, $args{"view_${i}_or"})  ],
			[ (split /,/, $args{"view_${i}_out"}) ],
			$args{"view_${i}_cursor"},
		);
		push @{$self->{views}}, $view;

		delete $args{"view_${i}_$_"}  foreach qw/cursor and or out/;
		++$i;
	}
	foreach (qw/current_view last_view/) {
		$self->{$_} = $args{$_}  if defined $args{$_};
	}

	# if no views loaded, create one
	if (scalar @{$self->{views}} == 0) {
		push @{$self->{views}}, View::new(
			PictureItr->new($args{startdir} // $args{basedir}, $self->{jaildir}),
			[ (split /,/, $args{and}) ],
			[ (split /,/, $args{or}) ],
			[ (split /,/, $args{exclude}) ]
		);
	}
}#

sub save_state
{my ($self) = @_;

	my %state = (
		info_toggle  => $args{info_toggle},
		exif_toggle  => $args{exif_toggle},
		current_view => $self->{current_view},
		last_view    => $self->{last_view},
	);

	my $view_idx = 1;
	foreach (@{$self->{views}}) {
		my $k = "view_$view_idx";
		$state{$k.'_cursor'} = $_->pic->{sel};
		$state{$k.'_and'  } = join ',', keys %{$_->{and}};
		$state{$k.'_or'   } = join ',', keys %{$_->{or}};
		$state{$k.'_out'  } = join ',', keys %{$_->{out}};
		++$view_idx;
	}

	args::save_state(\%state);
}#

sub view_set_cursor
{my ($self, $idx) = @_;

	my $original_view = $self->{current_view};

	my $N = scalar @{$self->{views}};
	$self->{current_view} =
		$idx < 0 ? $N-1 :
		$idx >= $N ? 0 :
		$idx;

	if ($self->{current_view} != $original_view) {
		$self->{last_view} = $original_view;
	}
}#

sub close_view
{my ($self) = @_;

	$self->{last_view} = undef;
	splice @{$self->{views}}, $self->{current_view}, 1;
	if ($self->{current_view} >= scalar @{$self->{views}}) {
		$self->{current_view} = scalar @{$self->{views}} - 1;
	}

	unless (@{$self->{views}}) {
		# the last view was closed
		$self->quit;
	}
}#

sub quit
{my ($self) = @_;

	$self->save_state  if $self->{jaildir} eq $args{basedir};
	exit(0);
}#

sub enter_tag_editor
{my ($self) = @_;

	$self->{menu}->enter('tag_editor', Tags::groups());
	Tags::begin_edit();
}#

sub enter_view_editor
{my ($self) = @_;

	$self->{menu}->enter('view_editor', Tags::ALL());
}#

sub do_menu
{my ($self, $command) = @_;

	return 0  unless $self->{menu}->{action};

	$self->{dirty} = $self->{menu}->do($command);
	my $activated = $self->{menu}->{activated};

	if ($self->{menu}->{action} eq 'tag_editor') {
		if (defined $activated) {
			$self->view->pic->{tags}->toggle($activated);
		}
		elsif (not $self->{dirty}) {
			$self->{dirty} = 1;
			if ($command =~ /^(t|toggle info)$/) {
				$self->{menu}->leave;
			}
			elsif ($command eq 'e' and not $args{fullscreen}) {
				my $filename = $self->view->pic->{id}.'.tags';
				-e $filename  or FileItr->dirty();
				system "\$EDITOR $filename";
				$self->view->pic->add($filename, time);
				$self->enter_tag_editor;
				$self->display;
			}
			else {
				$self->{dirty} = 0;
			}
		}
	}
	elsif ($self->{menu}->{action} eq 'view_editor') {
		if (defined $activated) {
			if ($self->view->{and}->{$activated}) {
				delete $self->view->{and}->{$activated};
				$self->view->{or}->{$activated} = 1;
			}
			elsif ($self->view->{or}->{$activated}) {
				delete $self->view->{or}->{$activated};
				$self->view->{out}->{$activated} = 1;
			}
			elsif ($self->view->{out}->{$activated}) {
				delete $self->view->{out}->{$activated};
			}
			else {
				$self->view->{and}->{$activated} = 1;
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

	return  unless defined $command;
	return  if $self->do_menu($command);

	my $view = $self->view;
	my %actions = (#{my

		add_tag_to_actions('global',
		{#{my
			quit => {
				keys => [ 'q' ],
				code => sub { $self->quit },
			},
			toggle_fullscreen => {
				keys => [ 'f', 'f11' ],
				code => sub { $self->fullscreen_toggle },
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
		{#{my
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
				keys => [ 'z-i', '=', '[+]' ],
				code => sub { $view->{zoom}++; $view->{zoom} =  1  if $view->{zoom} == -1; },
				tags => [ 'pic' ],
			},
			zoom_out => {
				keys => [ 'z-o', '-', '[-]' ],
				code => sub { $view->{zoom}--; $view->{zoom} = -2  if $view->{zoom} ==  0; },
				tags => [ 'pic' ],
			},
			zoom_reset => {
				keys => [ 'z-z' ],
				code => sub { $view->{zoom} = 1 },
				tags => [ 'pic' ],
			},
			view_create => {
				keys => [ 'v-c', 'control-t' ],
				code => sub { push @{$self->{views}}, View::new($view->{picitr}); $self->view_set_cursor(-1) },
			},
			view_edit => {
				keys => [ 'v-e' ],
				code => sub { $self->enter_view_editor },
			},
			view_delete => {
				keys => [ 'v-d', 'control-w' ],
				code => sub { $self->close_view },
			},
			view_next => {
				keys => [ 'v-n', 'tab' ],
				code => sub { $self->view_set_cursor($self->{current_view}+1) },
			},
			view_prev => {
				keys => [ 'v-p', 'shift-tab' ],
				code => sub { $self->view_set_cursor($self->{current_view}-1) },
			},
			view_last => {
				keys => [ 'v-v' ],
				code => sub { $self->view_set_cursor($self->{last_view})  if defined $self->{last_view} },
			},
			view_1 => { keys => [ 'v-1', 'f1' ], code => sub { $self->view_set_cursor(0) } },
			view_2 => { keys => [ 'v-2', 'f2' ], code => sub { $self->view_set_cursor(1) } },
			view_3 => { keys => [ 'v-3', 'f3' ], code => sub { $self->view_set_cursor(2) } },
			view_4 => { keys => [ 'v-4', 'f4' ], code => sub { $self->view_set_cursor(3) } },
			view_5 => { keys => [ 'v-5', 'f5' ], code => sub { $self->view_set_cursor(4) } },
			view_6 => { keys => [ 'v-6', 'f6' ], code => sub { $self->view_set_cursor(5) } },
			view_7 => { keys => [ 'v-7', 'f7' ], code => sub { $self->view_set_cursor(6) } },
			view_8 => { keys => [ 'v-8', 'f8' ], code => sub { $self->view_set_cursor(7) } },
			view_9 => { keys => [ 'v-9', 'f9' ], code => sub { $self->view_set_cursor(8) } },
		}), #}#

		add_tag_to_actions('pic',
		{#{my
			selection_toggle => {
				keys => [ 'x' ],
				code => sub { $view->toggle_selection },
			},
			selection_toggle_all_visible => {
				keys => [ 'shift-x' ],
				code => sub { $view->toggle_selection_page },
			},
			edit_file_ufraw => {
				keys => [ 'control-u' ],
				code => sub { $view->pic->develop('ufraw'); FileItr->dirty() },
			},
			edit_file_gimp => {
				keys => [ 'control-g' ],
				code => sub { $view->pic->develop('gimp'); FileItr->dirty() },
			},
			edit_file => {
				keys => [ 'control-d' ],
				code => sub { $view->pic->develop; FileItr->dirty() },
			},
			open_folder => {
				keys => [ 'control-f' ],
				code => sub { $view->pic->open_folder },
			},
			mark_first => {
				keys => [ 'r-a' ],
				code => sub { $view->mark('first') },
			},
			mark_last => {
				keys => [ 'r-b' ],
				code => sub { $view->mark('last') },
			},
			print_marked_pics => {
				keys => [ 'r-p' ],
				code => sub { foreach($view->marked_pics) { say foreach(keys %{$_->{files}}) } }
			},
			tag_marked_pics => {
				keys => [ 'r-.' ],
				code => sub { foreach($view->marked_pics) { $_->{tags}->repeat_last_edit } }
			},
			print_files => {
				keys => [ 'p-p' ],
				code => sub { $view->pic->print }
			},
			print_folder => {
				keys => [ 'p-f' ],
				code => sub { $_->print foreach($view->folder_pics) }
			},
			print_files_selected => {
				keys => [ ';-p' ],
				code => sub { $_->print foreach($view->selected_pics) }
			},
			develop_folder => {
				keys => [ 'o' ],
				code => sub { Picture::develop_pics($view->folder_pics) }
			},
			develop_selected => {
				keys => [ ';-d' ],
				code => sub { Picture::develop_pics($view->selected_pics) }
			},
			develop_marked => {
				keys => [ 'r-d' ],
				code => sub { Picture::develop_pics($view->marked_pics) }
			},
			tag_selected_pics => {
				keys => [ ';-.' ],
				code => sub { $_->{tags}->repeat_last_edit foreach($view->selected_pics) }
			},
			add_star => {
				keys => [ 's' ],
				code => sub { $view->pic->{tags}->toggle_star },
			},
			remove_star => {
				keys => [ 'shift-s' ],
				code => sub { $view->pic->{tags}->toggle_star(-1) },
			},
			toggle_hidden => {
				keys => [ 'shift-1' ],
				code => sub { $view->pic->{tags}->toggle('_hidden') },
			},
			tag_edit => {
				keys => [ 't' ],
				code => sub { $self->enter_tag_editor },
			},
			repeat_last_tag => {
				keys => [ '.' ],
				code => sub { $view->pic->{tags}->repeat_last_edit },
			},
			delete_picture => {
				keys => [ 'delete' ],
				code => sub { $view->delete_current },
			},
			play => {
				keys => [ 'enter', 'return' ],
				code => sub { $view->pic->play },
			},
		}), #}#

		add_tag_to_actions('menu',
		{#{my

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
	if ($event->type == SDL_KEYDOWN()) {
		my $key = SDL::Events::get_key_name($event->key_sym);
		$shift   = 1  if $key =~ m{^(left|right)\ shift$};
		$control = 1  if $key =~ m{^(left|right)\ ctrl$};
		$key =   'shift-'.$key  if $shift;
		$key = 'control-'.$key  if $control;

		if ($self->{key_hold}) {
			$key = "$self->{key_hold}-$key"; #FIXME: can't use - key
			$self->{key_hold} = '';
		}
		if ($key =~ /^[gprvz;]$/) { #FIXME: compute the list of keys that a start a multi-key binding
			$self->{key_hold} = $key;
		}
		else {
			$key =~ s/\ /_/g;
			$self->do($key);
		}
	}
	elsif ($event->type == SDL_KEYUP()) {
		my $sym = SDL::Events::get_key_name($event->key_sym);
		if    ($sym =~ m{^(left|right)\ shift$}) { $shift   = 0 }
		elsif ($sym =~ m{^(left|right)\ ctrl$})  { $control = 0 }
	}
	elsif ($event->type == SDL_MOUSEBUTTONDOWN()) {
		say 'mouse button '.$event->button_button  if dbg 'event';
		$self->do(
			{
				3 => 'info_toggle',
				4 => 'page_down',
				5 => 'page_up',
			}->{$event->button_button} // 'button-'.$event->button_button
		);
	}
	elsif ($event->type == SDL_VIDEORESIZE()) {
		say 'resizing to '.join('x',$event->resize_w,$event->resize_h)  if dbg 'event', 'video';
		$self->{app}->resize($event->resize_w, $event->resize_h);
		$self->{dirty} = 1;
	}
	elsif ($event->type == SDL_QUIT()) {
		$self->quit;
	}
}#

sub new_sdl_window
{my ($self) = @_;

	my ($w, $h) = get_window_geometry;

	my %sdl_args = (
		title => 'bapho',
		width => $w,
		height => $h,
	);

	if ($args{fullscreen}) {
		$sdl_args{flags} = SDL::Video::SDL_FULLSCREEN;
	}
	else {
		$sdl_args{resizeable} = 1;
	}

	my $surf = SDLx::App->new(%sdl_args);
	$self->{white} = SDL::Video::map_RGB($surf->format, 255, 255, 255);
	$self->{black} = SDL::Video::map_RGB($surf->format, 0, 0, 0);
	$self->{null_rect} = SDL::Rect->new(0, 0, 0, 0);
	$surf;
}#

sub new
{#{my constructor}

	Tags::init();

	sub fixlink { -l $_[0] ? readlink $_[0] : $_[0] }

	$args{basedir} = fixlink $args{basedir};
	-d $args{basedir}  or die "$args{basedir} not found.\n";

	if (exists $args{files}) {
		die "only one startdir is currently supported\n"  if scalar @{$args{files}} != 1;
		my $dir = $args{files}->[0];
		unless ($dir =~ m{^/}) {
			my $pwd = `pwd`; chomp $pwd;
			$dir = $pwd."/$dir";
		}
		$args{startdir} = fixlink $dir;
	}

	my $jaildir = defined $args{startdir}
		? $args{startdir} =~ m|^$args{basedir}/|
			? $args{basedir}
			: $args{startdir}
		: $args{basedir};


	if ($args{import}) {
		use import;
		exit(import::import_any($args{files}) ? 0 : 1);
	}
	elsif ($args{print}) {
		die "not implemented\n";
=a
		$view->seek('first');
		while(1) {
			my $path = $view->pic->{sel};
			say $path;
			$view->seek('+1');
			last  if $path eq $view->pic->{sel};
		}
		exit(0);
=cut
	}

	bless my $eu = {

		views         => [],
		current_view  => 0,
		last_view     => undef,
		factory       => Factory::new,
		menu          => Menu::new,
		key_hold      => '',
		dirty         => 1,

		# rendering state
		info_toggle   => 1,
		exif_toggle   => 0,
		text          => Text::new(
			'Bitstream Vera Sans Mono:20',
			':18',
			':32',
		),

		jaildir       => $jaildir,
	};

	$ENV{SDL_VIDEO_ALLOW_SCREENSAVER} = 1;
	$eu->{app} = $eu->new_sdl_window();
	$eu->load_state;
	$eu;
}#

sub main
{my @arghs = @_;

	args::read_args(@arghs);

	my $self = new;

	use SDL::Event;
	my $event = new SDL::Event;
	SDL::Events::enable_key_repeat($args{key_repeat_start_delay}, $args{key_repeat_image_delay});

	while(1) {

		if ($self->{dirty}) {
			$self->display;
			$self->{dirty} = 0;
		}

		SDL::Events::wait_event($event);
		do {
			$self->handle_event($event);
		} while (SDL::Events::poll_event($event));
	}

}#

1;
# vim600:fdm=marker:fmr={my,}#:
