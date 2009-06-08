use strict;
use warnings;
use 5.010;

use args qw/%args/;
use display;
use collection;
use picture;
use text;

use SDL::App;

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

	($w, $h);
}#

package main;

sub adjust_page_and_cursor ($)
{#
	my ($self) = @_;

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

sub enter_tag_mode ($)
{#
	my $self = shift;
	$self->{tag_mode} = 1;
	$self->{tag_cursor} = 0;
	$self->{tags} = [ sort keys %{$self->{collection}->{tags}} ];
}#

sub tag_do ($)
{#
	my ($self, $command) = @_;
	return unless defined $command;

	my $N = scalar @{$self->{tags}};

	given ($command) {
		when (/^up$/)           { $self->{tag_cursor}-- }
		when (/^down$/)         { $self->{tag_cursor}++ }
		when (/^home$/)         { $self->{tag_cursor} = 0 }
		when (/^end$/)          { $self->{tag_cursor} = $N - 1 }
		when (/^quit$/)         { $self->quit }
		when (/^e$/) {
			$self->pic->save_tags;
			my $filename = $self->pic->tag_filename;
			system "\$EDITOR $filename";
			$self->pic->add ($filename);
			$self->{collection}->update_tags;
			$self->enter_tag_mode;
			$self->display;
		}
		when (/^(page down|enter|return)$/) {
			$self->pic->toggle_tag ($self->{tags}->[$self->{tag_cursor}]);
		}
		when (/^(t|toggle info)$/) {
			$self->{tag_mode} = 0;
			$self->pic->save_tags;
		}
		default {
			$self->{dirty} = 0;
		}
	}

	$self->{tag_cursor} = 0     if $self->{tag_cursor} <  0;
	$self->{tag_cursor} = $N-1  if $self->{tag_cursor} >= $N;

	1;
}#

sub pic ($)
{#
	my $self = shift;
	$self->{collection}->{pics}->{$self->{ids}->[$self->{cursor}]};
}#

sub seek_date ($$)
{#
	my ($self, $key) = @_;
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

sub do ($)
{#
	my ($self, $command) = @_;
	return $self->tag_do($command)  if $self->{tag_mode};
	return unless defined $command;

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
		when (/^toggle info$/)  { $self->{display_info} = !$self->{display_info} }
		when (/^zoom in$/)      { $self->{zoom}++; $self->{zoom} =  1 if $self->{zoom} == -1; }
		when (/^zoom out$/)     { $self->{zoom}--; $self->{zoom} = -2 if $self->{zoom} ==  0; }
		when (/^zoom reset$/)   { $self->{zoom} = 1 }
		when (/^quit$/)         { $self->quit }
		when (/^d$/)            { $self->pic->develop }
		when (/^p$/)            { say join "\n", keys %{$self->pic->{files}} }
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

sub handle_event ($)
{#
	my ($self, $event) = @_;
	state $shift = 0;

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
			$shift = 1  if $key =~ m{^(left|right)\ shift$};
			$key = uc $key  if $shift;
			$self->do ($ev2cmd{$key} // $key);
		}
		when ($_ == SDL_KEYUP()) {
			$shift = 0  if $event->key_name =~ m{^(left|right)\ shift$};
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

sub quit ($)
{#
	my $self = shift;
	my $P = $self->{collection}->{pics};
	foreach (keys %{$P}) {
		$P->{$_}->save_tags;
	}
	exit(0);
}#

sub main (@)
{#
	args::read_args(@_);

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

	bless my $self = {};

	# pictures
	$self->{collection} = collection::new;
	$self->{ids} = [ sort keys %{$self->{collection}->{pics}} ];

	# SDL window
	my ($w, $h) = get_window_geometry;
	$self->{app} = SDL::App->new (
		-title => 'bapho',
		-width => $w,
		-height => $h,
		($args{fullscreen} ? '-fullscreen':'-resizeable') => 1,
	);

	SDL::ShowCursor(0);

	# rendering state
	$self->{display_info} = 0;
	$self->{text} = text::new (
		'Bitstream Vera Sans Mono:24',
		':20',
	);

	# navigation state
	$self->{cursor} = $self->{page_first} = 0;
	$self->{rows} = $self->{cols} = 1;
	$self->{zoom} = 1;

	# tag editor state
	$self->{tag_mode} = 0;
	$self->{tag_cursor} = 0;

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
# vim600:fdm=marker:fmr={#,}#:
