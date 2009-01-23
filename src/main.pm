package main;
use import;

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
#>
);

sub display ($$)
{#<
	my ($app, $pic) = @_;

	unless ($pic->{loaded}) {
		say "loading $pic->{path}";
		$pic->{loaded} = 1;
		$pic->{surface} = SDL::Surface->new (-name => $pic->{path});
	}

	if ($pic->{surface}) {
		$pic->{surface}->blit (0, $app, 0);
	}

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

sub main (@)
{#<
	if (@_) {
		import::import_files (\%args, @_);
		return;
	}

	my $pics = load_files;
	my @keys = sort keys %$pics  or die;
	my $cursor = 0;

	my $app = SDL::App->new (
		-title => 'bapho',
	);

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
			$cursor = 0       if $cursor < 0;
			$cursor = $#keys  if $cursor > $#keys;

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
