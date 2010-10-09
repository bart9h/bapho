package Video;
#{my uses
use strict;
use warnings;
use 5.010;
use Data::Dumper;
use SDL::Surface;
use args qw/%args dbg/;
#}#

sub load_sample_frame
{my ($videofile) = @_;

	my $tmpdir = $args{temp_dir}.'/bapho-videopreview';
	-d $tmpdir or mkdir $tmpdir or die;
	my $framefile = "$tmpdir/00000001.jpg";

	my $cmd = "mplayer -frames 1 -ss 00:00:01 -vo jpeg:maxfiles=1:outdir=\"$tmpdir\" -ao null \"$videofile\"";
	say $cmd if $args{verbose};
	$cmd .= ' >/dev/null 2>/dev/null';
	system $cmd;

	my $surf;
	if (-e $framefile) {
		$surf = SDL::Surface->new(-name => $framefile);
		unlink $framefile or die;
	}
	rmdir $tmpdir or die;

	$surf;
}#

sub play
{my ($videofile) = @_;

	my $cmd = "mplayer \"$videofile\" &";
	say $cmd if dbg;
	system $cmd;
}#

1;
# vim600:fdm=marker:fmr={my,}#:
