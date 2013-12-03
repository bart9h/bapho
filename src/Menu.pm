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

	$self->leave; #reset

	if (scalar @args > 0) {

		$self->{action} = $action;

		$self->{groups} = (ref $args[0])
			? [ @args ]
			: [ { items => [ @args ] } ];

		$self->{items} = [ map { @{$_->{items}} } @{$self->{groups}} ];
	}

}#

sub leave
{my ($self) = @_;

	$self->{action}      = '';
	$self->{item_cursor} = 0;
	$self->{activated}   = undef;
	$self->{groups}      = undef;
	$self->{items}       = undef;
	$self->{text_input}  = [];
	$self->{text_cursor} = 0;
}#

sub do
{my ($self, $command) = @_;

	return 0 unless defined $command;

	# abbreviations
	my $item = $self->{items}->[$self->{item_cursor}];
	my $in = $self->{text_input};

	my $N = scalar @{$self->{items}};
	$self->{activated} = undef;

	given ($command) {
		when (/^([a-z:])$/) {
			push @$in, $command;
			++$self->{text_cursor};
		}
		when (/^(right)$/) {
			++$self->{text_cursor}  if $self->{text_cursor} < scalar @$in;
		}
		when (/^(left)$/) {
			--$self->{text_cursor}  if $self->{text_cursor} > 0;
		}
		when (/^(home)$/) {
			$self->{text_cursor} = 0;
		}
		when (/^(end)$/) {
			$self->{text_cursor} = scalar @$in;
		}
		when (/^(tab)$/) {
			@$in = split //, $item;
			$self->{text_cursor} = scalar @$in;
		}
		when (/^(ctrl-h|backspace)$/) {
			if ($self->{text_cursor} > 0) {
				my $c = ($text->{text_cursor} -= 1);
				@$in = (@$in[0 .. $c-1], @$in[$c+1 .. $#$in]);
			}
		}
		when (/^(down)$/) { $self->{item_cursor}++ }
		when (/^(end)$/) { $self->{item_cursor} = $N - 1 }
		when (/^(q|escape|close)$/) { $self->leave }
		when (/^shift-([a-z0-9])$/) { $self->pvt__jump($1) }
		when (/^(space|enter|return)$/) { $self->{activated} = $item }
		default { return 0 }
	}

	$self->{item_cursor} = 0     if $self->{item_cursor} <  0;
	$self->{item_cursor} = $N-1  if $self->{item_cursor} >= $N;

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
