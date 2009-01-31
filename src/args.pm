package args;

use base 'Exporter';
our @EXPORT = qw(%args);

our %args = (
		basedir => $ENV{HOME}.'/fotos',
		dir_fmt => '%04d/%02d-%02d',
		jpeg_quality => 80,
		mv => 1,
		verbose => 1,
		geometry => undef,
		fullscreen => 0,
);

