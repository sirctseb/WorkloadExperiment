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