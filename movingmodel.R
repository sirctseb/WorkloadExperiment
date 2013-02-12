movingmodel <- function(shutup, len=NULL) {
	if(is.null(len)) {
		len = length(shutup$complete)
	}
	x = numeric()
	frame = shutup[1:len, ]
	frame$trial = 1:len
	for(n in 1:(len-1)) {
		x = c(x, summary(lm(complete~trial, frame[-n:0,]))$coefficients[1,4])
	}
	return (x)
}