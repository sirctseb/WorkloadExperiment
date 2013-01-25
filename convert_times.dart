import "dart:io";
//from datetime import datetime;
//import time;


Date datetimeFromString(stamp_string) {

	// get a float of epoch time in seconds. have to divide by 1000 because dart timestamps are in ms
	var stamp = int.parse(stamp_string);

	// build a datetime object from the stamp
	return new Date.fromMillisecondsSinceEpoch(stamp);
}
	
String replaceMatch(match) {
	return datetimeFromString(match.group(0)).toString();
}


void main() {
	int subject = 1, trial = 1;

	// get subject and trial from command line if passed
	var args = new Options().arguments;
	if(args.length > 0) {
		subject = args[0];
	}
	if(args.length > 1) {
		trial = args[1];
	}

	// make file object
	File logFile = new File.fromPath(new Path("output/subject${subject}/trial${trial}/data.txt"));

	// get contents
	String contents = logFile.readAsStringSync();
	
	// find trial start
	String stamp_string = new RegExp(r"TrialStart (\d{13})", multiLine: true).firstMatch(contents).group(1);

	Date startDate = datetimeFromString(stamp_string);

	var replaceFunc = (Match match) {
	  //print(match.groupCount);
	  Duration diff = datetimeFromString(match.group(0)).difference(startDate);
	  num seconds = diff.inSeconds + (diff.inMilliseconds % 1000) / 1000; 
		return seconds.toString();
	};

	print(contents.replaceAllMapped(new RegExp(r"\d{13}"), replaceFunc));
}