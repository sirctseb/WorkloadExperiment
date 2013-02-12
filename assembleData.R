assembleData <- function(subject, ignorePractice=TRUE) {
	# get the filename for the main file
	mainfile <- sprintf("output/subject%d/r1.txt", subject)
	# read in the data
	mainData <<- read.table(mainfile, header=TRUE, sep=",", strip.white=TRUE)
	
	# force factor columns
	mainData$speed <<- as.factor(mainData$speed)
	mainData$difficulty <<- as.factor(mainData$difficulty)
	
	# separate the addition-only trials
	additionData <<- mainData[mainData$targets == 0, ]
	mainData <<- mainData[mainData$targets != 0, ]
	
	# get rid of targets columns as it is all 3 or 0
	mainData$targets <<- NULL
	additionData$targets <<- NULL
	
	# get rid of speed, difficulty, and target columns from addition data
	additionData$speed <<- NULL
	additionData$difficulty <<- NULL
	additionData$target <<- NULL
	# remove empty levels
	additionData$oprange <<- factor(additionData$oprange)
	
	# separate targeting-only trials
	targetingData <<- mainData[mainData$oprange == "[]", ]
	mainData <<- mainData[mainData$oprange != "[]", ]

	# remove empty factors
	mainData$oprange <<- factor(mainData$oprange)
	
	# prepare the separated data
	mainDatasss <<- split(mainData, list(mainData$speed, mainData$oprange, mainData$difficulty))
	
	# show boxplot of main data
	#boxplot(complete~targets*speed*oprange, mainData, notch=TRUE)
	if(ignorePractice) {
		firstindex = 13
	} else {
		firstindex = 1
	}
	oprangeLow = levels(additionData$oprange)[1]
	oprangeHigh = levels(additionData$oprange)[2]
	# get the mean of the low addition only tasks
	additionLowMean <<- mean(additionData[additionData$oprange==levels(additionData$oprange)[1], ]$complete[firstindex:36])
	# get the mean of the high addition only tasks
	additionHighMean <<- mean(additionData[additionData$oprange==levels(additionData$oprange)[2], ]$complete[firstindex:36])
	
	# get the mean of the low, low targeting only tasks
	speedLow = levels(targetingData$speed)[1]
	speedHigh = levels(targetingData$speed)[2]
	difficultyLow = levels(targetingData$difficulty)[1]
	difficultyHigh = levels(targetingData$difficulty)[2]
	targetLowLowMean <<- mean(targetingData[targetingData$speed == speedLow & targetingData$difficulty == difficultyLow, ]$complete[firstindex:36])
	# get the mean of the low, high targeting only tasks
	targetLowHighMean <<- mean(targetingData[targetingData$speed == speedLow & targetingData$difficulty == difficultyHigh, ]$complete[firstindex:36])
	# get the mean of the high, low targeting only tasks
	targetHighLowMean <<- mean(targetingData[targetingData$speed == speedHigh & targetingData$difficulty == difficultyLow, ]$complete[firstindex:36])
	# get the mean of the low, low targeting only tasks
	targetHighHighMean <<- mean(targetingData[targetingData$speed == speedHigh & targetingData$difficulty == difficultyHigh, ]$complete[firstindex:36])

	# compute concurrency
	mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeLow] <<-
		getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeLow], additionLowMean, targetLowLowMean)
	mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeLow] <<-
		getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeLow], additionLowMean, targetHighLowMean)
	mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeLow] <<-
		getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeLow], additionLowMean, targetLowHighMean)
	mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeLow] <<-
		getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeLow], additionLowMean, targetHighHighMean)
	mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeHigh] <<-
		getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeHigh], additionHighMean, targetLowLowMean)
	mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeHigh] <<-
		getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeHigh], additionHighMean, targetHighLowMean)
	mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeHigh] <<-
		getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeHigh], additionHighMean, targetLowHighMean)
	mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeHigh] <<-
		getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeHigh], additionHighMean, targetHighHighMean)
}

getConcurrencyVec <- function(completionTimes, additionTime, targetTime) {
	# low value
	low = max(additionTime, targetTime)
	# high value
	high = additionTime + targetTime
	return ((completionTimes - high) / (low - high))
}