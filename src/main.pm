package main;

#< use

use strict;
use warnings;
use 5.010;

use Data::Dumper;
use File::Find;
use Image::ExifTool qw(:Public);
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
#>
);

#< GUI mode

sub display ($$)
{#<
	my ($app, $pic) = @_;

	print Dumper $pic;

	unless ($pic->{loaded}) {
		say "loading $pic->{path}";
		$pic->{loaded} = 1;
		$pic->{surface} = SDL::Surface->new (-name => $pic->{path});
	}

	if ($pic->{surface}) {
		$pic->{surface}->blit (0, $app, 0);
	}

}#>

sub gui ($)
{#<

	my $pics = shift;
	my @keys = sort keys %$pics  or die;
	my $cursor = 0;

	my $app = SDL::App->new (
		-title => 'bapho',
	);

	display ($app, $pics->{$keys[$cursor]});

	$app->loop(
	{#<

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
			$cursor = 0       if $cursor < 0;
			$cursor = $#keys  if $cursor > $#keys;

			if ($oldcursor != $cursor) {
				display ($app, $pics->{$keys[$cursor]});
				$oldcursor = $cursor;
				$app->sync;
			}
		},#>

	}#>
	);

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
				my $_ = $File::Find::name;
				return if -d;
				unless (m|$args{basedir}/([^.]+?)\.\w+$|) {
					warn "strange filename ($_)";
					return;
				}

				$pics{$1} = {
					path => $_,
				};
			},
		},
		$args{basedir}.'/'
	);

	die 'no pictures found'  unless scalar keys %pics;
	return \%pics;
}#>

#>

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

sub main (@)
{#<
	if (@_) {
		find ({ no_chdir => 1, wanted => sub { move_file ($_) } }, @_);
	}
	else {
		gui (load_files);
	}
}#>

# vim600:fdm=marker:fmr=#<,#>:
