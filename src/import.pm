package import;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use args qw/%args dbg/;

#}#

sub datetime2path
{my ($year, $mon, $mday, $hour, $min, $sec) = @_;

	my $dir = $args{basedir}.'/'.sprintf $args{dir_fmt}, $year, $mon, $mday;

	my $basename = sprintf '%02d%02d%02d-%02d%02d%02d', $year, $mon, $mday, $hour, $min, $sec;

	return ($dir, $basename);
}#

sub exif2path
{my ($source_file) = @_;

	use Image::ExifTool qw(:Public);
	my $exif = ImageInfo($source_file);

	my $date_key;
	foreach (qw/DateTimeOriginal FileModifyDate/) {
		if (defined $exif->{$_}) {
			$date_key = $_;
			last;
		}
	}

	unless (defined $date_key) {
		warn "bad exif in \"$source_file\"".(dbg() ? ($exif->{Error} // Dumper $exif) : '')."\n";
		return undef;
	}

	my ($year, $mon, $mday, $hour, $min, $sec) =
		$exif->{$date_key}
		=~ /^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$/;
	foreach ($year, $mon, $mday) {
		if (not defined $_  or  $_ <= 0) {
			warn "invalid exif date in \"$source_file\"\n";
			warn Dumper $exif  if dbg;
			return undef;
		}
	}

	return datetime2path($year, $mon, $mday, $hour, $min, $sec);
}#

sub filedate2path
{my ($source_file) = @_;

	my @s = stat $source_file;
	my $mtime = $s[9];
	my ($sec,$min,$hour,$mday,$mon,$year) = gmtime $mtime;
	return datetime2path($year+1900, $mon+1, $mday, $hour, $min, $sec);
}#

sub get_target_path
{my ($source_file) = @_;

	#FIXME: $args{quiet}

	$source_file =~ m/$args{basedir}/
		and die "importing file $source_file from inside basedir $args{basedir}";

	my ($ext) = $source_file =~ /\.([^.]+)$/;
	unless (defined $ext) {
		warn "ignoring \"$source_file\": no extension.\n";
		return undef;
	}
	$ext = lc $ext;

	unless (Picture::is_pic_or_vid($source_file)) {
		warn "ignoring \"$source_file\": unregistered extension.\n";
		return undef;
	}

	my ($dir, $basename) = exif2path($source_file);
	unless (defined $dir) {
		($dir, $basename) = filedate2path($source_file);
		defined $dir or return undef;
		print "Use file modification time ($basename)? [Y/n] ";
		my $answer = <STDIN>; chomp $answer;
		return unless $answer eq '' or lc $answer eq 'y';
	}

	my $target_file;
	foreach ('a' .. 'z', 0) {
		$_  or die 'duplicated timestamp overflow';
		$target_file = "$dir/$basename$_.$ext";
		if (!-e $target_file) {
			return $target_file;
		}
		else {
			if (0 == system "cmp \"$source_file\" \"$target_file\"") {
				say "skipping \"$source_file\" == \"$target_file\""  unless $args{quiet};
				system "rm \"$source_file\"".($args{quiet}?'':' -v')  if $args{mv};
				return undef;
			}
		}
	}
}#

sub create_tags_file
{my ($file) = @_;

	return unless defined $file and $args{tags};

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

	$target_file =~ m{^(.*)/[^/]+$} or die;
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
		-e $target_file or die;
	}

	return $target_file;
}#

sub import_files
{my (@files) = @_;

	use File::Find;
	find(
		{
			no_chdir => 1,
			wanted => sub {
				create_tags_file(import_file($_)) unless -d;
			},
		},
		@files
	);
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
		rmdir $dir  or die "files left on $dir/?";
	}
	else {
		die "$cmd failed";
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
