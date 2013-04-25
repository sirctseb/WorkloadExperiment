getDF <- function(data, tablename) {
	data[[tablename]]
}
combineData <- function(data, tablename) {
	i <- 1
	ldply(data,
		function(d) {
			res <- cbind(getDF(d, tablename), subject = i);
			i <<- i + 1
			res
		}
	)
}
loadSubjectData <- function(subjlow, subjhigh) {
	llply(subjlow:subjhigh, assembleData);
}
getVertical <- function(data, subject) {
	rmerge(data.frame(data[[subject]]$addition, type="addition"), data.frame(data[[subject]]$targeting, type="targeting"), data.frame(data[[subject]]$main, type="main"))
}
getAll <- function(data, subjects) {
	do.call(rmerge, llply(subjects, function(subject) {getVertical(data, subject)}));
}
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