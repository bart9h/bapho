package Menu;

#{my uses

use strict;
use warnings;
use 5.010;
use Carp;
use Data::Dumper;

#}#

sub new
{#{my}

	bless my $self = {};
	$self->leave;
	return $self;
}#

sub enter
{my ($self, $action, @args) = @_;

	if (scalar @args == 0) {
		$self->leave;
	}
	else {
		$self->{action} = $action;
		$self->{cursor} = 0;
		$self->{activated} = undef;

		$self->{groups} = (ref $args[0])
			? [ @args ]
			: [ { items => [ @args ] } ];

		$self->{items} = [ map { @{$_->{items}} } @{$self->{groups}} ];
	}

}#

sub leave
{my ($self) = @_;

	$self->{action}    = '';
	$self->{cursor}    = 0;
	$self->{activated} = undef;
	$self->{groups}    = undef;
	$self->{items}     = undef;
}#

sub do
{my ($self, $command) = @_;

	return 0 unless defined $command;

	my $N = scalar @{$self->{items}};
	$self->{activated} = undef;

	given ($command) {
		when (/^(k|up)$/)            { $self->{cursor}-- }
		when (/^(j|down)$/)          { $self->{cursor}++ }
		when (/^(g-g|home)$/)        { $self->{cursor} = 0 }
		when (/^(end)$/)             { $self->{cursor} = $N - 1 }
		when (/^(q|escape|close)$/)  { $self->leave }
		when (/^shift-([a-z0-9])$/)  { $self->pvt__jump($1) }
		when (/^(l|space|enter|return)$/) {
			$self->{activated} = $self->{items}->[$self->{cursor}];
		}
		default {
			return 0;
		}
	}

	$self->{cursor} = 0     if $self->{cursor} <  0;
	$self->{cursor} = $N-1  if $self->{cursor} >= $N;

	return 1;
}#

sub pvt__jump
{my ($self, $char) = @_;
	caller eq __PACKAGE__ or croak;

	my $i = $self->{cursor};
	for(;;) {
		++$i;
		$i = 0 if $i >= scalar @{$self->{items}};
		return if $i == $self->{cursor};
		if ($self->{items}->[$i] =~ /^$char/) {
			$self->{cursor} = $i;
			return;
		}
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
