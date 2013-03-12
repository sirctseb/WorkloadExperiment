package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"github.com/skelterjohn/geom"
	"io/ioutil"
	"math"
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

func printResponseTimes(subject int, block, trial string) {
	// read oral response times if they exist
	file, err := os.Open(fmt.Sprintf("output/subject%d/%s/%s/responses.txt", subject, block, trial))
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
			responseTimes[index] = (rt - 5000.0*float64(index)) / 1000
		}
		// print data
		fmt.Printf("responseTimes, %s\n", listToString(responseTimes))
		file.Close()
	} else {
		fmt.Printf("no responses file for subject %d, block %s, trial %s\n", subject, block, trial)
	}

}

type Target struct {
	ID        int
	startX    float64
	startY    float64
	endX      float64
	endY      float64
	startTime float64
	endTime   float64
}

// get the fraction of the way through the target's existence at the given time
func (t Target) TimeParam(time float64) float64 {
	return (time - t.startTime) / (t.endTime - t.startTime)
}

// get the start point of the target
func (t Target) StartPoint() geom.Coord {
	return geom.Coord{t.startX, t.startY}
}

// get the end point of the target
func (t Target) EndPoint() geom.Coord {
	return geom.Coord{t.endX, t.endY}
}

// get the center point of the target at a given time
func (t Target) Center(time float64) geom.Coord {
	timeParam := t.TimeParam(time)
	// interpolate
	return t.StartPoint().Plus(t.EndPoint().Minus(t.StartPoint()).Times(timeParam))
}

// get the top left point of the target at a given time
func (t Target) TopLeft(time float64) geom.Coord {
	return t.Center(time).Minus(geom.Coord{64, 64})
}

// get the bottom right point of the target at a given time
func (t Target) BottomRight(time float64) geom.Coord {
	return t.Center(time).Plus(geom.Coord{64, 64})
}

// get the target rectangle of a target at a given time
func (t Target) Rect(time float64) geom.Rect {
	// create rectangle
	return geom.Rect{t.TopLeft(time), t.BottomRight(time)}
}

// test if a target contains a point at a given time
func (t Target) Contains(time float64, point geom.Coord) bool {
	return t.Rect(time).ContainsCoord(point)
}

func parseResults(lines []string, targets int) map[string][]float64 {
	// define regexes for target hits and starts
	hitRE, _ := regexp.Compile(`TargetHit, ([\d\.]+), `)
	startRE, _ := regexp.Compile(`TargetStart, ([\d\.]+), `)
	additionRE, _ := regexp.Compile(`AdditionCorrect, ([\d\.]+)`)
	taskCompleteRE, _ := regexp.Compile(`TasksComplete, ([\d\.]+), `)
	iterationEndRE, _ := regexp.Compile(`IterationEnd, ([\d\.]+)`)
	friendHitRE, _ := regexp.Compile(`FriendHit, `)
	shotRE, _ := regexp.Compile(`MouseDown, `)
	//trialStartRE, _ := regexp.Compile(`TrialStart, ([\d\.]+)`)

	// make slice for hit times
	hitTimes := make([]float64, 0, 100)
	// make slice for additiont imes
	additionTimes := make([]float64, 0, 100)
	// make slice for task completion times
	taskCompleteTimes := make([]float64, 0, 100)
	// make slice for final hit times
	finalHitTimes := make([]float64, 0, 100)
	// make slice for number of hits
	numberHits := make([]float64, 0, 100)
	// make slice for number of friendly hits
	numberFriendHits := make([]float64, 0, 100)
	// make slice for number of shots taken
	numberShots := make([]float64, 0, 100)

	// variables for accumulating totals and keeping state
	iterationStartTime := 0.
	lastHitTime := 0.
	tasksComplete := false
	additionComplete := false
	targetsHit := 0
	friendTargetsHit := 0
	shots := 0

	// compute hit times
	for _, line := range lines {
		// check for target hit match
		match := hitRE.FindStringSubmatch(line)
		if len(match) > 0 {
			// find the time of the hit
			time, _ := strconv.ParseFloat(match[1], 64)
			// compute and store the target hit time from the start or last hit time
			hitTimes = append(hitTimes, time-lastHitTime)
			// update the last hit time
			lastHitTime = time
			// increment number of targets hit
			targetsHit++
			// if this is the last hit of the iteration, append it to last hit array
			if targetsHit == targets {
				finalHitTimes = append(finalHitTimes, time-iterationStartTime)
			}
		} else if strings.HasPrefix(line, "TargetStart") {
			// check for target start event

			// get time of event and set lastHitTime
			lastHitTime, _ = strconv.ParseFloat(startRE.FindStringSubmatch(line)[1], 64)
			// update the iteration start time when we find a new target start
			iterationStartTime = lastHitTime
		} else if match = additionRE.FindStringSubmatch(line); len(match) > 0 {
			// check for addition task end

			// get time of event
			time, _ := strconv.ParseFloat(match[1], 64)
			// compute and store time since iteration start
			additionTimes = append(additionTimes, time-iterationStartTime)
			// set addition complete flag
			additionComplete = true
		} else if match = taskCompleteRE.FindStringSubmatch(line); len(match) > 0 {
			// check for tasks complete

			// get time of event
			time, _ := strconv.ParseFloat(match[1], 64)
			// compute and store time since iteration start
			taskCompleteTimes = append(taskCompleteTimes, time-iterationStartTime)
			// set flag that tasks are complete
			tasksComplete = true
		} else if match = iterationEndRE.FindStringSubmatch(line); len(match) > 0 {
			// check for iteration end

			// if tasks are not complete by the time we hit iteration end, set completion time
			// to 5
			// TODO this depends on 5 second iterations. we should make this look it up
			if !tasksComplete {
				taskCompleteTimes = append(taskCompleteTimes, 5.)
			}
			// if addition not complete by the time we hit iteration end, set addiion time
			// to 5
			// TODO this depends on 5 second iterations. we should make this look it up
			if !additionComplete {
				additionTimes = append(additionTimes, 5.)
			}
			// if targeting not complete by the time we hit iteration end, set final hit time
			// to 5
			// TODO this depends on 5 second iterations. we should make this look it up
			if targetsHit < targets {
				finalHitTimes = append(finalHitTimes, 5.)
			}

			// store number of targets hit
			numberHits = append(numberHits, float64(targetsHit))
			// store number of friend targets hit
			numberFriendHits = append(numberFriendHits, float64(friendTargetsHit))
			// store number of shots taken
			numberShots = append(numberShots, float64(shots))

			// TODO should also fill 5s for incomplete target tasks
			// reset tasks Complete
			tasksComplete = false
			// reset addition complete flag
			additionComplete = false
			// reset number of targets hit
			targetsHit = 0
			// reset number of friend targets hit
			friendTargetsHit = 0
			// reset number of shots taken
			shots = 0

			// reset iteration start time
			iterationStartTime, _ = strconv.ParseFloat(match[1], 64)
		} else if friendHitRE.MatchString(line) {
			friendTargetsHit++
		} else if shotRE.MatchString(line) {
			shots++
		}
	}
	return map[string][]float64{"hit": hitTimes, "addition": additionTimes, "complete": taskCompleteTimes, "finalHit": finalHitTimes,
		"hits": numberHits, "friendHits": numberFriendHits, "shots": numberShots}
}

