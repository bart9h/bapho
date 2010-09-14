package View;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use PictureItr;

#}#

sub new
{my ($picitr, $ins, $outs) = @_;
	$picitr or die;

	bless my $self = {
		picitr     => $picitr,
		ins        => $ins,
		outs       => $outs,
		page_first => $picitr,
		rows       => 1,
		cols       => 1,
		zoom       => 1,
	};

	return $self;
}#

sub pic { $_[0]->{picitr}->{pic} }

sub delete_current
{my ($self) = @_;

	$self->{picitr}->{pic}->delete;
	$self->{picitr}->seek(1) // $self->{picitr}->seek(-1); #TODO: definir melhor o q fazer nos extremos
	FileItr->dirty();
}#

sub adjust_page_and_cursor
{my ($self) = @_;

	$self->{page_first} = $self->{picitr};

=a TODO
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

=cut
}#

sub pvt__filter
{my ($self) = @_;

	foreach (@{$self->{ins}}) {
		return 0 unless $self->pic->{tags}->get($_);
	}
	foreach (@{$self->{outs}}) {
		return 0 if     $self->pic->{tags}->get($_);
	}
	1;
}#

sub seek
{my ($self, $dir) = @_;

	given ($dir) {
		when (/^first$/) {
			warn 'TODO';
		}
		when (/^last$/)  {
			warn 'TODO';
		}
		when (/^[+-]/)   {
			$dir =~ s/line/$self->{cols}/e;
			$dir =~ s/page/$self->{cols}*$self->{rows}/e;

			my $d = $dir>0?1:-1;
			while ($dir) {

				my $old = $self->{picitr}->{pic};
				$self->{picitr}->seek($d);
				last if $old eq $self->{picitr}->{pic};
				next unless $self->pvt__filter;

				$dir -= $d;
			}
		}
	}

}#

sub seek_levels
{my ($self, $cmd, $keys) = @_;

	$cmd =~ m/(shift-)?([a-z])/;
	my ($shift, $k) = ($1, $2);

	$self->{picitr}->{itr}->pvt__up  #FIXME: using private method of FileItr
		foreach 1 .. $keys->{$k};
	$self->seek($shift ? '-1' : '+1');
}#

1;
# vim600:fdm=marker:fmr={my,}#:
