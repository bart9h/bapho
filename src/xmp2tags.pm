package xmp2tags;

use strict;
use warnings;
use 5.010;
use File::Find;
sub getenv { defined $ENV{$_[0]} ? $ENV{$_[0]} : defined $_[1] ? $_[1] : '' }


sub convert
{my ($args) = @_;

	find(
		{
			no_chdir => 1,
			wanted => sub {
				if (not -d and m{^(.*)\.xmp$}) {
					my $xmp_path = $_;
					my $id = PictureItr::path2id($xmp_path);

					if (open my $fd, '<', $xmp_path) {
						foreach (<$fd>) {
							if (m{^\s*xmp:Rating="([^"]+?)"\s*$}) {
								say "##### $xmp_path ==> $1";
								my $tags = Tags->new($id);
								$tags->set_nstars ($1);
								last;
							}
						}
						close $fd;
					}
				}
			},
		},
		@$args
	);
}#

1;
# vim600:fdm=marker:fmr={my,}#:
