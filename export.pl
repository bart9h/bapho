#!/usr/bin/perl
use strict;
use warnings;
use 5.010;

sub getenv { defined $ENV{$_[0]} ? $ENV{$_[0]} : defined $_[1] ? $_[1] : '' }

my $jpeg_quality = getenv('quality', 90);
my $tmp_ppm = '/tmp/bapho-export-tmp.ppm';
my $imagemagic_command = 'convert -verbose '.getenv('IMAGE_MAGIC_OPTIONS').' "%I"[%Wx%H] -quality '.$jpeg_quality; #has no %O, included later
my $ufraw_command = 'rm -f -v '.$tmp_ppm.'; ufraw-batch %I --out-type=ppm --output='.$tmp_ppm;
my $ufraw_defaults = ' --wb=camera --gamma=0.45 --linearity=0.10 --exposure=0 --restore=lch --clip=digital --saturation=1.0 --wavelet-denoising-threshold=0.0 --base-curve=camera --curve=linear --black-point=0.0 --interpolation=ahd --color-smoothing --grayscale=none --lensfun=auto --auto-crop';
my $ufraw_post = ' && convert -verbose '.$tmp_ppm.'[%Wx%H] -quality '.$jpeg_quality.' -sharpen 3x1 "%O"';
my $copy_command = 'cp -v "%I" "%O"';
my $darktable_command = 'darktable-cli --width %W --height %H "%I" "%O"';

my %exts = (
	png   => { priority => 1, command => $imagemagic_command.' "%O"' },
	png   => { priority => 1, command => $imagemagic_command.' "%O"' },
	tif   => { priority => 2, command => $imagemagic_command.' "%O"' },
	ppm   => { priority => 3, command => $imagemagic_command.' -sharpen 3x1 "%O"' }, #-sharpen needs to be before %O
	'cr2.xmp' => { priority => 4, command => $darktable_command },
	'raf.xmp' => { priority => 4, command => $darktable_command },
	ufraw => { priority => 5, command => $ufraw_command.' --conf="%C"'.$ufraw_post },
	cr2   => { priority => 6, command => $ufraw_command.$ufraw_defaults.$ufraw_post },
	raf   => { priority => 6, command => $darktable_command },
	jpg   => { priority => 7, command => $copy_command },
	mov   => { priority => 7, command => $copy_command },
	mpg   => { priority => 7, command => $copy_command },
);

# get arguments from the environment variables
my ($width, $height, $output_dir) = map {
	(defined $ENV{$_} and $ENV{$_} ne '') or die "Error: must pass $_.\n";
	$ENV{$_}
} qw/width height output_dir/;
($width > 0 and $height > 0) or die "Error: must pass positive width and height.\n";

# make sure output_dir exists
mkdir "$output_dir";
-d $output_dir or die "Error: no dir \"$output_dir\".\n";

my @errors;
my $nop = getenv('nop');

# process arguments from stdin
foreach my $arg (<STDIN>) {
	chomp $arg;
	say "Processing \"$arg\"...";

	my $output_file = $arg;
	$output_file =~ s{^.*/([^/]+)\.\w+$}{$output_dir/$1.jpg};
	if (-s $output_file) {
		say "\t\"$output_file\" already exists, skipping.";
		next;
	}

	foreach my $ext (sort { $exts{$a}->{priority} <=> $exts{$b}->{priority} } keys %exts) {

		my $input_file = $arg;
		$input_file =~ s/\.\w+$/\.$ext/;
		say "\tTrying \"$input_file\".";
		if (-e $input_file) {

			my $cmd = $exts{$ext}->{command};
			if ($ext eq 'ufraw') {
				$cmd =~ s/%C/$input_file/;
				if ($input_file =~ /\.ufraw$/) {
					$input_file =~ s/\.ufraw$/\.cr2/;
					unless (-e $input_file) {
						$input_file =~ s/^(.*?\/\d{8}-\d{6}[a-z]).*?(\.cr2)$/$1$2/;
					}
				}
			}
			elsif ($ext eq 'mov' or $ext eq 'mpg') {
				$output_file =~ s/\.jpg$/\.$ext/;
			}
			elsif ($ext =~ /^(cr2|raf)\.xmp$/) {
				$input_file =~ s/\.xmp$//;
			}
			$cmd =~ s/%I/$input_file/;
			$cmd =~ s/%O/$output_file/;
			$cmd =~ s/%W/$width/;
			$cmd =~ s/%H/$height/;

			if ($nop) {
				say "\tNot calling `$cmd'.";
			}
			else {
				say "\tCalling `$cmd'.";
				system $cmd;
				unless (-s $output_file) {
					say "Error: \"$output_file\" was not created.";
					push @errors, $arg;
				}
			}

			last;
		}
	}
}

if (scalar @errors) {
	say "\nERRORS:\n".join("\n", @errors);
}
