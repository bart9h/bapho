#!/usr/bin/perl
# vim600:fdm=marker:fmr=#<,#>:

#< use

use strict;
use warnings;
use 5.010;

use Data::Dumper;
use File::Find;
use Image::ExifTool qw(:Public);

#>

my %args = (
#<
		basedir => $ENV{HOME}.'/fotos',
		dir_fmt => '%04d/%02d-%02d',
		jpeg_quality => 80,
		mv => 1,
		verbose => 1,
#>
);

#< import mode

sub x($)
{#<
	my $cmd = shift;
	say $cmd;
	system $cmd  unless $args{nop};
}#>

sub do_mkdir($)
{#<
	-d $_[0]  and return $_[0];
	my $cmd = "mkdir -p \"$_[0]\"";
	$cmd .= ' -v' if $args{verbose};
	x $cmd;
	-d $_[0]  or die "$cmd: $!"  unless $args{nop};
	return $_[0];
}#>

sub exif2path ($)
{#<
	my ($source_file) = @_;

	my ($ext) = $source_file =~ /\.([^.]+)$/;
	unless (defined $ext) {
		warn "no extension in \"$source_file\"";
		return undef;
	}

	my $exif = ImageInfo ($source_file);
	unless (defined $exif->{DateTimeOriginal}) {
		warn "bad exif in \"$source_file\":";
		say Dumper $exif;
		return undef;
	}

	my ($year, $mon, $mday, $hour, $min, $sec) =
		$exif->{DateTimeOriginal}
		=~ /^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$/;

	my $dir = $args{basedir}.'/'.sprintf $args{dir_fmt}, $year, $mon, $mday;
	do_mkdir $dir;

	foreach ('a' .. 'z') {
		my $path = sprintf '%s/%02d%02d%02d%s.%s', $dir, $hour, $min, $sec, $_, lc $ext;
		return $path unless -e $path;
	}
	die;
}#>

sub move_file ($)
{#<
	return if -d $_[0];

	my $path = exif2path ($_[0])  or return;

	# check for duplicated files
	if (-e $path) {
		if (0 == system "cmp \"$_[0]\" \"$path\"") {
			say "skipping $_[0] == $path";
			unlink $_[0];
		}
		else {
			say "WARNING: $_[0] != $path";
		}
		return undef;
	}

	# move the file to it's new place/name
	my $cmd = join ' ', ($args{mv} ? 'mv' : 'cp'), $_[0], $path;
	$cmd .= ' -v'  if $args{verbose};
	if ($args{nop}) {
		say $cmd;
	}
	else {
		x $cmd;
	}

	return $path;
}#>

#>

sub main()
{#<
	if (@ARGV) {
		find ({ no_chdir => 1, wanted => sub { move_file ($_) } }, @ARGV);
	}
}#>
main;

