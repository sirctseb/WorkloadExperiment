package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

func datetimeFromString(stamp_string string) time.Time {

	// get a float of epoch time in seconds. have to divide by 1000 because dart timestamps are in ms
	var stamp, _ = strconv.ParseInt(stamp_string, 10, 64)

	// build a time object from the stamp
	return time.Unix(stamp/1000, (stamp%1000)*1000000)
}

/*
String replaceMatch(match) {
	return datetimeFromString(match.group(0)).toString();
}*/

func listToString(list []float64) string {
	stringslist := make([]string, len(list), len(list))
	for index, val := range list {
		stringslist[index] = fmt.Sprintf("%f", val)
	}
	return strings.Join(stringslist, ",")
}

func printResponseTimes(subject, trial int) {
	// read oral response times if they exist
	file, err := os.Open(fmt.Sprintf("output/subject%d/trial%d/responses.txt", subject, trial))
	if err == nil {
		// get the contents of the file
		contents, _ := ioutil.ReadAll(bufio.NewReader(file))
		responseTimeString := string(contents)
		// split into lines
		responseTimeStrings := strings.Split(responseTimeString, "\n")
		// make array for numerical version
		responseTimes := make([]float64, len(responseTimeStrings), len(responseTimeStrings))
		// subtract starting times to get actual response times
		for index, rts := range responseTimeStrings {
			rt, _ := strconv.ParseFloat(rts, 64)
			responseTimes[index] = rt - 5000.0*float64(index)
		}
		// print data
		fmt.Printf("responseTimes, %s\n", listToString(responseTimes))
		file.Close()
	} else {
		fmt.Printf("no responses file for subject %d, trial %d\n", subject, trial)
	}

}

func printTaskData(subject, trial int) {
	// read task description
	file, _ := os.Open(fmt.Sprintf("output/subject%d/trial%d/task.txt", subject, trial))
	contents, _ := ioutil.ReadAll(bufio.NewReader(file))
	trialDesc := string(contents)

	// discard "start trial: "
	trialDesc = trialDesc[len("start trial: "):len(trialDesc)]

	// parse json
	decoder := json.NewDecoder(strings.NewReader(trialDesc))
	var descObj map[string]interface{}
	decoder.Decode(&descObj)

	// print number of targets
	if numTargets, ok := descObj["numTargets"]; ok {
		fmt.Printf("number of targets, %d\n", int(numTargets.(float64)))
	} else {
		fmt.Printf("no number of targets found")
	}
	// print speed
	if speed, ok := descObj["targetDist"]; ok {
		fmt.Printf("speed, %d\n", int(speed.(float64)))
	}

	file.Close()
}

func printAccuracy(contents string) {
	// get number of clicks
	click_regex, _ := regexp.Compile(`MouseDown, `)
	clicks := len(click_regex.FindAllString(contents, -1))
		// get number of misses
	miss_regex, _ := regexp.Compile(`MouseDown, [\d.]+, \d+, \d+, MISS`)
	misses := len(miss_regex.FindAllString(contents, -1))
		// get number of hits
	hit_regex, _ := regexp.Compile(`TargetHit, `)
	hits := len(hit_regex.FindAllString(contents, -1))
		// print hit / miss info
	fmt.Printf("clicks, %d\n", clicks)
	fmt.Printf("misses, %d\n", misses)
	fmt.Printf("hits, %d\n", hits)
}

func main() {

	var subject, trial int

	// get subject and trial from command line ifassed
	flag.IntVar(&subject, "s", 5, "The number of the subject")
	flag.IntVar(&trial, "t", 1, "The trial number")
	flag.Parse()

	trials := []int{1,2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}

	for _, trial := range trials {

		// make file object
		file, _ := os.Open(fmt.Sprintf("output/subject%d/trial%d/data.txt", subject, trial))

		// get file contents
		buffer, _ := ioutil.ReadAll(bufio.NewReader(file))
		contents := string(buffer)

		// close file
		file.Close()

		// read and print task data
		printTaskData(subject, trial)

		// define rege for start of trial
		trial_start_regex, _ := regexp.Compile(`TrialStart, (\d{13})`)

		// get string of trial start time
		stamp_string := trial_start_regex.FindStringSubmatch(contents)[1]

		// get time object for start time
		startDate := datetimeFromString(stamp_string)

		// define function for replacing time stamps
		replaceFunc := func(match string) string {
			diff := datetimeFromString(match).Sub(startDate)
			return fmt.Sprintf("%f", diff.Seconds())
		}

		// define regex for time stamp
		date_regex, _ := regexp.Compile(`\d{13}`)
		// replace times stamps
		diffTimes := date_regex.ReplaceAllStringFunc(contents, replaceFunc)

		// print accuracy info
		printAccuracy(diffTimes)

		// read response time data and print
		printResponseTimes(subject, trial)

		// split contents into lines
		lines := strings.Split(diffTimes, "\n")

		// define regexes for target hits and starts
		hitRE, _ := regexp.Compile(`TargetHit, ([\d\.]+), `)
		startRE, _ := regexp.Compile(`TargetStart, ([\d\.]+), `)
		// make slice for hit times
		hitTimes := make([]float64, 0, 100)
		lastHitTime := 0.
		// compute hit times
		for _, line := range lines {
			match := hitRE.FindStringSubmatch(line)
			if len(match) > 0 {
				time, _ := strconv.ParseFloat(match[1], 64)
				hitTimes = append(hitTimes, time-lastHitTime)
				lastHitTime = time
			} else if strings.HasPrefix(line, "TargetStart") {
				lastHitTime, _ = strconv.ParseFloat(startRE.FindStringSubmatch(line)[1], 64)
			}
		}

		hitTimesString := listToString(hitTimes)

		fmt.Printf("hitTimes, %s\n", hitTimesString)

		// compute min max and mean
		/*min, max, mean := hitTimes[0], hitTimes[0], 0.
		for _, hitTime := range hitTimes {
			if hitTime < min {
				min = hitTime
			}
			if hitTime > max {
				max = hitTime
			}
			mean += hitTime
		}
		mean /= float64(len(hitTimes))
		fmt.Printf("%f, %f, %f\n", min, max, mean)

		// print historgram
		bucketSize := 0.2;
		for i := min; i <= max; i += bucketSize {
			fmt.Printf("%f: %s\n", i, strings.Repeat("x", CountBucket(hitTimes, i, i + bucketSize)))
		}*/
		fmt.Println()
	}
}
func CountBucket(values []float64, min, max float64) int {
	count := 0
	for _, val := range values {
		if min <= val && val < max {
			count++
		}
	}
	return count
}
