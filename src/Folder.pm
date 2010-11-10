package Folder;
use strict;
use warnings;
use v5.10;
use Data::Dumper;
use SDL::Surface;

sub render_surf
{my ($path, $width, $height, $factory) = @_;

	my $surf = SDL::Surface->new(-width => $width, -height => $height)->display_format;
	my $b = 12;

	folder_frame($surf, $b);

	my @files = sample_files($path);
print Dumper $path, \@files;
	my ($w, $h) = (scalar @files == 1)
		? ($width-4*$b, $height-5*$b)
		: (($width-5*$b)/2, ($height-6*$b)/2);

	my @sample_surfs = map {
		$factory->get($_, $w, $h)
	} @files;

	for my $j (0 .. 1) {
	for my $i (0 .. 1) {
		my $sample_surf = shift @sample_surfs;
		defined $sample_surf and defined $sample_surf->{surf} or last;
		my ($x, $y) = (2*$b+$i*($w+$b), 3*$b+$j*($h+$b));
		#print Dumper "i($i), j($j), w($w), h($h), x($x), y($y)", $sample_surf;
		$sample_surf->{surf}->blit(0, $surf, SDL::Rect->new(-width=>$w, -height=>$h, -x=>$x, -y=>$y));
	}}

	return $surf;
}#

sub sample_files
{my ($path) = @_;

	my $itr = PictureItr->new($path);
	$itr->down or return ();

	my @files = ();
	for(;;) {
		push @files, $itr->{pic}->{sel};
		$itr->seek('+1') or last;
	}

	my @sorted = sort {
		$a cmp $b  #TODO
	} @files;

	grep {$_} @sorted[0..3];
}#

sub folder_frame
{my ($surf, $b) = @_;

	state $color = new SDL::Color ( -r => 220, -g => 180, -b => 100 );
	my $tab2 = 4;

	$surf->fill(
		SDL::Rect->new(
			-width => $surf->width-2*$b,
			-height => $surf->height-2*$b,
			-x => $b,
			-y => $b),
		$color
	);

	$surf->fill(
		SDL::Rect->new(
			-width => $tab2*$b,
			-height => $b,
			-x => $b,
			-y => $b
		),
		$SDL::Color::black
	);

	my $x = $b+4*$tab2*$b;
	$surf->fill(
		SDL::Rect->new(
			-width => $surf->width-$x,
			-height => $b,
			-x => $x,
			-y => $b),
		$SDL::Color::black
	);

}#

1;
# vim600:fdm=marker:fmr={my,}#:
