use Tie::File;

chomp(my $filename = $ARGV[0]);
tie my @array, 'Tie::File', $filename or die $!;

foreach (@array)
{
    # ...... line processing happens here .......
    # ...... $line is automatically written to fi# take extraneous lines out
	s/^\s*<(?!Snapshot|Item).*$//g;
	# take extraneous xml out
	# take out tag names
	s/^\s*<\w* //g;
	# take out attribute names
	s/Value\d="([^"]*)"/$1,/g;
	# take out closing braces
	s/,\s*\/?>//g;
}

untie @array