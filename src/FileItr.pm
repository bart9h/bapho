package FileItr;

#{my documentation

=head1 SYNOPSIS

	my $file = FileItr->new("/some/path");
	$file->seek(+1);
	say $file->path;

=cut

#}#

#{my uses

use strict;
use warnings;
use 5.010;
use Carp;
use Data::Dumper;
use args qw/dbg/;

#}#

my $dirty = 0;
sub dirty { $dirty = 1 }

sub new
{my ($class, $path, $jaildir) = @_;

	$path  or croak;

	$path =~ s{/$}{};

	bless my $self = {
		parent  => $path,
		files   => [],
		cursor  => 0,
		jaildir => $jaildir // '/',
	}, $class;

	if (-e $path) {
		if (-d $path) {
			$self->pvt__readdir;
			if (@{$self->{files}}) {
				$self->{cursor} = 0;
				$self->pvt__down(1);
			}
			else {
				die "\"$path\" is empty.\n";
			}
		}
		else {
			0 until $self->pvt__up;
		}
	}
	else {
		confess "\"$path\" not found.";
		return undef;
	}

	$self;
}#

sub path
{my ($self) = @_;

	my $path = $self->{parent}.'/'.$self->{files}->[$self->{cursor}];
	$path =~ s{/+}{/}g;  # remove duplicated /'s (if parent==/)
	$path;
}#

sub seek
{my ($self, $dir) = @_;

	my $d = $dir>0?1:-1;
	while($dir) {

		# backup self
		my $bk_dir  = $self->{parent};
		my $bk_file = $self->{files}->[$self->{cursor}];

		unless (eval { $self->pvt__seek($d) }) {

			# restore self
			$self->{parent} = $bk_dir;
			$self->pvt__find($bk_file);

			return undef;
		}
		$dir -= $d;
	}

	$self;
}#

sub first { $_[0]->{cursor} = 0;                  $_[0] }
sub last  { $_[0]->{cursor} = $#{$_[0]->{files}}; $_[0] }

sub pvt__seek
{my ($self, $dir) = @_;
caller eq __PACKAGE__  or croak;
say "pvt__seek (parent=$self->{parent}, cursor=$self->{cursor}, dir=$dir)"  if dbg 'trace';

	if ($dirty) {
		$self->pvt__find($self->{files}->[$self->{cursor}]);
		$dirty = 0;
	}

	$self->{cursor} += $dir;
	if ($self->{cursor} >= 0 and $self->{cursor} < scalar @{$self->{files}}) {
		$self->pvt__down($dir);
	}
	else {
		$self->pvt__up;
		$self->pvt__seek($dir);
		$self->pvt__down($dir);
	}

	1;
}#

sub pvt__up
{my ($self) = @_;
#caller eq __PACKAGE__  or croak;  # View.pm uses this sub
say "pvt__up (parent=$self->{parent})"  if dbg 'trace';

	my $base = $self->{jaildir};
	$base =~ s{/$}{};
	$self->{parent} =~ m|^(?<parent>$base(.*)?)/(?<name>[^/]+)$|
		or confess "match failed for \"$self->{parent}\"";
	$self->{parent} = $+{parent} ne '' ? $+{parent} : '/';
	$self->pvt__find($+{name});
}#

sub pvt__down
{my ($self, $dir) = @_;
caller eq __PACKAGE__  or croak;
say "pvt__down (parent=$self->{parent})"  if dbg 'trace';

	while (-d $self->path) {
		$self->{parent} = $self->path;
		$self->pvt__readdir;
		if (@{$self->{files}}) {
			$self->{cursor} = $dir>0 ? 0 : (scalar @{$self->{files}} - 1);
		}
		else {
			$self->pvt__up;
			$self->pvt__seek($dir);
			$self->pvt__down($dir);
		}
	}
}#

sub pvt__find
{my ($self, $name) = @_;
caller eq __PACKAGE__  or croak;
say "pvt__find (parent=$self->{parent}, name=$name)"  if dbg 'trace';

	$self->pvt__readdir;

	for ($self->{cursor} = 0;; ++$self->{cursor}) {

		if ($self->{cursor} >= scalar @{$self->{files}}) {
			warn "couldn't find $name in $self->{parent}";
			$self->{cursor} = 0;
			return 0;
		}

		if ($self->{files}->[$self->{cursor}] eq $name) {
			return 1;
		}
	}
	confess;
}#

sub pvt__readdir
{my ($self) = @_;
caller eq __PACKAGE__  or croak;

	if (opendir(my $dh, $self->{parent})) {
		$self->{files} = [
			sort { (-f $a and -d $b) ? -1 : (-d $a and -f $b) ? 1 : $a cmp $b }
			grep { not /^\./ } #and (-f $_ or -d $_) }
			readdir($dh)
		];
		closedir $dh;
	}
	else {
		warn "opendir $self->{parent}: $!";
		$self->{files} = [];
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
