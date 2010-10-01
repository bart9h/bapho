package Picture;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use args qw/%args dbg/;
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

	unless ($path =~ m{^.*/[^.]+\.(?<ext>[^/]+)}) {
		warn "invalid filename \"$path\"\n";
		return;
	}

	$self->{files}->{$path} = 1;

	given ($+{ext}) {
		when (/^tags$/) {
			$self->{tags}->add($path);
		}
	}

	if (Array::find($args{pic_extensions}, $+{ext})) {
		$self->{sel} = $path
			if not defined $self->{sel}
			or -M $path < -M $self->{sel};
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
		say $cmd if dbg;
		system "$cmd $file &";
	}
}#

sub delete
{my ($self) = @_;

	return if $args{nop};

	my $afile = (keys %{$self->{files}})[0];
	$afile =~ m{^(.*?)/[^/]+$}
		or die "strange filename ($afile)";
	my $trash = "$1/.bapho-trash";
	-d $trash or print `mkdir -v "$trash"`;
	foreach (keys %{$self->{files}}) {
		print `mv -v "$_" "$trash/"`;
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
