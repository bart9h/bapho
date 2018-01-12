package Tags;

#{my uses

use strict;
use warnings;
use 5.010;
use Carp;
use Data::Dumper;

use args qw/%args dbg/;

#}#

my %singleton;

sub init
{#{my}

	my $all_path = $args{basedir}.'/.bapho-tags';

	%singleton = (
		all_path => $all_path,
		all_tags => pvt__read_tags($all_path),
		last_edit => {},
		clean_last_edit => 0,
	);
}#

sub mru
{my (@all) = @_;

	my @mru = (
		sort { $singleton{all_tags}->{$b} <=> $singleton{all_tags}->{$a} }
		grep { $singleton{all_tags}->{$_} > time - 7*24*60*60 }
		@all
	);

	my $mru_max = 20;

	scalar @mru > $mru_max
		? @mru[0 .. $mru_max-1]
		: @mru;
}#

sub groups
{#{my}

	my @groups = ();

	my @all = sort grep { /^[^_]/ } keys %{$singleton{all_tags}};

	my @mru = mru @all;

	my @rest = Array::subtract(\@all, @mru);

	my @people = grep { m/^name:/  } @rest;
	my @places = grep { m/^place:/ } @rest;

	@rest = Array::subtract(\@rest, @people, @places);

	return grep { scalar @{$_->{items}} > 0 } (
		{ label => 'recent', items => [ @mru    ] },
		{ label => 'people', items => [ @people ] },
		{ label => 'places', items => [ @places ] },
		{ label => 'others', items => [ @rest   ] },
	);
}#

sub ALL
{#{my}

	return sort keys %{$singleton{all_tags}};
}#

sub new
{my ($class, $id) = @_;

	bless {
		id => $id,
		tags => {},
	}, $class;
}#

sub begin_edit
{#{my}

	$singleton{clean_last_edit} = 1;
}#

sub repeat_last_edit
{my ($self) = @_;

	foreach my $tag (keys %{$singleton{last_edit}}) {
		my $t = $singleton{last_edit}->{$tag};
		if ($t == 1) {
			$self->{tags}->{$tag} = 1;
		}
		elsif ($t == 0) {
			delete $self->{tags}->{$tag};
		}
		else {
			die;
		}
	}

	$self->pvt__save_pic_tags;
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
{my ($self, $something, $time) = @_;

	if ($something =~ m{/}) {
		foreach (keys %{pvt__read_tags($something)}) {
			$self->pvt__set_tag($_, $time);
		}
	}
	else {
		$self->pvt__set_tag($something, $time);
		$self->pvt__save_pic_tags;
	}
}#

sub toggle
{my ($self, $tag) = @_;

	sub toggle_singleton {
		if ($singleton{clean_last_edit}) {
			$singleton{last_edit} = {};
			$singleton{clean_last_edit} = 0;
		}

		if (exists $singleton{last_edit}->{$_[0]}) {
			delete $singleton{last_edit}->{$_[0]};
		}
		else {
			$singleton{last_edit}->{$_[0]} = $_[1];
		}
	}

	if (exists $self->{tags}->{$tag}) {
		delete $self->{tags}->{$tag};
		toggle_singleton($tag, 0);
	}
	else {
		$self->pvt__set_tag($tag, time);
		toggle_singleton($tag, 1);
	}

	$self->pvt__save_pic_tags;
}#

sub toggle_star
{my ($self, $dir) = @_;
	$dir //= 1;

	my $n = $self->get_nstars;
	say "was($n)"  if dbg 'tags';
	if ($dir > 0) {
		$n = ($n<5) ? $n+1 : 0;
	}
	else {
		$n = ($n>0) ? $n-1 : 5;
	}
	say "is($n)"  if dbg 'tags';

	foreach ("", 1 .. 5) {
		my $tag = '_star'.$_;
		my $i = $_ ? $_ : 1;
		if ($i > $n) {
			if (exists $self->{tags}->{$tag}) {
				say "del($tag)"  if dbg 'tags';
				delete $self->{tags}->{$tag};
			}
		}
		else {
			if ($tag ne '_star1') { # =='_star'
				say "set($tag)"  if dbg 'tags';
				$self->{tags}->{$tag} = 1;
			}
		}
	}

	$self->pvt__save_pic_tags;
}#

sub pvt__set_tag
{my ($self, $tag, $time) = @_;
caller eq __PACKAGE__  or croak;

	say "Setting tag \"$tag\" to \"$self->{id}\"."  if dbg 'tags';
	$self->{tags}->{$tag} = 1;
	if (not defined $singleton{all_tags}->{$tag} or $time) {
		$singleton{all_tags}->{$tag} = $time;
		pvt__save_tags($singleton{all_path}, $singleton{all_tags});
	}
}#

sub pvt__save_pic_tags
{my ($self) = @_;
caller eq __PACKAGE__  or croak;

	pvt__save_tags($self->{id}.'.tags', $self->{tags});
}#

sub pvt__save_tags
{my ($filename, $tags) = @_;
caller eq __PACKAGE__  or croak;

	return if $args{readonly};

	if (scalar keys %$tags > 0) {
		if (!-e $filename) { FileItr->dirty() }
		unless ($args{nop}) {
			open F, '>', $filename  or die "$filename: $!";
			say "Saving \"$filename\"."  if dbg 'tags,file';
			foreach my $tag (sort keys %$tags) {
				my $line = $tags->{$tag} ? "$tag=$tags->{$tag}" : $tag;
				print F "$line\n";
			}
			close F;
		}
		else {
			say "(not) Saving \"$filename\"...";
			foreach my $tag (sort keys %$tags) {
				my $line = $tags->{$tag} ? "$tag=$tags->{$tag}" : $tag;
				say "\t$line";
			}
			say "done.";
		}
	}
	else {
		if (-e $filename) {
			unless ($args{nop}) {
				if (unlink $filename) {
					say "\"$filename\" removed."  if dbg 'tags,file';
				}
				else {
					warn "unlink \"$filename\": $!\n";
				}
			}
			else {
				say "(not) Removing \"$filename\".";
			}
		}
	}
}#

sub pvt__read_tags
{my ($filename) = @_;
caller eq __PACKAGE__  or croak;

	if (open F, $filename) {
		say "reading $filename"  if dbg 'tags,file';
		my %rc = ();
		foreach my $line (<F>) {
			$line =~ s/^\s*(.*?)\s*$/$1/;
			next  if $line =~ m/^#/;
			next  if $line eq '';
			my ($tag, $val) = ($line =~ m/^([^=]+)=(.+)$/) ? ($1, $2) : ($line, 1);
			$rc{$tag} = $val;
		}
		close F;
		\%rc;
	}
	else {
		{};
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
