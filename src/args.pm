package args;

#{# uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use base 'Exporter';
our @EXPORT = qw(%args dbg min max);

#}#

our %args = (
		basedir => $ENV{HOME}.'/fotos',
		editor => $ENV{EDITOR} // 'gedit',
		temp_dir => '/tmp',
		dir_fmt => '%04d/%02d/%02d',
		jpeg_quality => 80,
		mv => 1,
		include => '',
		exclude => '',
		verbose => undef,
		geometry => undef,
		fullscreen => undef,
		nop => undef,
		import => undef,
		cache_size_mb => undef,
		pic_extensions => [ qw/jpg tif png cr2/ ],
		vid_extensions => [ qw/mpg avi mkv mp4 flv/ ],
		exif_tags => [
		#{#
			qw/
				Model
				LensID
				ISO
				ShutterSpeed
				Aperture
				FocalLength
				Flash
				FocusMode
				ColorTemperature
				WhiteBalance
				ExposureCompensation
				Sharpness
				Orientation
				UserComment
			/
		#}#
		],
);

sub dbg
{#
	my ($tags) = @_;

	return 0 unless defined $args{verbose};
	return 1 unless $tags;
	return 1 if $args{verbose} eq 'all';
	foreach my $a (split /,/, $args{verbose}) {
	foreach my $b (split /,/, $tags) {
		return 1 if $a eq $b
	}}
	0;
}#

sub state_filename
{#
	$args{basedir}.'/.bapho-state';
}#

sub read_args
{# read cmdline parameters into %args

	foreach (keys %ENV) {
		/^BAPHO_(\w+)$/ or next;
		$args{lc $1} = $ENV{$_};
	}

	my $process_args = 1;
	foreach (@_) {
		if ($process_args) {

			if (my $alias = {
					'-f' => '--fullscreen',
					'-h' => '--help',
					'-v' => '--verbose',
				}->{$_})
			{
				$_ = $alias;
			}

			if (/^--$/) {
				$process_args = 0;
				next;
			}
			elsif ($_ eq '--help') {
				#{#
				#TODO: better %args, to contain description
				#      (borrow from other script I wrote..)
				say 'arguments and their defaults (if any):';
				foreach (sort keys %args) {
					my $val = $args{$_};
					next if ref $val;
					s/_/-/g;
					say '--'.$_.(defined $val ? "=$val" : '');
				}
				exit 0;
				#}#
			}
			elsif (m/^--(..*?)(=(.*))?$/) {
				my ($arg, $has_val, $val) = ($1, $2, $3);
				$arg =~ s/-/_/g;
				if (exists $args{$arg}) {
					$args{$arg} = $has_val ? $val : 1;
					next;
				}
				else {
					say STDERR "unknown arg ($_)";
					exit 1;
				}
			}
		}

		$args{files} = []  if not exists $args{files};
		push @{$args{files}}, $_;
	}
	1;
}#

sub save_state
{#
	my ($h) = @_;

	unless (open F, '>', state_filename) {
		printf ">%s: $!\n", state_filename;
		return;
	}

	foreach (keys %$h) {
		print F "$_=$h->{$_}\n";
	}

	close F;
}#

sub load_state
{#
	say "loading state file ".state_filename if dbg 'file';

	unless (open F, state_filename) {
		printf "<%s: $!\n", state_filename;
		return;
	}

	while (<F>) {
		chomp;
		/^([^=]+)=(.*)$/ or die;
		$args{$1} = $2;
	}

	close F;
}#

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

1;
# vim600:fdm=marker:fmr={#,}#:
