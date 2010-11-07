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

	$self->{path} =~ m{^(?<parent>.*/)[^/]+/?$} or return undef;
	$self->{path} = $+{parent};
	$self->{path} =~ s{(.)/$}{$1};
	return $self;
}#

sub down
{my ($self) = @_;

	my $first = (read_directory($self->{path}))[0];

	defined $first or return undef;

	$self->{path} = join_path($self->{path}, $first);
	return $self;
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

	$idx += $direction;
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
			when (/^([+-]?\d+)$/) {
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
