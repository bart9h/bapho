package view;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use PictureItr;

#}#

sub new
{my ($pic, $ins, $outs) = @_;
	$pic or die;

	bless my $self = {
		pic        => $pic,
		count      => 1,
		ins        => $ins,
		outs       => $outs,
		cursor     => 0,
		page_first => 0,
		rows       => 1,
		cols       => 1,
		zoom       => 1,
	};

	return $self;
}#

sub delete_current
{my ($self) = @_;

	my $next = $self->{pic}->seek(1) // $self->{pic}->seek(-1); #TODO: definir melhor o q fazer nos extremos
	$self->{pic}->delete;
	$self->{pic} = $next;
}#

sub adjust_page_and_cursor
{my ($self) = @_;

	my $last = $self->{count} - 1;
	my $page_size = $self->{rows}*$self->{cols};

	if ($self->{cursor} < 0) {
		$self->{cursor} = $last;
		$self->{page_first} = $last>=$page_size ? $last-($page_size-1) : 0;
	}
	elsif ($self->{cursor} > $last) {
		$self->{cursor} = $self->{page_first} = 0;
	}
	elsif ($page_size > 1) {
		if ($self->{count} > $page_size) {
			$self->{page_first} += $page_size
				while $self->{cursor}-$self->{page_first} >= $page_size;

			$self->{page_first} -= $page_size
				while $self->{cursor} < $self->{page_first};

			$self->{page_first} = 0
				if $self->{page_first} < 0;

			my $last_page = $self->{count} - $page_size;
			$self->{page_first} = $last_page
				if $self->{page_first} > $last_page;
		}
	}
	else {
		$self->{page_first} = $self->{cursor};
	}

}#

sub pvt__filter
{my ($self) = @_;

	foreach (@{$self->{ins}}) {
		return 0 unless $self->{pic}->{tags}->{$_};
	}
	foreach (@{$self->{outs}}) {
		return 0 if $self->{pic}->{tags}->{$_};
	}
	1;
}#

sub seek
{my ($self, $dir) = @_;

	given ($dir) {
		when (/^first$/) {
			warn;
		}
		when (/^last$/)  {
			warn;
		}
		when (/^[+-]/)   {
			$dir =~ s/line/$self->{cols}/e;
			$dir =~ s/page/$self->{cols}*$self->{rows}/e;

			my $d = $dir>0?1:-1;
			while ($dir) {

				my $old = $self->{pic};
				$self->{pic}->seek($d);
				last if $old eq $self->{pic};
				next unless $self->pvt__filter;
			}
		}
	}

}#

1;
# vim600:fdm=marker:fmr={my,}#:
