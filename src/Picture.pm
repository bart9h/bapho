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

	if ($path =~ /\.tags$/i) {
		$self->{tags}->add($path);
	}
	else {
		die "duplicate file $path" if exists $self->{files}->{$path};
	}

	$self->{files}->{$path} = 1;

	if (is_pic($path) or is_vid($path)) {
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
	if ($file =~ m{\.(ufraw|cr2)$}i) {
		$cmd = "ufraw";
	}
	elsif (is_pic($file)) {
		$cmd = "gimp";
	}
	if (defined $cmd) {
		say $cmd if dbg;
		system "$cmd $file &";
	}
}#

sub play
{my ($self) = @_;

	if ($self->is_vid) {
		Video::play($self->{sel});
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

sub is_pic { pvt__is_pic_or_vid('pic', @_) }
sub is_vid { pvt__is_pic_or_vid('vid', @_) }

sub pvt__is_pic_or_vid
{my ($type, $self_or_path) = @_;
caller eq __PACKAGE__ or die;

	my $x = $self_or_path;
	my $path = ref $x ? $x->{sel} : $x;

	$path =~ m{\.([^.]+)$} or die;
	my $ext = lc $1;

	Array::find($args{$type.'_extensions'}, $ext);
}#

1;
# vim600:fdm=marker:fmr={my,}#:
