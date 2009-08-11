package view;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

#}#

sub new
{my ($collection, $ins, $outs) = @_;

	bless my $self = {
		collection => $collection,
		ins        => $ins,
		outs       => $outs,
		ids        => [], # will be filled in $self->update
		cursor     => 0,
		page_first => 0,
		rows       => 1,
		cols       => 1,
		zoom       => 1,
	};

	$self->update;

	return $self;
}#

sub update
{my ($self) = @_;

	sub filter
	{my ($tags, $ins, $outs) = @_;
		foreach (@$ins) {
			return 0 unless $tags->{$_};
		}
		foreach (@$outs) {
			return 0 if $tags->{$_};
		}
		1;
	}#

	# sorted array of (the ids of) filtered pictures
	my $pics = $self->{collection}->{pics};
	$self->{ids} = [
		sort grep {
			filter($pics->{$_}->{tags}, $self->{ins}, $self->{outs})
		} keys %$pics
	];
}#

sub pic
{my ($self, $idx) = @_;

	$idx //= $self->{cursor};

	$self->{collection}->{pics}->{$self->{ids}->[$idx]};
}#

sub delete_current
{my ($self) = @_;

	$self->{collection}->delete($self->pic);

	$self->update;
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

	$key =~ m/(shift-)?([a-z])/;
	my ($shift, $k) = ($1, $2);

	sub part($$) { substr $_[1]->{id}, 0, {d=>8,m=>6,y=>4}->{$_[0]} }

	my $last = (scalar @{$self->{ids}}) - 1;

	# prevent endless loop
	return if part($k,$self->pic(0)) eq part($k,$self->pic($last));

	# loop to find next pic with different date part
	my $current_pic = $self->pic;
	my $direction = $shift ? -1 : 1;
	while ($self->{cursor} >= 0  and  $self->{cursor} <= $last) {

		$self->{cursor} += $direction;
		$self->{cursor} = 0      if $self->{cursor} > $last;
		$self->{cursor} = $last  if $self->{cursor} < 0;

		last  if part($k,$self->pic) ne part($k,$current_pic);
	}
}#

sub seek_id
{my ($self, $id) = @_;

	my $idx = 0;
	foreach (@{$self->{ids}}) {
		if ($_ eq $id) {
			$self->{cursor} = $idx;
			last;
		}
		$idx++;
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
