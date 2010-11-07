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

sub next { $_[0]->seek(+1) }
sub prev { $_[0]->seek(-1) }
sub join_path { my $rc = join '/', @_; $rc =~ s{//+}{/}g; $rc }

sub up
{my ($self) = @_;

	$self->{path} =~ m{^(?<parent>.*/)[^/]+/?$}
		? FileItr->new($+{parent})
		: $self
}#

sub down
{my ($self) = @_;

	my $first = (read_directory($self->{path}))[0];

	defined $first
		? FileItr->new(join_path($self->{path}, $first))
		: $self;
}#

sub seek
{my ($self, $direction) = @_;
	$direction==1 or $direction==-1 or die;

	$self->{path} =~ m{^(?<parent>.*/)(?<name>[^/]+)/?$} or return $self;
	my @names = read_directory($+{parent});

	my $idx;
	foreach (0 .. $#names) {
		if ($names[$_] eq $+{name}) {
			$idx = $_;
			last;
		}
	}
	defined $idx or die;

	$idx += $direction;
	if ($idx >= 0 and $idx <= $#names) {
		return FileItr->new(join_path($+{parent}, $names[$idx]));
	}
	else {
		return FileItr->new($+{parent})->seek($direction);
	}
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

1;
# vim600:fdm=marker:fmr={my,}#:
