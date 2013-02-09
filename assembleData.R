assembleData <- function(subject) {
	# get the filename for the main file
	mainfile <- sprintf("dart/WorkloadExperiment/output/subject%d/r1.txt", subject)
	# read in the data
	mainData <<- read.table(mainfile, header=TRUE, sep=",", strip.white=TRUE)
	# prepare the separated data
	mainDatasss <<- split(mainData, list(mainData$targets, mainData$speed, mainData$oprange))
	
	# get the filename for the first practice file
	practiceFile1 <- sprintf("dart/WorkloadExperiment/output/subject%d/p1.txt", subject)
	# read in the data
 	practice1Data <<- read.table(practiceFile1, header=TRUE, sep=",", strip.white=TRUE)
	# remove the empty columns
	practice1Data$targets <<- NULL
	practice1Data$speed <<- NULL
	practice1Data$target <<- NULL
	# prepare the separated data
	practice1Datas <<- split(practice1Data, practice1Data$oprange)
	
	# get the filename for the second practice file
	practiceFile2 <- sprintf("dart/WorkloadExperiment/output/subject%d/p2.txt", subject)
	# read in the data
	practice2Data <<- read.table(practiceFile2, header=TRUE, sep=",", strip.white=TRUE)
	# remove the empty columns
	practice2Data$oprange <<- NULL
	practice2Data$addition <<- NULL
	# prepare the separated data
	practice2Datass <<- split(practice2Data, practice2Data$targets, practice2Data$speed)
	
	# show boxplot of main data
	#boxplot(complete~targets*speed*oprange, mainData, notch=TRUE)
	
	# get the mean of the low addition only tasks
	additionLowMean <<- mean(practice1Data[practice1Data$oprange=="low", ]$complete)
	# get the mean of the high addition only tasks
	additionHighMean <<- mean(practice1Data[practice1Data$oprange=="high", ]$complete)
	
	# get the mean of the low, low targeting only tasks
	# TODO levels are hard coded and need to change if we change the values
	targetLowLowMean <<- mean(practice2Data[practice2Data$targets == 2 & practice2Data$speed == 400, ]$complete)
	# get the mean of the low, high targeting only tasks
	targetLowHighMean <<- mean(practice2Data[practice2Data$targets == 2 & practice2Data$speed == 800, ]$complete)
	# get the mean of the high, low targeting only tasks
	targetHighLowMean <<- mean(practice2Data[practice2Data$targets == 3 & practice2Data$speed == 400, ]$complete)
	# get the mean of the low, low targeting only tasks
	targetHighHighMean <<- mean(practice2Data[practice2Data$targets == 3 & practice2Data$speed == 800, ]$complete)
	
	# compute concurrency for lll
	mainData$concurrency[mainData$targets=="low" & mainData$speed=="low" & mainData$oprange=="low"] <<-
		getConcurrencyVec(mainData$complete[mainData$targets=="low" & mainData$speed=="low" & mainData$oprange=="low"], additionLowMean, targetLowLowMean)
	mainData$concurrency[mainData$targets=="high" & mainData$speed=="low" & mainData$oprange=="low"] <<-
		getConcurrencyVec(mainData$complete[mainData$targets=="high" & mainData$speed=="low" & mainData$oprange=="low"], additionLowMean, targetHighLowMean)
	mainData$concurrency[mainData$targets=="low" & mainData$speed=="high" & mainData$oprange=="low"] <<-
		getConcurrencyVec(mainData$complete[mainData$targets=="low" & mainData$speed=="high" & mainData$oprange=="low"], additionLowMean, targetLowHighMean)
	mainData$concurrency[mainData$targets=="high" & mainData$speed=="high" & mainData$oprange=="low"] <<-
		getConcurrencyVec(mainData$complete[mainData$targets=="high" & mainData$speed=="high" & mainData$oprange=="low"], additionLowMean, targetHighHighMean)
	mainData$concurrency[mainData$targets=="low" & mainData$speed=="low" & mainData$oprange=="high"] <<-
		getConcurrencyVec(mainData$complete[mainData$targets=="low" & mainData$speed=="low" & mainData$oprange=="high"], additionHighMean, targetLowLowMean)
	mainData$concurrency[mainData$targets=="high" & mainData$speed=="low" & mainData$oprange=="high"] <<-
		getConcurrencyVec(mainData$complete[mainData$targets=="high" & mainData$speed=="low" & mainData$oprange=="high"], additionHighMean, targetHighLowMean)
	mainData$concurrency[mainData$targets=="low" & mainData$speed=="high" & mainData$oprange=="high"] <<-
		getConcurrencyVec(mainData$complete[mainData$targets=="low" & mainData$speed=="high" & mainData$oprange=="high"], additionHighMean, targetLowHighMean)
	mainData$concurrency[mainData$targets=="high" & mainData$speed=="high" & mainData$oprange=="high"] <<-
		getConcurrencyVec(mainData$complete[mainData$targets=="high" & mainData$speed=="high" & mainData$oprange=="high"], additionHighMean, targetHighHighMean)
}

getConcurrencyVec <- function(completionTimes, additionTime, targetTime) {
	# low value
	low = max(additionTime, targetTime)
	# high value
	high = additionTime + targetTime
	return ((completionTimes - high) / (low - high))
}