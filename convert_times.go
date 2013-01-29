package main

import (
	"bufio"
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

func main() {

	var subject, trial int

	// get subject and trial from command line ifassed
	flag.IntVar(&subject, "s", 5, "The number of the subject")
	flag.IntVar(&trial, "t", 1, "The trial number")
	flag.Parse()

	trials := []int{3,4,5,6,7,8,9,10,11,12}

	for _, trial := range trials {

		// make file object
		file, _ := os.Open(fmt.Sprintf("output/subject%d/trial%d/data.txt", subject, trial))


		// get file contents
		buffer, _ := ioutil.ReadAll(bufio.NewReader(file))
		contents := string(buffer)

		// close file
		file.Close()

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

		// get number of clicks
		click_regex, _ := regexp.Compile(`MouseDown, `)
		clicks := len(click_regex.FindAllString(diffTimes, -1))
		// get number of misses
		miss_regex, _ := regexp.Compile(`MouseDown, [\d.]+, \d+, \d+, MISS`)
		misses := len(miss_regex.FindAllString(diffTimes, -1))
		// get number of hits
		hit_regex, _ := regexp.Compile(`TargetHit, `)
		hits := len(hit_regex.FindAllString(diffTimes, -1))
		// print hit / miss info
		fmt.Printf("clicks, %d\n", clicks)
		fmt.Printf("misses, %d\n", misses)
		fmt.Printf("hits, %d\n", hits)


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

		hitTimesStrings := make([]string, len(hitTimes), len(hitTimes))
		for index, hT := range hitTimes {
			hitTimesStrings[index] = fmt.Sprintf("%f", hT)
		}

		fmt.Printf("hitTimes, %s\n", strings.Join(hitTimesStrings, ","))

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