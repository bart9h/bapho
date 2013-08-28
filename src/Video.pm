package Video;
#{my uses
use strict;
use warnings;
use 5.010;
use Data::Dumper;
use SDL::Surface;
use args qw/%args dbg/;
#}#

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

sub load_sample_frame
{my ($videofile) = @_;

	my $tmpdir = $args{temp_dir}.'/bapho-videopreview';
	-d $tmpdir or mkdir $tmpdir or die "$tmpdir: $!";
	my $framefile = "$tmpdir/00000001.jpg";

	my $cmd = "mplayer -frames 1 -ss 00:00:01 -vo jpeg:maxfiles=1:outdir=\"$tmpdir\" -ao null \"$videofile\"";
	say $cmd if dbg 'cmd,video,file';
	$cmd .= ' >/dev/null 2>/dev/null';
	system $cmd;

	my $surf;
	$surf = SDL::Image::load($framefile)  if -e $framefile;

	system "rm -rf \"$tmpdir\"";

	render_film_roll_frame($surf) if $surf;
	$surf;
}#

sub play
{my ($videofile) = @_;

	my $cmd = join ' ',
		'mplayer',
		$args{fullscreen} ? ('-fs') : (),
		"\"$videofile\"",
		'&';
	say $cmd if dbg;
	system $cmd;
}#

1;
# vim600:fdm=marker:fmr={my,}#:
