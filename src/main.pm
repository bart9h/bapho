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
			follow => 1,
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

sub display_pic ($$$$$;$)
{#
	my ($self, $pic, $w, $h, $x, $y, $is_selected) = @_;

	my $surf = $pic->get_surface ($w, $h);

	my $dest = SDL::Rect->new (
		-x => $x + ($w - $surf->width)/2,
		-y => $y + ($h - $surf->height)/2,
		-width => $surf->width,
		-height => $surf->height,
	);

	$surf->blit (0, $self->{app}, $dest);

	if ($is_selected)
	{#  draw cursor

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
}#

sub display
{#
	my ($self) = @_;
	my ($W, $H) = ($self->{app}->width, $self->{app}->height);

	state $bg = SDL::Color->new (-r => 0, -g => 0, -b => 0);
	$self->{app}->fill (0, $bg);

	my $key = $self->{keys}->[$self->{page_first}];
	my $pic = $self->{pics}->{$key};

	if ($self->{zoom} < -1)
	{# thumbnails

		my $d = (sort $W, $H)[0];  # smallest window dimention
		my $n = -$self->{zoom};    # number of pictures across that dimention
		($self->{cols}, $self->{rows}) = (int($W/($d/$n)), int($H/($d/$n)));
		my ($w, $h) = (int($W/$self->{cols}), int($H/$self->{rows}));  # thumbnail area

		my $i = $self->{page_first};
		THUMB: foreach my $y (0 .. $self->{rows}-1) {
			foreach my $x (0 .. $self->{cols}-1) {
				my $key = $self->{keys}->[$i];
				my $pic = $self->{pics}->{$key};
				$self->display_pic ($pic, $w, $h, $x*$w, $y*$h, $i==$self->{cursor});
				++$i;
				last THUMB if $i >= scalar @{$self->{keys}};
			}
		}
	}#
	else {
		$self->{rows} = $self->{cols} = 1;
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

sub adjust_page_and_cursor ($)
{#
	my ($self) = @_;

	my $last = (scalar @{$self->{keys}}) - 1;
	my $page_size = $self->{rows}*$self->{cols};

	if ($self->{cursor} < 0) {
		$self->{cursor} = $last;
		$self->{page_first} = $last>=$page_size ? $last-($page_size-1) : 0;
	}
	elsif ($self->{cursor} > $last) {
		$self->{cursor} = $self->{page_first} = 0;
	}
	elsif ($page_size > 1) {
		if (scalar @{$self->{keys}} > $page_size) {
			$self->{page_first} += $page_size
				while $self->{cursor}-$self->{page_first} >= $page_size;

			$self->{page_first} -= $page_size
				while $self->{cursor} < $self->{page_first};

			$self->{page_first} = 0
				if $self->{page_first} < 0;

			my $last_page = (scalar @{$self->{keys}}) - $page_size;
			$self->{page_first} = $last_page
				if $self->{page_first} > $last_page;
		}
	}
	else {
		$self->{page_first} = $self->{cursor};
	}

}#

sub do ($)
{#
	my ($self, $command) = @_;
	return unless defined $command;

	given ($command) {
		when (/^right$/)        { $self->{cursor}++; }
		when (/^left$/)         { $self->{cursor}--; }
		when (/^up$/)           { $self->{cursor} -= $self->{cols}; }
		when (/^down$/)         { $self->{cursor} += $self->{cols}; }
		when (/^page down$/)    { $self->{cursor} += $self->{rows}*$self->{cols}; }
		when (/^page up$/)      { $self->{cursor} -= $self->{rows}*$self->{cols}; }
		when (/^home$/)         { $self->{cursor} = 0; }
		when (/^end$/)          { $self->{cursor} = scalar @{$self->{keys}} - 1; }
		when (/^toggle info$/)  { $self->{display_info} = !$self->{display_info}; }
		when (/^zoom in$/)      { $self->{zoom}++; $self->{zoom} =  0 if $self->{zoom} == -1; }
		when (/^zoom out$/)     { $self->{zoom}--; $self->{zoom} = -2 if $self->{zoom} == -1; }
		when (/^zoom reset$/)   { $self->{zoom} = 1; }
		when (/^quit$/)         { exit(0); }
		default {
			$self->{dirty} = 0;
			say 'unhandled command ['.$command.']';
		}
	}

	$self->adjust_page_and_cursor;

	1;
}#

sub handle_event ($)
{#
	my ($self, $event) = @_;

	given ($event->type) {
		when ($_ == SDL_KEYDOWN()) {
			$self->{dirty} = 1;
			my %ev2cmd = (
				q         => 'quit',
				escape    => 'quit',
				space     => 'page down',
				backspace => 'page up',
				i         => 'toggle info',
				'-'       => 'zoom out',
				'='       => 'zoom in',
			);

			$self->do ($ev2cmd{$event->key_name} // $event->key_name);
		}
		when ($_ == SDL_MOUSEBUTTONDOWN()) {
			$self->{dirty} = $self->do (
				{
					3 => 'toggle info',
					4 => 'page up',
					5 => 'page down',
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

	# pictures
	$self->{pics} = load_files;
	$self->{keys} = [ sort keys %{$self->{pics}} ];

	# SDL window
	my ($w, $h) = get_window_geometry;
	$self->{app} = SDL::App->new (
		-title => 'bapho',
		-width => $w,
		-height => $h,
		($args{fullscreen} ? '-fullscreen':'-resizeable') => 1,
	);

	# rendering state
	$self->{display_info} = 0;
	$self->{text} = text::new (
		'Bitstream Vera Sans Mono:18',
		':14',
	);

	# navigation state
	$self->{cursor} = $self->{page_first} = 0;
	$self->{rows} = $self->{cols} = 1;
	$self->{zoom} = 1;

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
