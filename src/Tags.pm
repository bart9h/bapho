package Tags;

#{my uses

use strict;
use warnings;
use 5.010;
use Carp;
use Data::Dumper;

use args qw/%args dbg/;

#}#

my $all_path = $args{basedir}.'/.bapho-tags';
my %all_tags = map { $_ => 1 } pvt__read_tags($all_path);

sub all
{#{my}

	my @all = grep { /^[^_]/ } keys %all_tags;

	my @mru = (
		sort { $all_tags{$b} <=> $all_tags{$a} }
		grep { $all_tags{$_} > 1 }
		@all
	);
	@mru = $mru[0 .. 4]  if scalar @mru > 5;

	my @rest = sort grep { not defined Array::find(\@mru, $_) } @all;

	return @mru, @rest;
}#

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

sub get_nstars
{my ($self) = @_;

	my $n = 0;
	foreach ("", 1 .. 5) {
		$n = ($_ ? $_ : 1)  if exists $self->{tags}->{'_star'.$_};
	}
	return $n;
}#

sub add
{my ($self, $something) = @_;

	if ($something =~ m{/}) {
		foreach (pvt__read_tags($something)) {
			$self->pvt__set_tag($_);
		}
	}
	else {
		$self->pvt__set_tag($something);
		$self->pvt__save_pic_tags;  #TODO: only if tag was new
	}
}#

sub toggle
{my ($self, $tag) = @_;

	if (exists $self->{tags}->{$tag}) {
		delete $self->{tags}->{$tag};
	}
	else {
		$self->pvt__set_tag($tag);
		$all_tags{$tag} = time;
	}

	$self->pvt__save_pic_tags;
}#

sub toggle_star
{my ($self) = @_;

	my $n = $self->get_nstars;
	say "was($n)" if dbg 'tags';
	$n = ($n<5) ? $n+1 : 0;
	say "is($n)" if dbg 'tags';

	foreach ("", 1 .. 5) {
		my $tag = '_star'.$_;
		my $i = $_ ? $_ : 1;
		if ($i > $n) {
			if (exists $self->{tags}->{$tag}) {
				say "del($tag)" if dbg 'tags';
				delete $self->{tags}->{$tag};
			}
		}
		else {
			if ($tag ne '_star1') { # =='_star'
				say "set($tag)" if dbg 'tags';
				$self->{tags}->{$tag} = 1;
			}
		}
	}

	$self->pvt__save_pic_tags;
}#

sub pvt__set_tag
{my ($self, $tag) = @_;
caller eq __PACKAGE__ or croak;

	say "Setting tag \"$tag\" to \"$self->{id}\"."  if dbg 'tags';
	$self->{tags}->{$tag} = 1;
	unless (defined $all_tags{$tag}) {
		$all_tags{$tag} = 1;
		pvt__save_tags($all_path, \%all_tags);
	}
}#

sub pvt__save_pic_tags
{my ($self) = @_;
caller eq __PACKAGE__ or croak;

	pvt__save_tags($self->{id}.'.tags', $self->{tags});
}#

sub pvt__save_tags
{my ($filename, $tags) = @_;
caller eq __PACKAGE__ or croak;

	unless ($args{nop}) {

		if (scalar keys %$tags > 0) {
			-e $filename or FileItr->dirty();
			if ($args{nop}) {
				say "Saving \"$filename\"...";
				say "\t$_" foreach sort keys %$tags;
				say "done.";
			}
			else {
				open F, '>', $filename  or die "$filename: $!";
				say "Saving \"$filename\"."  if dbg 'tags,file';
				print F "$_\n"  foreach sort keys %$tags;
				close F;
			}
		}
		else {
			if ($args{nop}) {
				say "Removing \"$filename\".";
			}
			else {
				unlink $filename if -e $filename;
			}
		}
	}
}#

sub pvt__read_tags
{my ($filename) = @_;
caller eq __PACKAGE__ or croak;
	wantarray or croak;

	if (open F, $filename) {
		say "reading $filename"  if dbg 'tags,file';
		my @rc = ();
		foreach (<F>) {
			s/^\s*(.*?)\s*$/$1/;
			next if m/^#/;
			next if $_ eq '';
			push @rc, $_;
		}
		close F;
		@rc;
	}
	else {
		();
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
