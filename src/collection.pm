package collection;

#{# use

use strict;
use warnings;
use 5.010;

use args qw/%args/;

#}#

sub new
{#
	die if $args{dir_fmt} =~ m{\.};

	bless my $self = {
		pics => {},
	};

	use File::Find;
	find ( {
			no_chdir => 1,
			follow => 1,
			wanted => sub { $self->add_file ($_); },
		},
		($args{startdir} // $args{basedir}).'/'
	);

	die "no pictures found in \"$args{basedir}\""  unless scalar keys %{$self->{pics}};
	return $self;
}#

sub add_file ($$)
{#
	my ($self, $file) = @_;

	return if -d $file;

	if ($file =~ m|^
		$args{basedir}
		(.*/)?
		(?<key>[^.]+)\.
		(?<rest>.*)
		$|x)
	{
		my $pic = $self->{pics}{$+{key}} //= picture::new ($+{key});
		$pic->add ($file);
	}
	else {
		warn "strange filename ($file)";
	}
}#

1;
# vim600:fdm=marker:fmr={#,}#: