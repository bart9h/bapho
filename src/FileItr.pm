package FileItr;
use strict;
use warnings;

sub new  { bless (my ($path, $class) = @_); }
sub next { $_[0]->seek(+1) }
sub prev { $_[0]->seek(-1) }
sub up   { $_[0] =~ m{^(.*)/([^/]+)/?$} ? ($1, $2) : undef }
sub down { $_[0]->readdir[0] }

sub seek
{
	my ($path, $direction) = @_;
	$direction==1 or $direction==-1 or die;

	my ($parent, $name) = $path->up;
	my @names = $parent->readdir;

	my $idx = Array::find(\@names, $name);
	defined $idx or die;

	$idx += $direction;
	$idx >= 0 and $idx <= $#names
		? $parent.'/'.$names[$idx]
		: $parent->seek($direction)
}

sub readdir
{
	my ($path) = @_;

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
		warn "opendir $self->{parent}: $!";
		return ();
	}
}

1;
