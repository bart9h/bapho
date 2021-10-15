package import;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use Picture;
use args qw/%args dbg/;

#}#

sub guess_path
{my ($source_file) = @_;

	my @rc;
	$rc[0] or @rc = exif2path($source_file);
	$rc[0] or @rc = path2path($source_file);
	$rc[0] or @rc = filedate2path($source_file);
	return @rc;

	sub exif2path
	{my ($source_file) = @_;

		use Image::ExifTool qw(:Public);
		my $exif = ImageInfo($source_file);

		my $date_key;
		foreach (qw/DateTimeOriginal MediaCreateDate/) {
			if (defined $exif->{$_}) {
				$date_key = $_;
				last;
			}
		}

		unless (defined $date_key) {
			warn "Bad exif in \"$source_file\"".(dbg() ? ($exif->{Error} // Dumper $exif) : '')."\n";
			return undef;
		}

		my ($year, $mon, $mday, $hour, $min, $sec) =
			$exif->{$date_key}
			=~ /^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$/;
		foreach ($year, $mon, $mday) {
			if (not defined $_  or  $_ <= 0) {
				warn "Invalid exif date in \"$source_file\".\n";
				warn Dumper $exif  if dbg;
				return undef;
			}
		}

		return datetime2path($year, $mon, $mday, $hour, $min, $sec);
	}#

	sub path2path
	{my ($source_file) = @_;

		$source_file =~ m{/([^./]+)_(\d\d\d\d)(\d\d)(\d\d)_(\d\d)(\d\d)(\d\d)(-\d|\d*|_LL|[a-z]|_\d+)\.([^./]+)$}
			or
		$source_file =~ m{/([^./]+)-(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\d*\.([^./]+)$}
			or
		return undef;

		my $basename = $1;
		my $dir = datetime2path($2, $3, $4, $5, $6, $7);
		return ($dir, $basename);
	}#

	sub filedate2path
	{my ($source_file) = @_;

		my @s = stat $source_file;
		my $mtime = $s[9];
		my ($sec,$min,$hour,$mday,$mon,$year) = gmtime $mtime;
		my ($dir, $basename) = datetime2path($year+1900, $mon+1, $mday, $hour, $min, $sec)
			or return undef;

		print "Use file modification time ($basename)? [Y/n] ";
		my $answer = <STDIN>; chomp $answer;
		return undef  unless $answer eq '' or lc $answer eq 'y';
	}#

	sub datetime2path
	{my ($year, $mon, $mday, $hour, $min, $sec) = @_;
		foreach (@_) { return undef  unless defined }

		my $dir = $args{basedir}.'/'.sprintf $args{dir_fmt}, $year, $mon, $mday;

		my $basename = sprintf '%02d%02d%02d-%02d%02d%02d', $year, $mon, $mday, $hour, $min, $sec;

		return ($dir, $basename);
	}#

}#

sub get_target_path
{my ($source_file) = @_;

	#FIXME: $args{quiet}

	$source_file =~ m/$args{basedir}/
		and die "Importing file \"$source_file\" from inside basedir \"$args{basedir}\".\n";

	my ($ext) = $source_file =~ /\.([^.]+)$/;
	unless (defined $ext) {
		warn "Ignoring \"$source_file\": no extension.\n";
		return undef;
	}
	$ext = lc $ext;

	unless (Picture::is_pic_or_vid($source_file) or $ext =~ m/^(xmp|tags)$/) {
		warn "ignoring \"$source_file\": unregistered extension.\n";
		return undef;
	}

	my ($dir, $basename) = guess_path($source_file);
	unless ($dir and $basename) {
		warn "Couldn't guess destination path for \"$source_file\".\n";
		return undef;
	}

	sub skiprm {
		return 0  unless (-e $_[0] && -e $_[1]);
		return 0  unless (-s $_[0] == -s $_[1]);
		if (0 == system "cmp \"$_[0]\" \"$_[1]\"") {
			say "skipping \"$_[0]\" == \"$_[1]\""  unless $args{quiet};
			system "rm \"$_[0]\" -f".($args{quiet}?'':' -v')  if $args{mv};
			return 1;
		}
	}

	#TODO: skip jpg if equivalent cr2 was skipped
	my $base = "$basename*.$ext*";
	foreach my $target_file (glob("$dir*/$base"), glob("$dir*/.bapho-trash/$base")) {
		return undef  if skiprm($source_file, $target_file);
	}

	foreach my $append_char ('a' .. 'z', undef) {
		$append_char  or die 'Duplicated timestamp overflow!';
		my $file = "$dir/$basename$append_char.$ext";
		return $file  unless -e $file;
	}
}#

sub create_tags_file
{my ($file) = @_;

	return  unless defined $file and $args{tags};

	my $tags = Tags->new(
		PictureItr::path2id($file)
	);

	$tags->add($_)
		foreach split /,/, $args{tags};
}#

sub import_file
{my ($source_file) = @_; # returns target file path or undef

	my $target_file = get_target_path($source_file)
		or return undef;

	$target_file =~ m{^(.*)/[^/]+$}  or die;
	my $dir = $1;

	# move the file target_file to it's new place/name
	my $v = $args{quiet} ? '' : 'v';
	my $cmd = join ' && ',(
		-d $dir ? () : "mkdir -p$v \"$dir\"",
		($args{mv} ? 'mv' : 'cp')." -i$v \"$source_file\" \"$target_file\"",
		"chmod 444 \"$target_file\"",
	);
	if ($args{nop}) {
		say $cmd;
	}
	elsif (0 == system $cmd) {
		-e $target_file  or die;
	}

	return $target_file;
}#

sub import_files
{my (@files) = @_;

	use File::Find;

	my %imported_files;
	find(
		{
			no_chdir => 1,
			wanted => sub {
				unless (-d) {
					my $path = import_file($_);
					if ($path) {
						create_tags_file($path);
						$imported_files{$path} = 1;
					}
				}
			},
		},
		@files
	);

	foreach my $path (keys %imported_files) {
		$path =~ m{^(?<base>.+?)\.(?<ext>[^.]+)$}  or next;

		# Mark .jpg as writeable (or remove it) if there's an equivalent raw file.
		if ($+{ext} eq 'jpg') {
			my $has_raw = 0;
			foreach (qw/.cr2 .raf/) {
				if (exists $imported_files{$+{base}.$_}) {
					$has_raw = 1;
					last;
				}
			}
			if ($has_raw) {
				if ($args{ignore_extra_jpg}) {
					say "removing extra $path";
					unlink $path;
				}
				else {
					chmod 0644, $path;
				}
			}
		}

		# Mark all .xmp files as writeable.
		if ($+{ext} eq 'xmp') {
			chmod 0644, $path;
		}
	}

	1;
}#

sub import_gphoto2
{#{my}

	my $dir = "$args{temp_dir}/bapho-gphoto2";
	my $cmd = join '; ', ("set -e",
		"test -d \"$dir\" || mkdir -v \"$dir\"",
		"cd \"$dir\"",
		"sudo gphoto2 -P",
		"sudo chown $ENV{USER} *",
	);

	if (0 == system $cmd) {
		import_files $dir;
		rmdir $dir  or die "Files left on $dir/?";
	}
	else {
		die "The command <<<\n\t$cmd\n>>> failed.\n\nWe need sudo and gphoto2 working.\n";
	}
}#

sub import_any
{my ($files_ref) = @_;

	if (defined $files_ref and scalar @$files_ref) {
		import_files(@$files_ref);
	}
	else {
		import_gphoto2;
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
