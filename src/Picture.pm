package Picture;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use args qw/%args/;
use Array;
use Tags;

#}#

sub new
{my ($id) = @_;

	bless {
		id             => $id,
		files          => {},
		tags           => Tags->new($id),
		sel            => undef, #path: which file was choosen to display
	};
}#

sub add
{my ($self, $path) = @_;

	die 'duplicate file'  if exists $self->{files}->{$path};

	unless ($path =~ m{^.*/[^.]+\.([^/]+)}) {
		warn "invalid filename \"$path\"\n";
		return;
	}
	given ($1) {
		when (/^tags$/) {
			$self->{tags}->add($path);
		}
		when (/^ufraw$/) {
		}
		default {
			$self->{files}->{$path} = 1;
			$self->{sel} = $path  if pvt__extval($path) > pvt__extval($self->{sel});
		}
	}
}#

sub develop
{my ($self) = @_;

	sub guess_source
	{my ($self) = @_;

		foreach (qw/ufraw xcf cr2 tif png/) {
			foreach (glob "$self->{id}*.$_") {
				-r and return $_;
			}
		}

		return $self->{sel};
	}#

	my $file = $self->guess_source;

	my $cmd;
	given ($file) {
		when (/\.(cr2|ufraw)$/i) {
			$cmd = "ufraw";
		}
		default {
			$cmd = "gimp";
		}
	}
	if (defined $cmd) {
		say $cmd if $args{verbose};
		system "$cmd $file &";
	}
}#

sub delete
{my ($self) = @_;

	return if $args{nop};

	$self->{sel} =~ m{^(.*?)/([^/]+)\.[^.]+$}
		or die "strange filename ($self->{sel})";
	my ($dirname, $basename) = ($1, $2);
	my $trash = "$dirname/.bapho-trash";
	-d $trash or print `mkdir -v "$trash"`;
	while (glob "$dirname/$basename.*") {
		print `mv -v "$_" "$trash/"`;
	}
}#


sub pvt__extval
{my ($path) = @_;
	caller eq __PACKAGE__ or die;

	defined $path
	?
	$path =~ /\.([^.]+)$/
	?
	{
		jpg => 3,
		tif => 2,
		png => 2,
		cr2 => 1,
	}->{lc $1}
	// 0
	:
	-1
	:
	-1
}#

1;
# vim600:fdm=marker:fmr={my,}#:
