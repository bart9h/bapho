package FileItr;
use strict;
use warnings;
use v5.10;

sub new
{my ($class, $path) = @_;

	bless {
		path => $path
	}, $class
}#

sub next      { $_[0]->seek(+1) }
sub prev      { $_[0]->seek(-1) }
sub first     { $_[0]->seek('first') }
sub last      { $_[0]->seek('last') }
sub next_file { $_[0]->seek_file(+1) }
sub prev_file { $_[0]->seek_file(-1) }
sub path      { $_[0]->{path} }
sub join_path { my $rc = join '/', @_; $rc =~ s{//+}{/}g; $rc }

sub up
{my ($self) = @_;

	$self->{path} =~ m{^(?<parent>.*/)[^/]+/?$} or return undef;
	$self->{path} = $+{parent};
	$self->{path} =~ s{(.)/$}{$1};
	return $self;
}#

sub down
{my ($self, $direction) = @_;

	my @names = read_directory($self->{path});
	scalar @names or return undef;

	my $i = (defined $direction and $direction < 0) ? $#names : 0;
	$self->{path} = join_path($self->{path}, $names[$i]);
	return $self;
}#

sub seek_file
{my ($self, $direction) = @_;

	my $first_backwards_step = ($direction < 0);
	while (1) {

		unless ($first_backwards_step) {
			if (-d $self->{path}) {
				while ($self->down($direction)) {
					-d $self->{path} or return $self;
				}
			}
		}
		$first_backwards_step = 0;

		while (1) {
			if ($self->seek($direction)) {
				-d $self->{path} or return $self;
				last;
			}
			else {
				$self->up or return undef;
			}
		}
	}

}#

sub seek
{my ($self, $direction) = @_;

	$self->{path} =~ m{^(?<parent>.*/)(?<name>[^/]+)/?$} or return undef;
	my @names = read_directory($+{parent});

	my $idx;
	foreach (0 .. $#names) {
		if ($names[$_] eq $+{name}) {
			$idx = $_;
			last;
		}
	}
	defined $idx or die;

	$idx =
		$direction eq 'first' ? 0 :
		$direction eq 'last'  ? $#names :
		$idx + $direction;
	$idx >= 0 and $idx <= $#names or return undef;

	$self->{path} = join_path($+{parent}, $names[$idx]);
	return $self;
}#

sub read_directory
{my ($path) = @_;

	if (-d $path) {
		if (opendir(my $dh, $path)) {
			my @names = (
				sort { (-f $a and -d $b) ? -1 : (-d $a and -f $b) ? 1 : $a cmp $b }
				grep { not /^\./ }
				readdir($dh)
			);
			closedir $dh;
			return @names;
		}
		else {
			warn "opendir $path: $!";
		}
	}
	return ();
}#

sub test
{#{my test}
	use v5.10;
	my $itr = FileItr->new($_[0] // $ENV{PWD});
	my $dir = 1;
	while(1) {
		print ">>> $itr->{path} >>> ";
		local $_ = <STDIN>;
		chomp;
		given ($_) {
			when (/^(help|\?)$/) {
				say 'q=quit, <[+/-]number>=direction, n|j=+1, p|k=-1';
				next;
			}
			when (/^$/) {
			}
			when (/^f(ile)?$/) {
				$itr->next_file or say 'not';
				next;
			}
			when (/^F(ile)?$/) {
				$itr->prev_file or say 'not';
				next;
			}
			when (/^up$/) {
				$itr->up or say 'not';
				next;
			}
			when (/^down$/) {
				$itr->down or say 'not';
				next;
			}
			when (/^q$/) {
				last;
			}
			when (/^(n|j)$/) {
				$dir = +1;
			}
			when (/^(p|k)$/) {
				$dir = -1;
			}
			when (/^([+-]?\d+|first|last)$/) {
				$dir = $1;
			}
			default {
				say '?';
				next;
			}
		}
		$itr->seek($dir) or say "seek failed";
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
