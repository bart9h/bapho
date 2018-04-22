package Video;
#{my uses
use strict;
use warnings;
use 5.010;
use Data::Dumper;
use SDL::Surface;
use args qw/%args dbg/;
#}#

sub play { player_command('play', $_[0]) }
sub load_sample_frame { player_command('load_sample_frame', $_[0]) }

sub render_film_roll_frame #FIXME nao funfa
{my ($surf) = @_;

	my $b = int($surf->h/(3*15+1));
	my $w = 1;  # width of the white line on the borders

	my $black = SDL::Video::map_RGB($surf->format, 0, 0, 0);
	my $white = SDL::Video::map_RGB($surf->format, 255, 255, 255);

	my $r = SDL::Rect->new(0, 0, $w, $surf->h);
	SDL::Video::fill_rect($surf, $r, $white);
	$r->x($surf->w- 1);
	SDL::Video::fill_rect($surf, $r, $white);

	foreach my $x (0+$w, $surf->w-1 -($w+5*$b)) {
		$r->x($x);
		$r->y(0);
		$r->w(5*$b);
		$r->h($surf->h);
		SDL::Video::fill_rect($surf, $r, $black);

		$r->x($x+$b);
		$r->w(3*$b);
		$r->h(2*$b);
		for (my $y = $b; $y < $surf->h; $y += 3*$b) {
			$r->y($y);
			SDL::Video::fill_rect($surf, $r, $white);
		}
	}
}#

sub player_command
{my ($command, $arg) = @_;

	state $player;
	unless (defined $player) {
		foreach my $p ('mpv', 'mplayer') {
			my $bin = `which $p 2>/dev/null`;
			chomp $bin;
			if (-x $bin) {
				$player = $p;
				last;
			}
		}
		unless (defined $player) {
			say STDERR "Can't find command to handle video files.\n"
			."Please install mpv or mplayer.";
			$player = '';
		}
	}
	$player or return;

	if ($command eq 'play') {
		my $cmdline = $player.(
			$args{fullscreen} ?
				$player eq 'mplayer' ? ' -fs'
				: $player eq 'mpv' ? ' --fs'
				: die
				: ''
		)." \"$arg\" &";

		say $cmdline  if dbg;
		system $cmdline;
	}
	elsif ($command eq 'load_sample_frame') {
		my $tmpdir = $args{temp_dir}.'/bapho-videopreview';
		-d $tmpdir  or mkdir $tmpdir  or die "$tmpdir: $!";
		my $framefile = "$tmpdir/00000001.jpg";

		my $cmd = "mplayer -frames 1 -ss 00:00:01 -vo jpeg:maxfiles=1:outdir=\"$tmpdir\" -ao null \"$arg\"";
		say $cmd  if dbg 'cmd,video,file';
		$cmd .= ' >/dev/null 2>/dev/null';
		system $cmd;

		my $surf;
		$surf = SDL::Image::load($framefile)  if -e $framefile;

		system "rm -rf \"$tmpdir\"";

		render_film_roll_frame($surf)  if $surf;
		return $surf;
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
