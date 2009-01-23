package picture;

#< use

use strict;
use warnings;
use 5.010;

use Data::Dumper;
use SDL::Surface;

#>

my $args;

sub new ($$)
{#<
	$args = shift;
	my $path = shift;

	unless ($path =~ m|$args->{basedir}/([^.]+?)\.\w+$|) {
		warn "strange filename ($path)";
		return undef;
	}

	bless {
		key => $1,
		path => $path,
		loaded => 0,
		surface => undef,
	};
}#>

sub surface ($)
{#<
	my $self = shift;

	unless ($self->{loaded}) {
		say "loading $self->{path}";
		$self->{loaded} = 1;
		$self->{surface} = SDL::Surface->new (-name => $self->{path});
	}

	return $self->{surface};
}#>

1;
# vim600:fdm=marker:fmr=#<,#>:
