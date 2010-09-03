package picture;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use args qw/%args/;

#}#

sub new
{my ($id) = @_;

	bless {
		id             => $id,
		files          => {},
		tags           => {},
		dir            => undef,  #dir: where files are
		sel            => undef,  #path: which file was choosen to display
	};
}#

sub add
{my ($self, $path) = @_;

	die 'duplicate file'  if exists $self->{files}->{$path};

	unless ($path =~ m{^(.*)/[^.]+\.([^/]+)}) {
		warn "invalid filename \"$path\"\n";
		return;
	}

	my ($dir, $ext) = ($1, $2);
	if (defined $self->{dir} and $self->{dir} ne $dir) {
		warn "$path\nalso exists in\n$self->{dir}\n";
		return;
	}
	$self->{dir} //= $dir;

	given ($ext) {
		when (/^tags$/) {
			if (open F, $path) {
				$self->{tags} = {};
				foreach (<F>) {
					s/^\s*(.*?)\s*$/$1/;
					next if m/^#/;
					next if $_ eq '';
					$self->{tags}->{$_} = 1;
				}
			}
		}
		when (/^ufraw$/) {
		}
		default {
			$self->{files}->{$path} = 1;
			$self->{sel} = $path  if pvt__extval($path) > pvt__extval($self->{sel});
		}
	}
}#

sub toggle_tag
{my ($self, $tag) = @_;

	if (exists $self->{tags}->{$tag}) {
		delete $self->{tags}->{$tag};
	}
	else {
		$self->{tags}->{$tag} = 1;
	}

	$self->save_tags;
}#

sub get_tag_filename
{my ($self) = @_;

	defined $self->{dir} or die;
	"$self->{dir}/$self->{id}.tags";
}#

sub save_tags
{my ($self) = @_;

	unless ($args{nop}) {
		my $filename = $self->get_tag_filename;

		if (scalar keys %{$self->{tags}} > 0) {
			open F, '>', $filename  or die "$filename: $!";
			say "saving $filename"  if $args{verbose};
			print F "$_\n"  foreach sort keys %{$self->{tags}};
			close F;
		}
		else {
			unlink $filename if -e $filename;
		}
	}
}#

sub get_tags
{my ($self) = @_;

	grep {!/^_/} sort keys %{$self->{tags}};
}#

sub develop
{my ($self) = @_;

	sub guess_source
	{my ($self) = @_;

		foreach (qw/ufraw xcf cr2 tif png/) {
			foreach (glob "$self->{dir}/$self->{id}*.$_") {
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
		#TODO: catch editor termination to update index?
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
