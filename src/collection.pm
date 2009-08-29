package collection;

#{my uses

use strict;
use warnings;
use 5.010;
use Data::Dumper;

use args qw/%args/;
use factory;

#}#

sub new
{#{my}

	die if $args{dir_fmt} =~ m{\.};

	bless my $self = {
		pics => {},
		tags => {},
		factory => factory::new,
	};

	use File::Find;
	find({
			no_chdir => 1,
			follow => 1,
			wanted => sub { $self->pvt__add_file($_) },
		},
		($args{startdir} // $args{basedir}).'/'
	);

	die "no pictures found in \"$args{basedir}\""  unless scalar keys %{$self->{pics}};

	foreach (keys %{$self->{pics}}) {
		if (not defined $self->{pics}->{$_}->{sel}) {
			say "ignoring $_";
			delete $self->{pics}->{$_};
		}
	}

	$self->update_tags;

	return $self;
}#

sub update_tags
{my ($self) = @_;

	%{$self->{tags}} = ();
	foreach my $pic (keys %{$self->{pics}}) {
		foreach my $tag ($self->{pics}->{$pic}->get_tags) {
			$self->{tags}->{$tag}++;
		}
	}
}#

sub delete
{my ($self, $pic) = @_;

	$pic->delete;
	delete $self->{pics}->{$pic->{id}};
	$self->update_tags;
}#

sub get_surface
{my ($self, $id, $width, $height) = @_;

	my $file = $self->{pics}->{$id}->{sel};
	return $self->{factory}->get($file, $width, $height);
}#


sub pvt__add_file
{my ($self, $file) = @_;
	caller eq __PACKAGE__ or die;

	return if -d $file;
	return if $file =~ m{/\.bapho-state$};
	return if $file =~ m{/\.([^/]*-)?trash/}i;
	return if $file =~ m{/\.qiv-select/}i;

	if ($file =~ m|^
		$args{basedir}
		(.*/)?
		(?<id>[^.]+)\.
		(?<rest>.*)
		$|x)
	{
		my $pic = $self->{pics}{$+{id}} //= picture::new($+{id});
		$pic->add($file);
	}
	else {
		warn "strange filename ($file)";
	}
}#

1;
# vim600:fdm=marker:fmr={my,}#:
