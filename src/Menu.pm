package Menu;

#{my uses

use strict;
use warnings;
use 5.010;
use Carp;
use Data::Dumper;
use args qw/%args/;

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

		SDL::Events::enable_key_repeat($args{key_repeat_start_delay}, $args{key_repeat_menu_delay});
	}

}#

sub leave
{my ($self) = @_;

	$self->{action}    = '';
	$self->{cursor}    = 0;
	$self->{activated} = undef;
	$self->{groups}    = undef;
	$self->{items}     = undef;
	SDL::Events::enable_key_repeat($args{key_repeat_start_delay}, $args{key_repeat_image_delay});
}#

sub do
{my ($self, $command) = @_;

	return 0  unless defined $command;

	my $N = scalar @{$self->{items}};
	$self->{activated} = undef;

	if    ($command =~ /^(k|up)$/)            { $self->{cursor}-- }
	elsif ($command =~ /^(j|down)$/)          { $self->{cursor}++ }
	elsif ($command =~ /^(g-g|home)$/)        { $self->{cursor} = 0 }
	elsif ($command =~ /^(end)$/)             { $self->{cursor} = $N - 1 }
	elsif ($command =~ /^(q|escape|close)$/) {
		$self->leave;
	}
	elsif ($command =~ /^shift-([a-z0-9])$/) {
		$self->pvt__jump($1);
	}
	elsif ($command =~ /^(l|space|enter|return)$/) {
		$self->{activated} = $self->{items}->[$self->{cursor}];
	}
	else {
		return 0;
	}

	$self->{cursor} = 0     if $self->{cursor} <  0;
	$self->{cursor} = $N-1  if $self->{cursor} >= $N;

	return 1;
}#

sub pvt__jump
{my ($self, $char) = @_;
	caller eq __PACKAGE__  or croak;

	my $i = $self->{cursor};
	for(;;) {
		++$i;
		$i = 0  if $i >= scalar @{$self->{items}};
		return  if $i == $self->{cursor};
		if ($self->{items}->[$i] =~ /^$char/) {
			$self->{cursor} = $i;
			return;
		}
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
