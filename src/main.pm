package main;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use Tags;
use args qw/%args dbg/;

#}#

sub quit
{my ($self) = @_;

	$self->save_state  if $self->{jaildir} eq $args{basedir};
	exit(0);
}#

sub new
{#{my constructor}

}#

sub main
{my @arghs = @_;

	args::read_args(@arghs);

	Tags::init();

	sub fixlink { -l $_[0] ? readlink $_[0] : $_[0] }

	$args{basedir} = fixlink $args{basedir};
	-d $args{basedir}  or die "$args{basedir} not found.\n";

	if (exists $args{files}) {
		die "only one startdir is currently supported\n"  if scalar @{$args{files}} != 1;
		my $dir = $args{files}->[0];
		unless ($dir =~ m{^/}) {
			my $pwd = `pwd`; chomp $pwd;
			$dir = $pwd."/$dir";
		}
		$args{startdir} = fixlink $dir;
	}

	my $jaildir = defined $args{startdir}
		? $args{startdir} =~ m|^$args{basedir}/|
			? $args{basedir}
			: $args{startdir}
		: $args{basedir};


	if ($args{import}) {
		use import;
		exit(import::import_any($args{files}) ? 0 : 1);
	}
	elsif ($args{print}) {
		die "not implemented\n";
=a
		$view->seek('first');
		while(1) {
			my $path = $view->pic->{sel};
			say $path;
			$view->seek('+1');
			last  if $path eq $view->pic->{sel};
		}
		exit(0);
=cut
	}
	else {
		require gui;
		import gui;
		gui::loop();
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