func printHitAndAdditionTimes(lines []string, targets int) {
	results := parseResults(lines, targets)
	//hitTimes := results["hit"]
	//additionTimes := results["addition"]
	taskCompleteTimes := results["complete"]

	//hitTimesString := listToString(hitTimes)
	//additionTimesString := listToString(additionTimes)
	taskCompleteTimesString := listToString(taskCompleteTimes)

	//fmt.Printf("hitTimes, %s\n", hitTimesString)
	//fmt.Printf("additionTimes, %s\n", additionTimesString)
	fmt.Printf("%s", taskCompleteTimesString)

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

func getTaskDataObject(subject int, block, trial string) map[string]interface{} {
	// read task description
	file, _ := os.Open(fmt.Sprintf("output/subject%d/%s/%s/task.txt", subject, block, trial))
	contents, _ := ioutil.ReadAll(bufio.NewReader(file))
	file.Close()
	trialDesc := string(contents)

	// discard "start trial: "
	trialDesc = trialDesc[len("start trial: "):len(trialDesc)]

	// parse json
	decoder := json.NewDecoder(strings.NewReader(trialDesc))
	var descObj map[string]interface{}
	decoder.Decode(&descObj)

	return descObj
}
func printTaskData(subject int, block, trial string) {
	descObj := getTaskDataObject(subject, block, trial)

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
	// print operand range
	if opRange, ok := descObj["opRange"]; ok {
		fmt.Printf("op range, %v\n", opRange)
	}

}

func printRHeader() {
	// TODO we should really read this from the file in case any of the parameters change
	//fmt.Println("targets, speed, oprange, et1, et2, et3, et4, et5, et6, et7, et8, et9, et10, et11, et12")
	fmt.Println("practice, targets, speed, oprange, difficulty, addition, target, complete, hits, friendHits, shots")
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

func trialsInDir(dirname string) []string {
	return getDirsInDirWithPrefix(dirname, "trial")
}

func blocksInDir(dirname string) []string {
	return getDirsInDirWithPrefix(dirname, "block")
}
func getDirsInDirWithPrefix(dirname, prefix string) []string {
	// get file info slice
	fileInfos, err := ioutil.ReadDir(dirname)
	if err != nil {
		fmt.Errorf("Could not read contents of %s", dirname)
		return nil
	}
	// make name slice
	names := make([]string, 0, len(fileInfos))
	// fill name slice
	for _, fi := range fileInfos {
		if strings.HasPrefix(fi.Name(), prefix) {
			names = append(names, fi.Name())
		}
	}
	return names
}

type IVLevels struct {
	TargetNumber       int
	TargetSpeed        int
	AdditionDifficulty []int
	TargetDifficulty   int
	Practice           bool
}

func getBlockIVLevels(subject int, block string) *IVLevels {
	// get file object
	if fi, err := os.Open(fmt.Sprintf("output/subject%d/%s/block.txt", subject, block)); err == nil {
		//decoder := json.NewDecoder(bufio.NewReader(fi))
		bytes, _ := ioutil.ReadAll(bufio.NewReader(fi))

		var levels *IVLevels = new(IVLevels)
		//if decoder.Decode(&levels) == nil {
		if json.Unmarshal(bytes, levels) == nil {
			return levels
		} /* else {
			fmt.Printf("could not decode levels from %s", string(bytes))
		}*/
	} else {
		fmt.Printf("could not open block desc file output/subject%d/%s/block.txt", subject, block)
	}
	return nil
}

func main() {

	var subject int
	var practice bool
	var blockName string
	var trialNum int

	// get subject and trial from command line ifassed
	flag.IntVar(&subject, "s", 5, "The number of the subject")
	//	flag.IntVar(&trial, "t", 1, "The trial number")
	//flag.BoolVar(&practice, "practice", false, "Set to produce variables for practice blocks")
	flag.BoolVar(&practice, "practice", false, "set to practice")
	flag.StringVar(&blockName, "block", "", "Specify a block to output")
	flag.IntVar(&trialNum, "trial", -1, "Specify a trial to output")
	flag.Parse()

	var blocks []string
	if blockName == "" {
		blocks = blocksInDir(fmt.Sprintf("output/subject%d", subject))
	} else {
		blocks = []string{blockName}
	}

	// print header
	printRHeader()

	var levels *IVLevels

	for _, block := range blocks {

		// get block IV levels now if we're not in practice block
		levels = getBlockIVLevels(subject, block)

		//	trials := []int{1,2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
		var trials []string
		if trialNum == -1 {
			trials = trialsInDir(fmt.Sprintf("output/subject%d/%s", subject, block))
		} else {
			trials = []string{fmt.Sprintf("trial%d", trialNum)}
		}

		for _, trial := range trials {

			// print subject and trial
			//fmt.Printf("subject, %d, block %s, trial, %s\n", subject, block, trial)

			// make file object
			file, _ := os.Open(fmt.Sprintf("output/subject%d/%s/%s/data.txt", subject, block, trial))

			// get file contents
			buffer, _ := ioutil.ReadAll(bufio.NewReader(file))
			contents := string(buffer)

			// close file
			file.Close()

			// read and print task data
			//printTaskData(subject, block, trial)

			// define rege for start of trial
			trial_start_regex, _ := regexp.Compile(`TrialStart, (\d{13})`)

			// get string of trial start time
			stamp_string := trial_start_regex.FindStringSubmatch(contents)[1]

			// get time object for start time
			startDate := datetimeFromString(stamp_string)

			// define function for replacing time stamps
			replaceFunc := func(match string) string {
				diff := datetimeFromString(strings.TrimSpace(match)).Sub(startDate)
				return fmt.Sprintf(" %f", diff.Seconds())
			}

			// define regex for time stamp
			date_regex, _ := regexp.Compile(` \d{13}`)
			// replace times stamps
			diffTimes := date_regex.ReplaceAllStringFunc(contents, replaceFunc)

			// print accuracy info
			//printAccuracy(diffTimes)

			// read response time data and print
			//printResponseTimes(subject, block, trial)

			// split contents into lines
			lines := strings.Split(diffTimes, "\n")

			//fmt.Println("split strings, about to to hits and additions")

			// TODO get this to work with practice blocks
			if levels != nil {
				var enemyTargets int = int(math.Ceil(float64(levels.TargetNumber) / 2))
				//printHitAndAdditionTimes(lines, targets)
				times := parseResults(lines, enemyTargets)
				// fill with zeros if data not present
				if len(times["addition"]) == 0 {
					times["addition"] = []float64{0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.}
				}
				if len(times["finalHit"]) == 0 {
					times["finalHit"] = []float64{0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.}
				}
				if len(times["complete"]) != 12 || len(times["addition"]) != 12 || len(times["finalHit"]) != 12 ||
					len(times["hits"]) != 12 || len(times["friendHits"]) != 12 || len(times["shots"]) != 12 {
					panic("one or more variables do not have 12 elements")
				}

				// TODO magic number 12 iterations should be looked up
				for index := 0; index < 12; index++ {
					fmt.Printf("%t, %d, %d, %v, %d, %f, %f, %f, %d, %d, %d\n",
						levels.Practice,
						levels.TargetNumber, levels.TargetSpeed, levels.AdditionDifficulty, levels.TargetDifficulty,
						times["addition"][index], times["finalHit"][index], times["complete"][index], int(times["hits"][index]),
						int(times["friendHits"][index]), int(times["shots"][index]))
				}
			}
		}
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
