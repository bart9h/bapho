package picture;

#{# use

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use SDL::Surface;

use args qw/%args/;

#}#

sub new ($)
{#
	my $path = shift;

	unless ($path =~ m{$args{basedir}/([^.]+?)\.([^.]+)$}) {
		warn "strange filename ($path)";
		return undef;
	}

	bless {
		key => $1,
		ext => $2,
		path => $path,
		loaded => 0,
		surface => undef,
	};
}#

sub get_dummy_surface
{#
	state $surf;

	unless ($surf) {
		say ':(';
		$surf = SDL::Surface->new (-width => 256, -height => 256);
		$surf->fill (
			SDL::Rect->new (-width => 128, -height => 128, -x => 64, -y => 64),
			SDL::Color->new (-r => 200, -g => 0, -b => 0),
		);
	}

	$surf;
}#

sub get_surface ($)
{#
	my $self = shift;

	unless ($self->{loaded}) {
		say "loading $self->{path}";
		$self->{loaded} = 1;
		eval {
			$self->{surface} = SDL::Surface->new (-name => $self->{path});
		};
		if ($@) {
			$self->{surface} = get_dummy_surface;
		}
	}

	return $self->{surface};
}#

1;
# vim600:fdm=marker:fmr={#,}#:
