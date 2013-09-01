#!/usr/bin/perl
use strict;
use warnings;
use 5.010;

sub getenv { defined $ENV{$_[0]} ? $ENV{$_[0]} : defined $_[1] ? $_[1] : '' }

my $imagemagic_command = 'convert '.getenv('IMAGE_MAGIC_OPTIONS').' %I[%Wx%H] -quality 90';
my $ufraw_command = 'ufraw-batch --out-type=jpeg --compression=90 %I --size=%W --output=%O';
my $ufraw_defaults = '--wb=camera --gamma=0.45 --linearity=0.10 --exposure=0 --restore=lch --clip=digital --saturation=1.0 --wavelet-denoising-threshold=0.0 --base-curve=camera --curve=linear --black-point=0.0 --interpolation=ahd --color-smoothing --grayscale=none --lensfun=auto --auto-crop';
my $copy_command = 'cp -v %I %O';

my %exts = (
	png   => { priority => 1, command => "$imagemagic_command %O" },
	tif   => { priority => 2, command => "$imagemagic_command %O" },
	ppm   => { priority => 3, command => "$imagemagic_command -sharpen 5x2 %O" },
	ufraw => { priority => 4, command => "$ufraw_command --conf=%C" },
	cr2   => { priority => 5, command => "$ufraw_command $ufraw_defaults" },
	jpg   => { priority => 6, command => $copy_command },
	mov   => { priority => 6, command => $copy_command },
	mpg   => { priority => 6, command => $copy_command },
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

sub get_nstars
{my ($file) = @_;

	my $tags_file = $file;
	$tags_file =~ s/\.\w+$/\.tags/;

	if (open F, $tags_file) {
		my %tags = ();
		foreach (<F>) {
			s/^\s*(.*?)\s*$/$1/;
			next if m/^#/;
			next if $_ eq '';
			$tags{$_} = 1;
		}
		close F;

		my $n = 0;
		foreach ('', 1 .. 5) {
			$n = ($_ ? $_ : 1)  if exists $tags{'_star'.$_};
		}
		return $n;
	}

	return 0;
}

my @errors;
my $min_stars = getenv('min_stars');
my $nop = getenv('nop');

# process arguments from stdin
foreach my $arg (<STDIN>) {
	chomp $arg;

	if ($min_stars) {
		next unless get_nstars($arg) >= $min_stars;
	}

	my $output_file = $arg;
	$output_file =~ s{^.*/([^/]+)\.\w+$}{$output_dir/$1.jpg};
	#-e $output_file and die "Error: \"$output_file\" already exists.\n";
	-s $output_file and next;

	foreach my $ext (sort { $exts{$a}->{priority} <=> $exts{$b}->{priority} } keys %exts) {

		my $input_file = $arg;
		$input_file =~ s/\.\w+$/\.$ext/;
		if (-e $input_file) {

			my $cmd = $exts{$ext}->{command};
			given ($ext) {
				when ('ufraw') {
					$cmd =~ s/%C/$input_file/;
					$input_file =~ s/\.ufraw$/\.cr2/;
				}
				when (['mov','mpg']) {
					$output_file =~ s/\.jpg$/\.$ext/;
				}
			}
			$cmd =~ s/%I/$input_file/;
			$cmd =~ s/%O/$output_file/;
			$cmd =~ s/%W/$width/;
			$cmd =~ s/%H/$height/;

			say $cmd;
			unless ($nop) {
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