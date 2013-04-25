rmerge <- function(df1, df2) {
	cols <- intersect(colnames(df1) , colnames(df2))
	rbind(df1[,cols, drop=FALSE], df2[,cols, drop=FALSE])
}
rmerge <- function(...) {
	cols <- Reduce(intersect, llply(list(...), colnames))
	Reduce(rbind, llply(list(...), function (df) {df[,cols, drop=FALSE]}))
}