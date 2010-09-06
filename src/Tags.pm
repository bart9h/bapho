package Tags;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use args qw/%args/;

#}#

sub new
{my ($class, $id) = @_;

	bless {
		id => $id,
		tags => {},
	}, $class;
}#

sub get
{my ($self, $tag) = @_;

	wantarray
	? grep {!/^_/} sort keys %{$self->{tags}}
	: $self->{tags}->{$tag}
}#

sub add
{my ($self, $path_or_tag) = @_;

	if ($path_or_tag =~ m{/}) {
		if (open F, $path_or_tag) {
			foreach (<F>) {
				s/^\s*(.*?)\s*$/$1/;
				next if m/^#/;
				next if $_ eq '';
				$self->{tags}->{$_} = 1;
			}
		}
	}
	else {
		$self->{tags}->{$path_or_tag} = 1;
		$self->pvt__save_tags;
	}
}#

sub toggle
{my ($self, $tag) = @_;

	if (exists $self->{tags}->{$tag}) {
		delete $self->{tags}->{$tag};
	}
	else {
		$self->{tags}->{$tag} = 1;
	}

	$self->pvt__save_tags;
}#

sub pvt__save_tags
{my ($self) = @_;

	unless ($args{nop}) {
		my $filename = $self->{id}.'.tags';

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


1;
# vim600:fdm=marker:fmr={my,}#:
