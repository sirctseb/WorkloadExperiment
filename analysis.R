# get a data frame from a table
getDF <- function(data, tablename) {
	data[[tablename]]
}
# combine data from multiple subjects into one data frame
combineData <- function(data, tablename) {
	i <- 1
	ldply(data,
		function(d) {
			res <- cbind(eval(substitute(tablename), d), subject = i);
			i <<- i + 1
			res
		}
	)
}
# load subject data into a list
loadSubjectData <- function(subjects) {
	llply(subjects, assembleData);
}
# get a vertical cross section of data
# i.e. the addition, targeting, and dual-task data for a given subject
getVertical <- function(data, subject) {
	rmerge(data.frame(data[[subject]]$addition, type="addition"), data.frame(data[[subject]]$targeting, type="targeting"), data.frame(data[[subject]]$main, type="main"))
}
# combine the dataframes in a list into one datafram
getAll <- function(data, subjects) {
	do.call(rmerge, llply(subjects, function(subject) {getVertical(data, subject)}));
}
# get the addition, targeting, and dual-task data for a given (oprange, speed, difficulty) condition
getVertCase <- function(data, difficultyLevel, speedLevel, oprangeLevel) {
	# be forgiving with level names
	if(oprangeLevel == 0 | oprangeLevel == "low") oprangeLevel = "[1 12]";
	if(oprangeLevel == 1 | oprangeLevel == "high") oprangeLevel = "[13 24]";
	if(speedLevel == 1 | speedLevel == "high") speedLevel = 200;
	# get subset
	subset(data, (difficulty == difficultyLevel | is.na(difficulty)) &
				 (speed == speedLevel | is.na(speed)) &
				 (oprange == oprangeLevel | is.na(oprange)));
}
# plot the completion times for the addition, targeting, and combined tasks from a vertical case data frame
plotVert <- function(data) {
	ggplot(data, aes(complete, fill=type)) + geom_histogram(pos="dodge")
}

# bind dataframes into one with the columns that they all share
rmerge <- function(...) {
	cols <- Reduce(intersect, llply(list(...), colnames))
	Reduce(rbind, llply(list(...), function (df) {df[,cols, drop=FALSE]}))
}

# load the data for a single subject into separate data frames for addition, targeting, and dual-task,
# and return them in a list
assembleData <- function(subject) {
	# get the filename for the main file
	mainfile <- sprintf("output/subject%d/r1.txt", subject)
	# read in the data
	mainData <- read.table(mainfile, header=TRUE, sep=",", strip.white=TRUE)
	mainData$subject <- subject

	# separate practice data from experimental data
	practiceData <- mainData[mainData$practice == "true", ]
	mainData <- mainData[mainData$practice == "false", ]

	# force factor columns
	mainData$speed <- as.factor(mainData$speed)
	mainData$difficulty <- as.factor(mainData$difficulty)
	
	# separate the addition-only trials
	additionData <- mainData[mainData$targets == 0, ]
	mainData <- mainData[mainData$targets != 0, ]
	
	# get rid of targets columns as it is all 3 or 0
	mainData$targets <- NULL
	additionData$targets <- NULL
	
	# get rid of speed, difficulty, and target columns from addition data
	additionData$speed <- NA
	additionData$difficulty <- NA
	additionData$target <- NA
	# get rid of targeting accuracy columns from addition data
	additionData$hits <- NA
	additionData$friendHits <- NA
	additionData$shots <- NA
	# remove empty levels
	additionData$oprange <- factor(additionData$oprange)

	# add targeting accuracy fraction column to remaining data
	mainData$accuracy <- mainData$hits / mainData$shots
	
	# separate targeting-only trials
	targetingData <- mainData[mainData$oprange == "[]", ]
	targetingData$oprange <- NA
	mainData <- mainData[mainData$oprange != "[]", ]

	# remove empty factors
	mainData$oprange <- factor(mainData$oprange)
	
	# prepare the separated data
	mainDatasss <- split(mainData, list(mainData$speed, mainData$oprange, mainData$difficulty))

	if(nrow(additionData) > 0) {

		# show boxplot of main data
		#boxplot(complete~targets*speed*oprange, mainData, notch=TRUE)
		oprangeLow = levels(additionData$oprange)[1]
		oprangeHigh = levels(additionData$oprange)[2]
		# get the mean of the low addition only tasks
		additionLowMean <- mean(additionData[additionData$oprange==levels(additionData$oprange)[1], ]$complete)
		# get the mean of the high addition only tasks
		additionHighMean <- mean(additionData[additionData$oprange==levels(additionData$oprange)[2], ]$complete)
		# put in dataframe
		additionMeans <- data.frame(oprange = levels(additionData$oprange), mean = c(additionLowMean, additionHighMean))
	}

	if(nrow(targetingData) > 0) {
		# get the mean of the low, low targeting only tasks
		speedLow = levels(targetingData$speed)[1]
		speedHigh = levels(targetingData$speed)[2]
		difficultyLow = levels(targetingData$difficulty)[1]
		difficultyHigh = levels(targetingData$difficulty)[2]
		targetLowLowMean <- mean(targetingData[targetingData$speed == speedLow & targetingData$difficulty == difficultyLow, ]$complete)
		# get the mean of the low, high targeting only tasks
		targetLowHighMean <- mean(targetingData[targetingData$speed == speedLow & targetingData$difficulty == difficultyHigh, ]$complete)
		# get the mean of the high, low targeting only tasks
		targetHighLowMean <- mean(targetingData[targetingData$speed == speedHigh & targetingData$difficulty == difficultyLow, ]$complete)
		# get the mean of the low, low targeting only tasks
		targetHighHighMean <- mean(targetingData[targetingData$speed == speedHigh & targetingData$difficulty == difficultyHigh, ]$complete)
		# put in dataframe
		targetMeans <- data.frame(speed = rep(levels(targetingData$speed), each=2), difficulty = rep(levels(targetingData$difficulty), 2),
			mean = c(targetLowLowMean, targetLowHighMean, targetHighLowMean, targetHighHighMean))
	}

	if(nrow(targetingData) > 0 & nrow(additionData) > 0) {

		# compute concurrency
		mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeLow] <-
			getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeLow], additionLowMean, targetLowLowMean)
		mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeLow] <-
			getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeLow], additionLowMean, targetLowHighMean)
		mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeLow] <-
			getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeLow], additionLowMean, targetHighLowMean)
		mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeLow] <-
			getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeLow], additionLowMean, targetHighHighMean)
		mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeHigh] <-
			getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeHigh], additionHighMean, targetLowLowMean)
		mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeHigh] <-
			getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeHigh], additionHighMean, targetLowHighMean)
		mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeHigh] <-
			getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeHigh], additionHighMean, targetHighLowMean)
		mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeHigh] <-
			getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeHigh], additionHighMean, targetHighHighMean)

		# compute concurrency in a loop
		for(o in unique(mainData$oprange)) {
			for(d in unique(mainData$difficulty)) {
				for(s in unique(mainData$speed)) {
					mainData$concurrency2[mainData$oprange == o & mainData$difficulty == d & mainData$speed == s] <-
					getConcurrencyVec(mainData$complete[mainData$oprange == o & mainData$difficulty == d & mainData$speed == s],
						additionMeans$mean[additionMeans$oprange == o],
						targetMeans$mean[targetMeans$speed == s & targetMeans$difficulty == d])
				}
			}
		}

		# test that loop produces same as flat
		print("concurrencies equal:")
		print(all(mainData$concurrency == mainData$concurrency2))
	}

	# return results in a list
	return(list(
		main = mainData,
		addition = additionData,
		targeting = targetingData,
		practice = practiceData
		))
}

getConcurrencyVec <- function(completionTimes, additionTime, targetTime) {
	# low value
	low = max(additionTime, targetTime)
	# high value
	high = additionTime + targetTime
	return ((completionTimes - high) / (low - high))
}