open(logfile, "<log.txt");
open(outfile, ">out.txt");
while(<logfile>)
{
	my($line) = $_;
	$match = s/([^,]*, )([^,\n]*)(.*)/$1 . int($2*1000) . $3/e;
	print outfile $_;
}