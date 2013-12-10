package Picture;

#{my uses

use strict;
use warnings;
use 5.010;
use Carp;
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
		croak "Duplicate file $path." if exists $self->{files}->{$path};
	}

	$self->{files}->{$path} = 1;

	if (is_pic($path) or is_vid($path)) {
		$self->{sel} = $path
			if not defined $self->{sel}
			or not -s $self->{sel}
			or -M $path < -M $self->{sel};
	}
}#

sub open_folder
{my ($self) = @_;

	$self->{sel} =~ m{^(.*?/)[^/]+$} or die;
	system "xdg-open \"$1\"";
}#

sub develop
{my ($self, $app) = @_;

	sub guess_source
	{my ($self, $app) = @_;

		my %app_exts = (
			ufraw => [ 'ufraw', 'cr2' ],
			gimp  => [ 'xcf', 'ppm', 'tif', 'png', 'jpg' ],
		);
		not $app or $app_exts{$app} or confess;

		foreach my $a ( $app
				? ( $app )
				: ( 'ufraw', 'gimp' )
		) {
			foreach my $ext (@{$app_exts{$a}}) {
				foreach (keys %{$self->{files}}) {
					/\.$ext$/ and -r and return $_;
				}
			}
		}

		return undef;
	}#

	my $file = $self->guess_source($app) or return;

	my $cmd;
	given ($file) {
		when (/\.ufraw$/i) {
			$cmd = "ufraw \"$file\" || gvim \"$file\"";
		}
		when (/\.cr2$/i) {
			$cmd = "ufraw \"$file\"";
		}
		when (is_pic($file)) {
			$cmd = "gimp \"$file\" &";
		}
	}
	if (defined $cmd) {
		say $cmd if dbg;

		my $ppm = $file; $ppm =~ s/\.[^.]+$/\.ppm/;
		my $M0 = -M $ppm;

		system $cmd;

		if ($cmd =~ /^ufraw /) {
			my $jpg = $file; $jpg =~ s/\.[^.]+$/\.jpg/;
			my $M1 = -M $ppm;
			if (not -s $jpg and $M1 and (not $M0 or $M0 != $M1)) {
				$cmd = "convert -sharpen 3x1 -quality 90 -resize 1920x1080 \"$ppm\" \"$jpg\"";
				my $base = $jpg; $base =~ s{/([^/]+)$}{$1};
				$cmd = "($cmd; notify-send \"$base\") &";
				say $cmd;
				system $cmd;
			}
		}
	}
}#

sub play
{my ($self) = @_;

	if ($self->is_vid) {
		Video::play($self->{sel});
	}
}#

sub print
{my ($self) = @_;

	if (-d $self->{sel}) {
		say $self->{sel};
	}
	else {
		my @files_to_identify = ();
		foreach (sort keys %{$self->{files}}) {
			if (/\.(jpg|png|tif|ppm)$/) {
				push @files_to_identify, '"'.$_.'"';
			}
			else {
				say;
			}
		}
		if (@files_to_identify) {
			my $cmd = 'identify '.join ' ', @files_to_identify;
			system $cmd;
		}
	}
}#


sub delete
{my ($self) = @_;

	return if $args{nop};

	my $afile = (keys %{$self->{files}})[0];
	$afile =~ m{^(.*?)/[^/]+$}
		or croak "Strange filename ($afile).";
	my $trash = "$1/.bapho-trash";
	-d $trash or print `mkdir -v "$trash"`;
	foreach (keys %{$self->{files}}) {
		print `mv -v "$_" "$trash/"`;
	}
}#

sub is_pic { pvt__is_pic_or_vid('pic', @_) }
sub is_vid { pvt__is_pic_or_vid('vid', @_) }
sub is_pic_or_vid { is_pic(@_) or is_vid(@_) }

sub pvt__is_pic_or_vid
{my ($type, $self_or_path) = @_;
caller eq __PACKAGE__ or croak;

	my $x = $self_or_path;
	my $path = ref $x ? $x->{sel} : $x;

	$path =~ m{\.([^.]+)$} or die;
	my $ext = lc $1;

	defined Array::find($args{$type.'_extensions'}, $ext);
}#

1;
# vim600:fdm=marker:fmr={my,}#:
