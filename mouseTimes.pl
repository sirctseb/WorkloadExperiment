#!/usr/bin/perl
use Getopt::Long;
use File::Copy;
use v5.10;

my $filename = nofile.txt;

# parse command line options
GetOptions('f=s' => \$filename);

# open result file
open(outputfile, ">" . $filename . ".times.txt");

# open input file
open(inputfile, "<" . $filename);

my $starttime = 0;

while(<inputfile>)
{
	# record movement start time
	if(/MOTOR\s*PREPARATION-COMPLETE/) {
		($starttime) = (/([\d*.\d*]+)\s*MOTOR/);
		# $starttime = $starttime + 0.2;
	}
	# print movement time
	if(/MOTOR\s*FINISH-MOVEMENT\s*move-cursor/) {
		($time) = (/([\d*.\d*]+)\s/);
		say "start ", $starttime;
		say "end ", $time;
		$time = $time - $starttime - 0.05;
		say "time ", $time;
		print outputfile $time . "\n";
	}
}

close(outputfile);
close(inputfile);
