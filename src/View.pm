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
		selection   => {},
	};

	$self->seek('+1') unless $self->pvt__filter;

	return $self;
}#

sub pic { $_[0]->{picitr}->{pic} }
sub selected_pics { map { $_[0]->{selection}->{$_} } keys %{$_[0]->{selection}} }
sub is_selected { exists $_[0]->{selection}->{ $_[1]->{id} // $_[0]->pic->{id} } }
sub toggle_selection { $_[0]->set_selected(!$_[0]->is_selected) }

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

sub set_selected
{my ($self, $selected, @pics) = @_;

	foreach ((scalar @pics) ? (@pics) : ($self->pic)) {
		if (exists $self->{selection}->{$_->{id}}) {
			delete $self->{selection}->{$_->{id}} unless $selected;
		}
		else {
			$self->{selection}->{$_->{id}} = $_ if $selected;
		}
	}
}#

sub toggle_selection_page
{my ($self) = @_;

	my @pics = $self->page_pics;

	my $selected = 0;
	foreach (@pics) {
		next if $self->is_selected($_);
		$selected = 1;
		last;
	}

	$self->set_selected($selected, @pics);
}#

sub delete_current
{my ($self) = @_;

	my $pic = $self->{picitr}->{pic};
	$self->{picitr}->seek(1) //
	$self->{picitr}->seek(-1) //
	$self->{picitr}->up; #TODO: definir melhor o q fazer nos extremos
	$pic->delete;
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
			$self->{picitr}->first;
			$self->pvt__filter or $self->seek('+1');
		}
		when (/^last$/)  {
			$self->{picitr}->last;
			$self->pvt__filter or $self->seek('-1');
		}
		when (/^up$/) {
			$self->{picitr}->up;
		}
		when (/^down$/) {
			$self->{picitr}->down;
		}
		when (/^[+-]/)   {
			$dir =~ s/line/$self->{cols}/e;
			$dir =~ s/page/$self->{cols}*$self->{rows}/e;

			my $d = $dir>0?1:-1;
			$self->pvt__filter or warn 'invalid itr';
			my $valid_itr = $self->{picitr}->dup;  # backup
			while ($dir) {
				if ($self->{picitr}->seek($d)) {
					$self->pvt__filter or next;
					$valid_itr = $self->{picitr}->dup;  # update
					$dir -= $d;
					$self->{page_cursor} += $d;
				}
				else {
					$self->{picitr} = $valid_itr;  # restore
					last;
				}
			}
		}
	}

}#

sub seek_to_file
{my ($self, $file, $jaildir) = @_;

	$self->{picitr} = PictureItr->new($file);

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
