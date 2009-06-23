package menu;

use strict;
use warnings;
use 5.010;

sub new
{#{my}

	bless my $self = {};
	$self->leave;
	return $self;
}#

sub enter ($$$)
{my ($self, $action, $items) = @_;

	$self->{action}   = $action;
	$self->{items}    = $items;
	$self->{cursor}   = 0;
	$self->{selected} = undef;
}#

sub leave ($)
{my ($self) = @_;

	$self->{action}   = '';
	$self->{items}    = [];
	$self->{cursor}   = 0;
	$self->{selected} = undef;
}#

sub do ($)
{my ($self, $command) = @_;

	return unless defined $command;

	my $N = scalar @{$self->{items}};

	$self->{selected} = undef;
	my $rc = 1;
	given ($command) {
		when (/^up$/)           { $self->{cursor}-- }
		when (/^down$/)         { $self->{cursor}++ }
		when (/^home$/)         { $self->{cursor} = 0 }
		when (/^end$/)          { $self->{cursor} = $N - 1 }
		when (/^quit$/)         { $self->leave }
		when (/^(page down|enter|return)$/) {
			$self->{selected} = $self->{items}->[$self->{cursor}];
		}
		default {
			$rc = 0;
		}
	}

	$self->{cursor} = 0     if $self->{cursor} <  0;
	$self->{cursor} = $N-1  if $self->{cursor} >= $N;

	return $rc;
}#

1;
# vim600:fdm=marker:fmr={my,}#:
