open(logfile, "<log.txt");
open(outfile, ">out.txt");
sub lpad {
	my($str) = $_[0];
	my($len) = length($str);
	return (0 x (13 - $len) . $str);
}
while(<logfile>)
{
	my($line) = $_;
	$match = s/([^,]*, )([^,\n]*)(.*)/$1 . lpad(int($2*1000)) . $3/e;
	print outfile $_;
}