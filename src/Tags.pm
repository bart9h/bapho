package Tags;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use args qw/%args/;

#}#

my %all_tags = ();
sub all { grep { /^[^_]/ } keys %all_tags; }

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
{my ($self, $something) = @_;

	if ($something =~ m{/}) {
		if (open F, $something) {
			foreach (<F>) {
				s/^\s*(.*?)\s*$/$1/;
				next if m/^#/;
				next if $_ eq '';
				$self->pvt__set_tag($_);
			}
			close F;
		}
	}
	else {
		$self->pvt__set_tag($something);
		$self->pvt__save_pic_tags;
	}
}#

sub toggle
{my ($self, $tag) = @_;

	if (exists $self->{tags}->{$tag}) {
		delete $self->{tags}->{$tag};
	}
	else {
		$self->pvt__set_tag($tag);
	}

	$self->pvt__save_pic_tags;
}#

sub pvt__set_tag
{my ($self, $tag) = @_;

	$self->{tags}->{$tag} = 1;
	unless (defined $all_tags{$tag}) {
		$all_tags{$tag} = 1;
		$self->pvt__save_all_tags;
	}
}#

sub pvt__save_pic_tags
{my ($self) = @_;

	pvt__save_tags($self->{id}.'.tags', $self->{tags});
}#

sub pvt__save_all_tags
{my ($self) = @_;

	pvt__save_tags($args{basedir}.'/.bapho-tags', \%all_tags);
}#

sub pvt__save_tags
{my ($filename, $tags) = @_;

	unless ($args{nop}) {

		if (scalar keys %$tags > 0) {
			open F, '>', $filename  or die "$filename: $!";
			say "saving $filename"  if $args{verbose};
			print F "$_\n"  foreach sort keys %$tags;
			close F;
		}
		else {
			unlink $filename if -e $filename;
		}
	}
}#


1;
# vim600:fdm=marker:fmr={my,}#:
