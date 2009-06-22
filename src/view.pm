package view;

#{my uses

use strict;
use warnings;
use 5.010;

#}#

sub new
{my ($collection) = @_;

	bless my $self = {
		collection => $collection,
		cursor     => 0,
		page_first => 0,
		rows       => 1,
		cols       => 1,
		zoom       => 1,
	};

	# sorted array of (the ids of) all pictures
	$self->{ids} = [ sort keys %{$self->{collection}->{pics}} ];

	return $self;
}#

sub pic
{my ($self, $idx) = @_;

	$idx //= $self->{cursor};

	$self->{collection}->{pics}->{$self->{ids}->[$idx]};
}#

sub adjust_page_and_cursor
{my ($self) = @_;

	my $last = (scalar @{$self->{ids}}) - 1;
	my $page_size = $self->{rows}*$self->{cols};

	if ($self->{cursor} < 0) {
		$self->{cursor} = $last;
		$self->{page_first} = $last>=$page_size ? $last-($page_size-1) : 0;
	}
	elsif ($self->{cursor} > $last) {
		$self->{cursor} = $self->{page_first} = 0;
	}
	elsif ($page_size > 1) {
		if (scalar @{$self->{ids}} > $page_size) {
			$self->{page_first} += $page_size
				while $self->{cursor}-$self->{page_first} >= $page_size;

			$self->{page_first} -= $page_size
				while $self->{cursor} < $self->{page_first};

			$self->{page_first} = 0
				if $self->{page_first} < 0;

			my $last_page = (scalar @{$self->{ids}}) - $page_size;
			$self->{page_first} = $last_page
				if $self->{page_first} > $last_page;
		}
	}
	else {
		$self->{page_first} = $self->{cursor};
	}

}#

sub seek_date
{my ($self, $key) = @_;

	our $k = lc $key;
	sub part($$) { substr $_[1]->{id}, 0, {d=>8,m=>6,y=>4}->{$_[0]} }

	my $last = (scalar @{$self->{ids}}) - 1;

	# prevent endless loop
	return if part($k,$self->pic(0)) eq part($k,$self->pic($last));

	# loop to find next pic with different date part
	my $current_pic = $self->pic;
	my $direction = $key =~ /[a-z]/ ? 1 : -1;
	while ($self->{cursor} >= 0  and  $self->{cursor} <= $last) {

		$self->{cursor} += $direction;
		$self->{cursor} = 0      if $self->{cursor} > $last;
		$self->{cursor} = $last  if $self->{cursor} < 0;

		last  if part($k,$self->pic) ne part($k,$current_pic);
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:

