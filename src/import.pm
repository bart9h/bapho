package import;

#{# use

use strict;
use warnings;
use 5.010;

use Data::Dumper;

use args qw/%args/;

#}#

sub exif2path ($)
{#
	my ($source_file) = @_;

	my ($ext) = $source_file =~ /\.([^.]+)$/;
	unless (defined $ext) {
		warn "no extension in \"$source_file\"";
		return undef;
	}

	use Image::ExifTool qw(:Public);
	my $exif = ImageInfo ($source_file);

	my $date_key;
	foreach (qw/DateTimeOriginal FileModifyDate/) {
		if (defined $exif->{$_}) {
			$date_key = $_;
			last;
		}
	}

	unless (defined $date_key) {
		warn "bad exif in \"$source_file\"".($args{verbose} ? ($exif->{Error} // Dumper $exif) : '');
		return undef;
	}

	my ($year, $mon, $mday, $hour, $min, $sec) =
		$exif->{$date_key}
		=~ /^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$/;

	my $dir = $args{basedir}.'/'.sprintf $args{dir_fmt}, $year, $mon, $mday;
	my $basename = sprintf '%02d%02d%02d-%02d%02d%02d', $year, $mon, $mday, $hour, $min, $sec;
	return ($dir, $basename, lc $ext);
}#

sub import_file ($)
{#
	my $source_file = shift;

	my ($dir, $basename, $ext) = exif2path ($source_file)  or return undef;

	my $target_file;
	foreach ('a' .. 'z', 0) {
		$_ or die 'duplicated timestamp overflow';
		$target_file = "$dir/$basename$_.$ext";
		if (!-e $target_file) {
			last;
		}
		else {
			if (0 == system "cmp \"$source_file\" \"$target_file\"") {
				say "skipping \"$source_file\" == \"$target_file\""  unless $args{quiet};
				system "rm \"$source_file\"".($args{quiet}?'':' -v')  if $args{mv};
				return $target_file;
			}
		}
	}

	# move the file target_file it's new place/name
	my $v = $args{quiet} ? '' : ' -v';
	my $cmd =
			(-d $dir ? '' : "mkdir -p$v \"$dir\" && ").
			($args{mv} ? 'mv' : 'cp')."$v \"$source_file\" \"$target_file\"".
			" && chmod 444 \"$target_file\"";
	if ($args{nop}) {
		say $cmd;
	}
	elsif (0 == system $cmd) {
		-e $target_file or die;
	}
}#

sub import_files (@)
{#
	use File::Find;
	find (
		{
			no_chdir => 1,
			wanted => sub { import_file ($_) unless -d },
		},
		@_
	);
}#

1;
# vim600:fdm=marker:fmr={#,}#:
