adf.learn <- function(x, length=36, offset=12) {
	adfresults = numeric(0)
	kpssresults = numeric(0)
	for(n in 1:(length(x)/length)) {
		whole = x[((n-1)*length + 1):(n*length)]
		adfresults = c(adfresults, adf.test(whole)$p.value)
		kpssresults = c(kpssresults, kpss.test(whole)$p.value)
		part = x[((n-1)*length + offset + 1):(n*length)]
		adfresults = c(adfresults, adf.test(part)$p.value)
		kpssresults = c(kpssresults, kpss.test(part)$p.value)
	}
	list(adf=adfresults, kpss=kpssresults)
}