#!/usr/bin/env dart
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
	int subject = 1, trial = 3;

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
	String stamp_string = new RegExp(r"TrialStart, (\d{13})", multiLine: true).firstMatch(contents).group(1);

	Date startDate = datetimeFromString(stamp_string);

	var replaceFunc = (Match match) {
		//print(match.groupCount);
		Duration diff = datetimeFromString(match.group(0)).difference(startDate);
		num seconds = diff.inSeconds + (diff.inMilliseconds % 1000) / 1000; 
		return seconds.toString();
	};

	var diffTimes = contents.replaceAllMapped(new RegExp(r"\d{13}"), replaceFunc);
//	print(diffTimes);

	// get number of clicks
	int clicks = new RegExp(r"MouseDown, ").allMatches(diffTimes).length;
	// get number of misses
	int misses = new RegExp(r"MouseDown, [\d.]+, \d+, \d+, MISS").allMatches(diffTimes).length;
	// get number of hits
	int hits = new RegExp(r"TargetHit, ").allMatches(diffTimes).length;
	// print hit / miss info
	print("clicks, $clicks");
	print("misses, $misses");
	print("hits, $hits");
//	print("miss rate: ${misses / clicks}");
//	print("hit rate: ${hits / clicks}");

	// get individual lines
	var lines = diffTimes.split("\n");
	var state = "hit";
	var match;
	RegExp hitRE = new RegExp(r"TargetHit, ([\d.]+), ");
	RegExp startRE = new RegExp(r"TargetStart, ([\d.]+), ");
	List<num> hitTimes = [];
	num lastHitTime;
	// iterate over lines
	lines.forEach((line) {
//		print(line);
		match = hitRE.firstMatch(line);
		if(match != null) {
			num time = double.parse(match.group(1));
			//print(lastHitTime);
			hitTimes.add(time - lastHitTime);
			lastHitTime = time;
		} else if(line.startsWith("TargetStart")) {
			state = "firsthit";
			// update last hit time on new target because the timer doesn't reset
			lastHitTime = double.parse(startRE.firstMatch(line).group(1));
		}
	});
	print("hitTimes, ${hitTimes.join(",")}");
	/*var min = hitTimes.min();
	print("min: $min");
	var max = hitTimes.max();
	print("max: $max");
	print("mean: ${hitTimes.reduce(0, (prev, el) => prev + el) / hitTimes.length}");
	var bucketSize = 0.2;
	for(num i = min; i <= max; i += bucketSize) {
		int count = hitTimes.where((time) => i < time && time < i + bucketSize).length;
		print("${i.toStringAsPrecision(2)}: ${new String.fromCharCodes([]..insertRange(0, count, "x".charCodeAt(0)))}");
	}*/
}