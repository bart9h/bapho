#!/usr/bin/perl
use strict;
use warnings;
use 5.010;
use Data::Dumper;

# usage: $0 class /initial/path
# class should implement new($path), seek($dir) and path()

sub test
{
	my $class = shift or die 'which module?';
	eval "require $class";
	my $i = $class->new($_[0] // $ENV{PWD}, $_[1]);
	my $dir = 1;
	my $dbg = 0;
	while(1) {
		print $i->path . ' > ';
		local $_ = <STDIN>;
		chomp;
		given ($_) {
			when (/^(help|\?)$/) {
				say 'q=quit, d=toggle dump, <[+/-]number>=direction, n|j=+1, p|k=-1';
				next;
			}
			when (/^$/) {
			}
			when (/^q$/) {
				last;
			}
			when (/^d$/) {
				print Dumper $i if $dbg = !$dbg;
				next;
			}
			when (/^(n|j)$/) {
				$dir = +1;
			}
			when (/^(p|k)$/) {
				$dir = -1;
			}
			when (/^([+-]?\d+)$/) {
				$dir = $1;
			}
			default {
				say '?';
				next;
			}
		}
		$i->seek($dir) or say "seek failed";
		print Dumper $i if $dbg;
	}
}

test(@ARGV);

