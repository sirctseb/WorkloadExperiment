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
	// make file object
	File logFile = new File.fromPath(new Path("output/subject1/trial1/data.txt"));

	// get contents
	String contents = logFile.readAsStringSync();
	

	// find trial start
	String stamp_string = new RegExp(r"TrialStart (\d{13})", multiLine: true).firstMatch(contents).group(1);

	print(contents.replaceAllMapped(new RegExp(r"\d{13}"), replaceMatch));
}