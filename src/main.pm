package main;
use import;
use picture;

#< use

use strict;
use warnings;
use 5.010;

use Data::Dumper;
use File::Find;
use SDL::App;
use SDL::Constants;
use SDL::Event;
use SDL::Surface;

#>

my %args = (
#<
		basedir => $ENV{HOME}.'/fotos',
		dir_fmt => '%04d/%02d-%02d',
		jpeg_quality => 80,
		mv => 1,
		verbose => 1,
		geometry => '1280x960',
#>
);

sub display ($$)
{#<
	my ($app, $pic) = @_;

	state $bg = SDL::Color->new (-r => 0, -g => 0, -b => 0);
	$app->fill (0, $bg);

	my $surf = $pic->get_surface;
	my $dest = SDL::Rect->new (
		-x => ($app->width-$surf->width)/2,
		-y => ($app->height-$surf->height)/2,
		-width => $surf->width,
		-height => $surf->height,
	);
	$surf->blit (0, $app, $dest);
	$app->update;
}#>

sub load_files()
{#<
	my %pics = ();

	die if $args{dir_fmt} =~ m{\.};

	find (
		{
			no_chdir => 1,
			wanted => sub
			{
				return if -d;
				my $pic = picture::new (\%args, $_);
				$pics{$pic->{key}} = $pic  if $pic;
			},
		},
		$args{basedir}.'/'
	);

	die 'no pictures found'  unless scalar keys %pics;
	return \%pics;
}#>

sub main (@)
{#<
	if (@_) {
		import::import_files (\%args, @_);
		return;
	}

	my $pics = load_files;
	my @keys = sort keys %$pics  or die;
	my $cursor = 0;

	my ($w, $h) = $args{geometry} =~ /(\d+)x(\d+)/ ? ($1, $2) : (0, 0);
	unless ($w) {
		($w, $h) = `xdpyinfo` =~ /\b(\d{2,})x(\d{2,})\b/s ? ($1, $2) : (0, 0);
		for (2 .. 10)
		{#<  fix multi-monitor
			$_ = 12 - $_;
			say;
			if ($w > $_*$h) {
				$w = int ($w/$_);
				last;
			}
		}#>
	}

	my $app = SDL::App->new (
		-title => 'bapho',
		-width => $w,
		-height => $h,
		-fullscreen => 0,
	);

	SDL::Event->set_key_repeat (200, 30);

	display ($app, $pics->{$keys[$cursor]});

	$app->loop({

		SDL_QUIT() => sub { exit(0); },

		SDL_KEYDOWN() => sub
		{#<
			my $e = shift;
			my $k = $e->key_name;
			my $oldcursor = $cursor;

			given ($k) {
				when (/^q$/) { exit(0); }
				when (/^(space|down|right)$/)  { $cursor++; }
				when (/^(backspace|up|left)$/) { $cursor--; }
				default { say "[$k]"; }
			}
			$cursor = $#keys  if $cursor < 0;
			$cursor = 0       if $cursor > $#keys;

			if ($oldcursor != $cursor) {
				display ($app, $pics->{$keys[$cursor]});
				$oldcursor = $cursor;
				$app->sync;
			}
		},#>

	});

}#>

1;
# vim600:fdm=marker:fmr=#<,#>:
