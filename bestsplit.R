bestsplit <- function(x) {
	best = 1
	bestn = 0
	bestt = NULL
	all = numeric(0)
	for(n in 3:(length(x)-3)) {
		new = t.test(x[1:n], x[n:length(x)])
		if(new$p.value < best) {
			best = new$p.value
			bestn = n
			bestt = new
		}
		all = c(all, new$p.value)
	}
	list(bestp=best, bestn=bestn, bestt=bestt, all=all)
}