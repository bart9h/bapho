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

#}#

sub get_window_geometry
{my ($self) = @_;

	my ($w, $h) = (0, 0);

	if (defined $args{geometry}) {
		($w, $h) = $args{geometry} =~ /(\d+)x(\d+)/ ? ($1, $2) : (0, 0)
	}

	if ($args{fullscreen}) {
		if ($w == 0) {
			($w, $h) = `xdpyinfo` =~ /\b(\d{2,})x(\d{2,})\b/s ? ($1, $2) : (0, 0);
			for (2 .. 10)
			{#{my ugly hack: fix multi-monitor}
				$_ = 12 - $_;
				if ($w > $_*$h) {
					$w = int ($w/$_);
					last;
				}
			}#
		}
	}

	($w, $h);
}#

sub adjust_page_and_cursor
{my ($self) = @_;

	my $last = (scalar @{$self->{ids}}) - 1;
	my $page_size = $self->{rows}*$self->{cols};

	if ($self->{cursor} < 0) {
		$self->{cursor} = $last;
		$self->{page_first} = $last>=$page_size ? $last-($page_size-1) : 0;
	}
	elsif ($self->{cursor} > $last) {
		$self->{cursor} = $self->{page_first} = 0;
	}
	elsif ($page_size > 1) {
		if (scalar @{$self->{ids}} > $page_size) {
			$self->{page_first} += $page_size
				while $self->{cursor}-$self->{page_first} >= $page_size;

			$self->{page_first} -= $page_size
				while $self->{cursor} < $self->{page_first};

			$self->{page_first} = 0
				if $self->{page_first} < 0;

			my $last_page = (scalar @{$self->{ids}}) - $page_size;
			$self->{page_first} = $last_page
				if $self->{page_first} > $last_page;
		}
	}
	else {
		$self->{page_first} = $self->{cursor};
	}

}#

sub enter_tag_mode
{my ($self) = @_;

	$self->{menu}->enter ('tag_editor', [ sort keys %{$self->{collection}->{tags}} ]);
}#

sub pic
{my ($self) = @_;

	$self->{collection}->{pics}->{$self->{ids}->[$self->{cursor}]};
}#

sub seek_date
{my ($self, $key) = @_;

	my $cur = $self->pic;
	my $last = (scalar @{$self->{ids}}) - 1;
	given ($key) {
		my $d = /[a-z]/ ? 1 : -1;
		while ($self->{cursor} >= 0  and  $self->{cursor} <= $last) {
			$self->{cursor} += $d;
			$self->{cursor} = 0      if $self->{cursor} > $last;
			$self->{cursor} = $last  if $self->{cursor} < 0;

			our $k = lc $key;
			sub part($) { substr $_[0]->{id}, 0, {d=>8,m=>6,y=>4}->{$k} }
			last  if part($self->pic) ne part($cur);
		}
	}
}#

sub do_menu
{my ($self, $command) = @_;

	return 0 unless $self->{menu}->{active};

	my $rc = $self->{menu}->do ($command);
	given ($self->{menu}->{action}) {
		when (/^tag_editor$/) {
			if ($rc) {
				my $tag = $self->{menu}->{selected};
				$self->pic->toggle_tag ($tag)  if defined $tag;
			}
			else {
				given ($command) {
					when (/^(t|toggle info)$/) {
						$self->{menu}->leave;
						$self->pic->save_tags;
					}
					when (/^e$/) {
						$self->pic->save_tags;
						my $filename = $self->pic->get_tag_filename;
						system "\$EDITOR $filename";
						$self->pic->add ($filename);
						$self->{collection}->update_tags;
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
	return $array_ref;
}#

sub do
{my ($self, $command) = @_;

	return unless defined $command;
	return if $self->do_menu ($command);

	given ($command) {
		when (/^right$/)        { $self->{cursor}++ }
		when (/^left$/)         { $self->{cursor}-- }
		when (/^up$/)           { $self->{cursor} -= $self->{cols} }
		when (/^down$/)         { $self->{cursor} += $self->{cols} }
		when (/^page down$/)    { $self->{cursor} += $self->{rows}*$self->{cols} }
		when (/^page up$/)      { $self->{cursor} -= $self->{rows}*$self->{cols} }
		when (/^home$/)         { $self->{cursor} = 0 }
		when (/^end$/)          { $self->{cursor} = scalar @{$self->{ids}} - 1 }
		when (/^[dmy]$/i)       { $self->seek_date($_) }
		when (/^toggle info$/)  { rotate($self->{info_modes}) }
		when (/^zoom in$/)      { $self->{zoom}++; $self->{zoom} =  1 if $self->{zoom} == -1; }
		when (/^zoom out$/)     { $self->{zoom}--; $self->{zoom} = -2 if $self->{zoom} ==  0; }
		when (/^zoom reset$/)   { $self->{zoom} = 1 }
		when (/^quit$/)         { $self->quit }
		when (/^control-d$/)    { $self->pic->develop }
		when (/^p$/)            { say join "\n", keys %{$self->pic->{files}} }
		when (/^s$/)            { $self->pic->toggle_tag('_star') }
		when (/^t$/)            { $self->enter_tag_mode }
		when (/^delete$/)       {
			$self->{collection}->delete ($self->pic);
			$self->{ids} = [ sort keys %{$self->{collection}->{pics}} ];
		}
		default                 { $self->{dirty} = 0 }
	}

	$self->adjust_page_and_cursor;

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
			$self->do ($ev2cmd{$key} // $key);
		}
		when ($_ == SDL_KEYUP()) {
			$shift   = 0  if $event->key_name =~ m{^(left|right)\ shift$};
			$control = 0  if $event->key_name =~ m{^(left|right)\ ctrl$};
		}
		when ($_ == SDL_MOUSEBUTTONDOWN()) {
			$self->{dirty} = $self->do (
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
		die 'import what?'  unless exists $args{files};
		use import;
		exit (import::import_files(@{$args{files}}) ? 0 : 1);
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
		collection => collection::new(),

		# navigation state
		cursor     => 0,
		page_first => 0,
		rows       => 1,
		cols       => 1,
		zoom       => 1,
		menu       => menu::new(),

		# rendering state
		info_modes => [ qw/none title tags/ ],
		text => text::new (
			'Bitstream Vera Sans Mono:24',
			':20',
		),

		# SDL window
		app => SDL::App->new (
			-title => 'bapho',
			-width => $w,
			-height => $h,
			($args{fullscreen} ? '-fullscreen':'-resizeable') => 1,
		),

	};

	# sorted array of (the ids of) all pictures
	$self->{ids} = [ sort keys %{$self->{collection}->{pics}} ];

	SDL::ShowCursor(0);

	# prepare to enter main loop
	use SDL::Event;
	use SDL::Constants;
	my $event = new SDL::Event;
	SDL::Event->set_key_repeat (200, 30);
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
# vim600:fdm=marker:fmr={my,}#:
