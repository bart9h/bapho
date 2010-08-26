#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

#}#

# test usage:
#    perl -MFileItr -e test
#    perl -MFileItr -e 'test "/some/path"'
sub test
{#{my}

	my $i = FileItr::new($_[0] // $ENV{PWD});
	my $dir = 1;
	my $dbg = 0;
	while(1) {
		print $i->path . ' > ';
		local $_ = <STDIN>;
		chomp;
		given ($_) {
			when (/^(help|\?)$/) {
				say 'q=quit, d=toggle dump, <[+/-]number>=direction';
				next;
			}
			when (/^$/) {
			}
			when (/^q$/) {
				last;
			}
			when (/^d$/) {
				print Dumper $i if $dbg = !$dbg;
				next;
			}
			when (/^([+-]?\d+)$/) {
				$dir = $1;
			}
			default {
				say '?';
				next;
			}
		}
		$i->seek($dir);
		print Dumper $i if $dbg;
	}
}#


# package usage:
#   my $file = FileItr::new("/some/path");
#   $file->seek(+1);
#   say $file->path;
package FileItr;

sub new
{my ($path) = @_;

	bless my $self = {
		cursor => 0,
		parent => $path,
		files  => [],
	};

	if (-d $path) {
		$self->pvt__readdir;
		$self->pvt__down(1);
	}
	else {
		$self->pvt__up;
	}

	$self;
}#

sub path
{my ($self) = @_;

	$self->{parent}.'/'.$self->{files}->[$self->{cursor}];
}#

sub seek
{my ($self, $dir) = @_;

	while($dir) {
		my $d = $dir>0?1:-1;
		$self->pvt__seek($d);
		$dir -= $d;
	}
	$self;
}#


sub pvt__seek
{my ($self, $dir) = @_;

	$self->{cursor} += $dir;
	if ($self->{cursor} >= 0 and $self->{cursor} < scalar @{$self->{files}}) {
		$self->pvt__down($dir);
	}
	else {
		$self->pvt__up;
		$self->pvt__seek($dir);
		$self->pvt__down($dir);
	}
}#

sub pvt__up
{my ($self) = @_;

	$self->{parent} =~ m{^(.*?)/([^/]+)$} or die; #TODO
	$self->{parent} = $1;
	$self->pvt__find($2);
}#

sub pvt__down
{my ($self, $dir) = @_;

	while (-d $self->path) {
		$self->{parent} = $self->path;
		$self->pvt__readdir;
		$self->{cursor} = scalar @{$self->{files}} - 1
			if $dir == -1;
	}
}#

sub pvt__find
{my ($self, $name) = @_;

	$self->pvt__readdir;
	for (; $self->{cursor} < scalar @{$self->{files}}; ++$self->{cursor}) {
		last if $self->{files}->[$self->{cursor}] eq $name;
	}
	$self;
}#

sub pvt__readdir
{my ($self) = @_;

	opendir(my $dh, $self->{parent})
		|| die "opendir $self->{parent}: $!";

	$self->{files} = [
		sort { (-f $a and -d $b) ? -1 : (-d $a and -f $b) ? 1 : $a cmp $b }
		grep { not /^\./ } #and (-f $_ or -d $_) }
		readdir($dh)
	];
	closedir $dh;

	die 'empty dir' unless scalar @{$self->{files}};  #TODO: nao morrer
	$self->{cursor} = 0;
	$self;
}#

1;
# vim600:fdm=marker:fmr={my,}#:
