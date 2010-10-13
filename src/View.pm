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
		picitr      => $picitr,
		ins         => $ins,
		outs        => $outs,
		rows        => 1,
		cols        => 1,
		zoom        => 1,
		page_cursor => 0,
		marks       => {},
	};

	$self->seek('+1') unless $self->pvt__filter;

	return $self;
}#

sub pic { $_[0]->{picitr}->{pic} }
sub is_marked { exists $_[0]->{marks}->{ $_[1]->{id} // $_[0]->pic->{id} } }
sub toggle_mark { $_[0]->set_mark(!$_[0]->is_marked); }

sub page_pics
{my ($self) = @_;

	my @pics = ();
	my $i = $self->{picitr};
	foreach (1 .. $self->{page_cursor}) {
		my $p = $i->prev;
		if ($p) {
			$i = $p;
		}
		else {
			$self->{page_cursor} = 0;
			last;
		}
	}
	foreach (1 .. $self->{rows} * $self->{cols}) {
		push @pics, $i->{pic};
		$i = $i->next  or last;
	}
	return @pics;
}#

sub set_mark
{my ($self, $mark, @pics) = @_;

	foreach ((scalar @pics) ? (@pics) : ($self->pic)) {
		if (exists $self->{marks}->{$_->{id}}) {
			delete $self->{marks}->{$_->{id}} unless $mark;
		}
		else {
			$self->{marks}->{$_->{id}} = $_ if $mark;
		}
	}
}#

sub toggle_mark_page
{my ($self) = @_;

	my @pics = $self->page_pics;

	my $mark = 0;
	foreach (@pics) {
		next if $self->is_marked($_);
		$mark = 1;
		last;
	}

	$self->set_mark($mark, @pics);
}#

sub delete_current
{my ($self) = @_;

	$self->{picitr}->{pic}->delete;
	$self->{picitr}->seek(1) // $self->{picitr}->seek(-1); #TODO: definir melhor o q fazer nos extremos
	FileItr->dirty();
}#

sub adjust_page_and_cursor
{my ($self) = @_;

	my $p = $self->{rows}*$self->{cols};

	while ($self->{page_cursor} < 0) {
		$self->{page_cursor} += $p;
	}

	while ($self->{page_cursor} >= $p) {
		$self->{page_cursor} -= $p;
	}
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
				$self->{picitr}->seek($d) or last;
				next unless $self->pvt__filter;
				$dir -= $d;
				$self->{page_cursor} += $d;
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

	# put itr at the start of the dir
	$self->{picitr}->{itr}->{cursor} = 0;
	# re-build picitr
	$self->{picitr} = $self->{picitr}->dup;
	$self->{page_cursor} = 0;
}#

sub seek_file
{my ($self, $file, $jaildir) = @_;

	$self->{picitr} = PictureItr->new($file, $jaildir);

	until ($self->pvt__filter) {
		$self->{picitr}->seek(1);
	}
}#

sub pvt__filter
{my ($self) = @_;
caller eq __PACKAGE__ or die;

	foreach (@{$self->{ins}}) {
		return 0 unless $self->pic->{tags}->get($_);
	}
	foreach (@{$self->{outs}}) {
		return 0 if     $self->pic->{tags}->get($_);
	}
	1;
}#

1;
# vim600:fdm=marker:fmr={my,}#:
