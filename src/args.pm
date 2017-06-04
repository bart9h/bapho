package args;

#{# uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use base 'Exporter';
our @EXPORT = qw(%args dbg min max);

#}#

my @raw_extensions = qw/cr2 raf/;

our %args = (
		baphorc => $ENV{HOME}.'/.baphorc', #TODO: xdg?
		basedir => $ENV{HOME}.'/Pictures', #TODO: xdg?
		editor => $ENV{EDITOR} // 'gedit',
		temp_dir => '/tmp',
		dir_fmt => '%04d/%02d/%02d',
		jpeg_quality => 80,
		mv => 0,
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
		raw_extensions => [ @raw_extensions ],
		pic_extensions => [ qw/jpeg jpg tiff tif png/, @raw_extensions ],
		vid_extensions => [ qw/mpeg mpg avi mkv mp4 m4v mov flv 3gp/ ],
		key_repeat_start_delay => 200,
		key_repeat_menu_delay => 25,
		key_repeat_image_delay => 200,
		exif_tags => [
		#{#
			{ tag => 'DateTimeOriginal',     label => '   date/time', em => 0 },
			{ tag => 'Model',                label => '      camera', em => 1 },
			{ tag => 'LensID',               label => '        lens', em => 1 },
			{ tag => 'Aperture',             label => '    aperture', em => 1 },
			{ tag => 'ShutterSpeed',         label => '       speed', em => 1 },
			{ tag => 'ISO',                  label => '         iso', em => 1 },
			{ tag => 'FocalLength',          label => 'focal length', em => 1 },
			{ tag => 'ExposureProgram',      label => '    exposure', em => 0 },
			{ tag => 'ExposureCompensation', label => '          ev', em => 0 },
			{ tag => 'FocusMode',            label => '       focus', em => 0 },
			{ tag => 'Flash',                label => '       flash', em => 0 },
		#}#
		],
);

sub dbg
{#
	my ($tags) = @_;

	return 0  unless defined $args{verbose};
	return 1  unless $tags;
	return 1  if $args{verbose} eq 'all';
	foreach my $a (split /,/, $args{verbose}) {
	foreach my $b (split /,/, $tags) {
		return 1  if $a eq $b
	}}
	0;
}#

sub state_filename  { $args{basedir}.'/.bapho-state' }
sub config_filename { $ENV{HOME}.'/.baphorc' }

sub read_args
{# read ~/.baphorc, environment and cmdline parameters into %args

	# for dbg to work here, before we process the args
	$args{verbose} = ''  if grep { /^(-v|--verbose)$/ } @_;

	sub add_arg
	{#
		say "add_arg($_[0])"  if dbg;
		if ($_[0] =~ m/^(..*?)(=(.*))?$/) {
			my ($arg, $has_val, $val) = ($1, $2, $3);
			$arg =~ s/-/_/g;
			if (exists $args{$arg}) {
				$args{$arg} = $has_val ? $val : 1;
				say "add_arg($arg,$args{$arg})"  if dbg;
			}
			else {
				say STDERR "unknown arg ($_)";
				exit 1;
			}
		}
	}#

	{# ~/.baphorc

		if (open F, '<', config_filename) {
			say 'BEGIN('.config_filename.')'  if dbg;
			while (<F>) {
				chomp;
				next if /^\s*#/;  # skip comments
				add_arg($_);
			}
			close F;
			say 'END('.config_filename.')'  if dbg;
		}
		else {
			printf STDERR "%s: $!\n", config_filename;
		}
	}#

	{# environment

		foreach (keys %ENV) {
			/^BAPHO_(\w+)$/i  or next;
			my ($arg, $val) = (lc $1, $ENV{$_});
			$args{$arg} = $val;
			say "env($arg,$val)"  if dbg;
		}
	}#

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
					next  if ref $val;
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

	foreach (sort keys %$h) {
		print F "$_=$h->{$_}\n";
	}

	close F;
}#

sub load_state
{#
	my $file = state_filename;
	say "Loading state file $file."  if dbg 'file';

	unless (open F, $file) {
		printf "%s: $!\n", $file;
		return;
	}

	while (<F>) {
		chomp;
		/^([^=]+)=(.*)$/  or die "Corrupt state file $file.";
		$args{$1} = $2;
	}

	close F;
}#

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

1;
# vim600:fdm=marker:fmr={#,}#:
