package View;

#{my uses

use strict;
use warnings;
use 5.010;
use Carp;
use Data::Dumper;

use args qw/%args dbg/;
use PictureItr;

#}#

sub new
{my ($picitr, $ins, $outs, $file) = @_;
	$picitr or croak;

	defined $ins   or $ins  = [];
	defined $outs  or $outs = [ (split /,/, $args{exclude}) ];

	bless my $self = {
		picitr      => $picitr,
		ins         => { map { $_ => 1 } @$ins },
		outs        => { map { $_ => 1 } @$outs },
		rows        => 1,
		cols        => 1,
		zoom        => 1,
		page_cursor => 0,
		selection   => {},
		marks       => {},
	};

	if (defined $file) {
		$self->seek_to_file($file, $self->{picitr}->{jaildir});
	}
	else {
		$self->seek('+1')  if not $self->pvt__filter;
	}

	return $self;
}#

sub pic { $_[0]->{picitr}->{pic} }
sub selected_pics { map { $_[0]->{selection}->{$_} } keys %{$_[0]->{selection}} }
sub is_selected { exists $_[0]->{selection}->{ $_[1]->{id} // $_[0]->pic->{id} } }
sub toggle_selection { $_[0]->set_selected(!$_[0]->is_selected) }

sub page_pics
{my ($self) = @_;

	my @pics = ();
	my $i = $self->{picitr}->dup;
	A: foreach (1 .. $self->{page_cursor}) {
		do {
			unless ($i->seek(-1)) {
				$self->{page_cursor} = 0;
				last A;
			}
		} until $self->pvt__filter($i->{pic});
	}
	B: foreach (1 .. $self->{rows} * $self->{cols}) {
		push @pics, $i->dup->{pic};
		do {
			unless ($i->seek(1)) {
				$self->{page_cursor} = 0;
				last B;
			}
		} until $self->pvt__filter($i->{pic});
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
{my ($self, $dir, $itr) = @_;
	$itr //= $self->{picitr};

	if ($dir eq 'first') {
		$itr->first;
		$self->pvt__filter($itr->{pic}) or $self->seek('+1');
	}
	elsif ($dir eq 'last')  {
		$itr->last;
		$self->pvt__filter($itr->{pic}) or $self->seek('-1');
	}
	elsif ($dir =~ /^[+-]/)   {
		$dir =~ s/line/$self->{cols}/e;
		$dir =~ s/page/$self->{cols}*$self->{rows}/e;

		my $d = $dir>0?1:-1;
		$self->pvt__filter($itr->{pic}) or warn 'invalid itr';
		my $valid_itr = $itr->dup;  # backup
		while(1) {
			if ($itr->seek($d)) {
				$self->pvt__filter($itr->{pic}) or next;
				$valid_itr = $itr->dup;  # update
				$self->{page_cursor} += $d;
				$dir -= $d;
				return 1 if $dir == 0;
			}
			else {
				%$itr = %$valid_itr;  # restore
				return 0;
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
	$self->pvt__filter or $self->seek('+1');
	$self->{page_cursor} = 0;
}#

sub seek_to_file
{my ($self, $file, $jaildir) = @_;

	$self->{picitr} = PictureItr->new($file, $jaildir);

	until ($self->pvt__filter) {
		$self->{picitr}->seek(1);
	}
}#

sub mark
{my ($self, $mark) = @_;

	$self->{marks}->{$mark} = $self->{picitr}->dup;
}#

sub marked_pics
{my ($self) = @_;

	return pvt__pics_between_itrs (
		$self->{marks}->{first},
		$self->{marks}->{last}
	);
}#

sub folder_pics
{my ($self) = @_;

	my $first = $self->{picitr}->dup;
	my $last  = $self->{picitr}->dup;

	$first->first();
	$last->last();

	return $self->pvt__pics_between_itrs($first, $last);
}#

sub pvt__filter
{my ($self, $pic) = @_;
caller eq __PACKAGE__ or croak;

	$pic //= $self->pic;
	foreach (keys %{$self->{ins}}) {
		return 0 unless $pic->{tags}->get($_);
	}
	foreach (keys %{$self->{outs}}) {
		return 0 if     $pic->{tags}->get($_);
	}
	1;
}#

sub pvt__pics_between_itrs
{my ($self, $first, $last) = @_;
caller eq __PACKAGE__ or croak;

	return () unless defined $first and defined $last;

	# swap endpoints if not ordered
	if ($first->{id} gt $last->{id}) {
		my $tmp = $first;
		$first = $last;
		$last = $tmp;
	}

	my @rc;

	my $itr = $first->dup;
	until ($self->pvt__filter($itr->{pic})) {
		$itr->seek('+1');
	}

	while ($itr->{id} le $last->{id}) {
		push @rc, $itr->{pic};
		$self->seek('+1', $itr) or last;
	}

	@rc;
}#

1;
# vim600:fdm=marker:fmr={my,}#:
