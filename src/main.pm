package main;

#{my uses

use strict;
use warnings;
use 5.010;

use SDL::App;

use args qw/%args/;
use collection;
use display;
use menu;
use picture;
use text;
use view;

#}#

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

sub enter_tag_mode
{my ($self) = @_;

	$self->{menu}->enter('tag_editor', [ sort keys %{$self->{collection}->{tags}} ]);
}#

sub do_menu
{my ($self, $command) = @_;

	return 0 unless $self->{menu}->{action};
	my $view = $self->{views}->[0];

	my $rc = $self->{menu}->do($command);
	given ($self->{menu}->{action}) {
		when (/^tag_editor$/) {
			if ($rc) {
				my $tag = $self->{menu}->{selected};
				$view->pic->toggle_tag($tag)  if defined $tag;
			}
			else {
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
				}
			}
		}
	}

	return 1;
}#

sub rotate
{my ($array_ref) = @_;

	push @$array_ref, shift @$array_ref;
}#

sub pick
{my ($array_ref, $item) = @_;

	my $idx;
	foreach (0 .. (scalar @$array_ref - 1)) {
		if ($array_ref->[$_] eq $item) {
			$idx = $_;
			last;
		}
	}

	if (defined $idx) {
		if ($idx > 0) {
			@$array_ref = @$array_ref[ $idx,  0 .. $idx-1,  $idx+1 .. $#$array_ref ];
		}
	}
	else {
		unshift @$array_ref, $item;
	}
}#

sub enter_star_view
{my ($self) = @_;

	$self->{star_view} //= view::new($self->{collection}, ['_star'], []);
	pick($self->{views}, $self->{star_view});
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

	if ($args{fullscreen}) {
		$self->{app}->resize($w, $h);
		$self->{app}->fullscreen;
	}
	else {
		$self->{app}->fullscreen;
		$self->{app}->resize($w, $h);
	}
}#

sub do
{my ($self, $command) = @_;

	return unless defined $command;
	return if $self->do_menu($command);

	my $view = $self->{views}->[0];

	given ($command) {
		when (/^control-d$/)    { $view->pic->develop }
		when (/^f$/)            { $self->fullscreen_toggle }
		when (/^p$/)            { say join "\n", keys %{$view->pic->{files}} }
		when (/^s$/)            { $view->pic->toggle_tag('_star') }
		when (/^control-s$/)    { $self->enter_star_view }
		when (/^t$/)            { $self->enter_tag_mode }
		when (/^[dmy]$/i)       { $view->seek_date($_) }

		when (/^left$/)         { $view->{cursor}-- }
		when (/^right$/)        { $view->{cursor}++ }
		when (/^up$/)           { $view->{cursor} -= $view->{cols} }
		when (/^down$/)         { $view->{cursor} += $view->{cols} }
		when (/^page up$/)      { $view->{cursor} -= $view->{rows}*$view->{cols} }
		when (/^page down$/)    { $view->{cursor} += $view->{rows}*$view->{cols} }
		when (/^home$/)         { $view->{cursor} = 0 }
		when (/^end$/)          { $view->{cursor} = scalar @{$view->{ids}} - 1 }

		when (/^delete$/)       { $view->delete_current }
		when (/^toggle info$/)  { rotate $self->{info_modes} }
		when (/^tab$/)          { rotate $self->{views}; $self->{views}->[0]->update }
		when (/^zoom in$/)      { $view->{zoom}++; $view->{zoom} =  1 if $view->{zoom} == -1; }
		when (/^zoom out$/)     { $view->{zoom}--; $view->{zoom} = -2 if $view->{zoom} ==  0; }
		when (/^zoom reset$/)   { $view->{zoom} = 1 }
		when (/^quit$/)         { $self->quit }

		default                 { $self->{dirty} = 0 }
	}

	$view->adjust_page_and_cursor;

	1;
}#

sub handle_event
{my ($self, $event) = @_;

	state $shift   = 0;
	state $control = 0;

	given ($event->type) {
		when ($_ == SDL_KEYDOWN()) {
			$self->{dirty} = 1;
			my %ev2cmd = (
				k         => 'up',
				j         => 'down',
				h         => 'left',
				l         => 'right',
				q         => 'quit',
				escape    => 'quit',
				space     => 'page down',
				backspace => 'page up',
				i         => 'toggle info',
				'-'       => 'zoom out',
				'='       => 'zoom in',
			);

			my $key = $event->key_name;
			$shift   = 1  if $key =~ m{^(left|right)\ shift$};
			$control = 1  if $key =~ m{^(left|right)\ ctrl$};
			$key = uc $key          if $shift;
			$key = 'control-'.$key  if $control;
			$self->do($ev2cmd{$key} // $key);
		}
		when ($_ == SDL_KEYUP()) {
			$shift   = 0  if $event->key_name =~ m{^(left|right)\ shift$};
			$control = 0  if $event->key_name =~ m{^(left|right)\ ctrl$};
		}
		when ($_ == SDL_MOUSEBUTTONDOWN()) {
			$self->{dirty} = $self->do(
				{
					3 => 'toggle info',
					4 => 'page down',
					5 => 'page up',
				}->{$event->button}
			);
		}
		when ($_ == SDL_QUIT()) {
			$self->quit;
		}
	}
}#

sub quit
{my ($self) = @_;

	my $P = $self->{collection}->{pics};
	foreach (keys %{$P}) {
		$P->{$_}->save_tags;
	}
	exit(0);
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
		star_view  => undef,
		menu       => menu::new,

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

	push @{$self->{views}}, view::new($self->{collection}, [], []);

	SDL::ShowCursor(0);

	# prepare to enter main loop
	use SDL::Event;
	use SDL::Constants;
	my $event = new SDL::Event;
	SDL::Event->set_key_repeat(200, 30);
	$self->display;

	while(1) {
		$event->wait;
		do {
			$self->handle_event($event);
		} while ($event->poll);

		$self->display  if $self->{dirty};
	}

}#

1;
# vim600:fdm=marker:fmr={my,}#:
