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
{my ($self, $path, $time) = @_;

	if ($path =~ /\.tags$/i) {
		$self->{tags}->add($path, $time);
	}
	else {
		croak "Duplicate file $path."  if exists $self->{files}->{$path};
	}

	$self->{files}->{$path} = 1;

	if (is_pic($path)  or is_vid($path)) {
		$self->{sel} = $path  if $self->sel_compare($path);
	}
}#

sub sel_compare
{my ($self, $path) = @_;

	return 1  unless defined $self->{sel} and -s $self->{sel};
	return 0  if !is_raw($self->{sel}) and  is_raw($path);
	return 1  if  is_raw($self->{sel}) and !is_raw($path);
	return 0  if !is_vid($self->{sel}) and  is_vid($path);
	return 1  if  is_vid($self->{sel}) and !is_vid($path);
	return -M $path > -M $self->{sel};
}#

sub open_folder
{my ($self) = @_;

	$self->{sel} =~ m{^(.*?/)[^/]+$}  or die;
	system "xdg-open \"$1\"";
}#

sub guess_source
{my ($self, $app) = @_;

	my %app_exts = (
		darktable => [ 'cr2', 'raf', 'jpg' ],
		ufraw => [ 'ufraw' ],
		gimp  => [ 'xcf', 'ppm', 'tif', 'png', 'jpg' ],
	);
	not $app or $app_exts{$app} or confess;

	foreach my $a ( $app
			? ( $app )
			: ( 'darktable', 'ufraw', 'gimp' )
	) {
		foreach my $ext (@{$app_exts{$a}}) {
			foreach (keys %{$self->{files}}) {
				/\.$ext$/ and -r and return $_;
			}
		}
	}

	return undef;
}#

sub develop
{my ($self, $app) = @_;

	my $file = $self->guess_source($app)  or return;

	my $cmd;
	if ($file =~ /\.ufraw$/i) {
		$cmd = "ufraw \"$file\" || gvim \"$file\"";
	}
	elsif ($file =~ /\.(cr2|raf)$/i) {
		$cmd = "darktable \"$file\"";
	}
	elsif (is_pic($file)) {
		$cmd = "gimp \"$file\" &";
	}
	else {
		return;
	}

	say $cmd  if dbg;

	my $ppm = $file; $ppm =~ s/\.[^.]+$/\.ppm/;
	my $M0 = -M $ppm;

	system $cmd;

	if ($cmd =~ /^ufraw /) {
		my $jpg = $file; $jpg =~ s/\.[^.]+$/\.jpg/;
		my $cr2 = $file; $cr2 =~ s/\.[^.]+$/\.cr2/;
		my $M1 = -M $ppm;
		if ($M1 and (not $M0 or $M0 != $M1)) { # new .ppm was created
			if (-s $jpg) { # jpg already exists
				if (-w $jpg) { # if it's writeable, remove
					unlink $jpg  and say "removed \"$jpg\"";
				}
				else { # if read-only, backup
					my $bk = $jpg; $bk =~ s/jpg$/original.jpg/;
					if (-s $bk and not -w $bk) { # backup already exists
						unlink $jpg  and say "\"$bk\" exists, \"$jpg\" removed";
					}
					else { # create backup
						unlink $bk  and say "\"$bk\" removed"  if -e $bk;
						rename $jpg, $bk  and say "\"$jpg\" -> \"$bk\"";
					}
				}
			}
			-e $jpg  and die "\"$jpg\" still exists";
			$cmd = "convert -sharpen 3x1 -quality 90 \"$ppm\" \"$jpg\" && exiftool -tagsFromFile \"$cr2\" \"$jpg\"";
			my $base = $jpg; $base =~ s{/([^/]+)$}{$1};
			$cmd = "notify-send sharpening...; $cmd && rm -v \"$ppm\" && notify-send \"$base\"";
			say $cmd;
			system $cmd;
		}
	}
}#

sub develop_pics
{my (@pics) = @_;

	my @raws = grep { $_ } map { $_->guess_source('darktable') } @pics;
	my $cmd = 'darktable '.join(' ', map { '"'.$_.'"' } @raws).' &';
	say $cmd  if dbg;
	system $cmd;
	FileItr->dirty();
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

	return  if $args{nop};

	my $afile = (keys %{$self->{files}})[0];
	$afile =~ m{^(.*?)/[^/]+$}
		or croak "Strange filename ($afile).";
	my $trash = "$1/.bapho-trash";
	-d $trash  or print `mkdir -v "$trash"`;
	my $files = join(' ', map { "\"$_\"" } sort keys %{$self->{files}});
	system "chmod +w $files";
	my $cmd = "mv -v $files \"$trash/\"";
	say $cmd;
	print `$cmd`;
}#

sub is_raw { pvt__is_pic_or_vid('raw', @_) }
sub is_pic { pvt__is_pic_or_vid('pic', @_) }
sub is_vid { pvt__is_pic_or_vid('vid', @_) }
sub is_pic_or_vid { is_pic(@_) or is_vid(@_) }

sub pvt__is_pic_or_vid
{my ($type, $self_or_path) = @_;
caller eq __PACKAGE__  or croak;

	my $x = $self_or_path;
	my $path = ref $x ? $x->{sel} : $x;

	$path =~ m{\.([^.]+)$}  or die;
	my $ext = lc $1;

	defined Array::find($args{$type.'_extensions'}, $ext);
}#

1;
# vim600:fdm=marker:fmr={my,}#:
