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
		baphorc => $ENV{HOME}.'/.baphorc', #TODO: xdg?
		basedir => $ENV{HOME}.'/Pictures', #TODO: xdg?
		editor => $ENV{EDITOR} // 'gedit',
		temp_dir => '/tmp',
		dir_fmt => '%04d/%02d/%02d',
		jpeg_quality => 80,
		mv => 1,
		include => '',
		exclude => '_hidden',
		tags => '',
		verbose => undef,
		geometry => undef,
		fullscreen => undef,
		nop => undef,
		import => undef,
		print => undef,
		cache_size_mb => undef,
		pic_extensions => [ qw/jpeg jpg tiff tif png cr2/ ],
		vid_extensions => [ qw/mpeg mpg avi mkv mp4 m4v mov flv 3gp/ ],
		exif_tags => [
		#{#
			qw/
				DateTimeOriginal
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

sub state_filename  { $args{basedir}.'/.bapho-state' }
sub config_filename { $ENV{HOME}.'/.baphorc' }

sub read_args
{# read ~/.baphorc, environment and cmdline parameters into %args

	sub add_arg
	{#
		if ($_[0] =~ m/^(..*?)(=(.*))?$/) {
			my ($arg, $has_val, $val) = ($1, $2, $3);
			$arg =~ s/-/_/g;
			if (exists $args{$arg}) {
				$args{$arg} = $has_val ? $val : 1;
			}
			else {
				say STDERR "unknown arg ($_)";
				exit 1;
			}
		}
	}#

	{# ~/.baphorc

		if (open F, '<', config_filename) {
			while (<F>) {
				add_arg($_);
			}
			close F;
		}
		else {
			print STDERR "%s: $!\n", config_filename;
		}
	}#

	foreach (keys %ENV) {
		/^BAPHO_(\w+)$/ or next;
		$args{lc $1} = $ENV{$_};
	}

	{# cmdline

	my $process_args = 1;
	my %default_args = %args;  # so --help won't display modified args
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
				say 'Arguments and their defaults (if any):';
				foreach (sort keys %default_args) {
					my $val = $default_args{$_};
					next if ref $val;
					s/_/-/g;
					say '--'.$_.(defined $val ? "=$val" : '');
				}

				my %tags;
				if (opendir(my $dh, $ENV{BAPHO_LIBDIR})) {
					map { ++$tags{$_} }
					map { split /,/ }
					map { m{\bdbg\s+'([^']+)'}msg }
					map { do {local(@ARGV,$/)=$_;<>} } # slurp
					map { "$ENV{BAPHO_LIBDIR}/$_" } grep { /\.pm$/ } readdir $dh;
					closedir $dh;
				}
				say "Tags for the verbose flag:";
				say join(',', 'all', sort keys %tags);

				exit 0;
				#}#
			}
			elsif (m/^--(.*)$/) {
				add_arg($1);
				next;
			}
		}

		$args{files} = []  if not exists $args{files};
		push @{$args{files}}, $_;
	}

	}#

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
	my $file = state_filename;
	say "Loading state file $file." if dbg 'file';

	unless (open F, $file) {
		printf "<%s: $!\n", $file;
		return;
	}

	while (<F>) {
		chomp;
		/^([^=]+)=(.*)$/ or die "Corrupt state file $file.";
		$args{$1} = $2;
	}

	close F;
}#

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

1;
# vim600:fdm=marker:fmr={#,}#:
