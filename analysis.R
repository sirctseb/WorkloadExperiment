library(ggplot2)
library(plyr)
library(rjson)
library(reshape)
# count completes
countCompletes <- function(data) {
	ddply(data, .(block),
		function(df) {
			add = sum(df$addition != -1, na.rm=TRUE)
			targ = sum(df$target != -1, na.rm=TRUE)
			data.frame(oprange = df$oprange[1],
						addition = add,
						targeting = targ,
						'a+t/2' = add + targ/2,
						'a+t' = add + targ,
						'100(a+t/2)' = 100*(add + targ/2))
		});
}
# get block info
getBlock <- function(subject, block, path = sprintf("output/subject%d/block%d/block.txt", subject, block)) {
	block = fromJSON(readLines(path))
	# set addidion difficulty to atomic value representing level
	if(!is.null(block$additionDifficulty)) {
		if(block$additionDifficulty[1] == 1) block$additionDifficulty = 0;
		if(block$additionDifficulty[1] == 13) block$additionDifficulty = 1;
	} else {
		block$additionDifficulty = NA
	}
	# set NA to target levels when there are no targets
	if(block$targetNumber == 0) {
		block[c("targetDifficulty", "targetSpeed")] = NA
	}
	block
}
# get weights for a given subject
getWeights <- function(subject) {
	# get weights
	data.frame(fromJSON(sub("weights: ", "", paste(readLines(sprintf("output/subject%d/weights.txt",subject)), collapse=""))))
}
# get weights for all subjects
getAllWeights <- function() {
	ldply(1:20,
		function(s) {
			transform(getWeights(s), subject = s)
		})
}
# get workload survey results for a given subject
getTLX <- function(subject) {
	# get weights
	weights = getWeights(subject)
	# get subdirectories
	dirs = list.dirs(sprintf("output/subject%d", subject), recursive = FALSE)
	# build results data frame
	df = ldply(dirs,
		function(dir) {
			# read survey file
			if(!file.exists(paste(dir,"survey.txt",sep="/"))) {
				return (NULL)
			}
			results = fromJSON(sub("survey: ", "", paste(readLines(paste(dir, "survey.txt", sep="/")), collapse="")))
			block = getBlock(path=paste(dir, "block.txt", sep="/"))
			# block = fromJSON(readLines(paste(dir,"block.txt",sep="/")))
			# if(!is.null(block$additionDifficulty)) {
			# 	if(block$additionDifficulty[1] == 1) block$additionDifficulty = 0;
			# 	if(block$additionDifficulty[1] == 13) block$additionDifficulty = 1;
			# } else {
			# 	block$additionDifficulty = NA
			# }
			res = c(unlist(block[c("targetDifficulty", "incentive", "additionDifficulty")]), unlist(results), sum(unlist(results)), unlist(results) %*% unlist(weights) / 15 )
			})
	colnames(df) = c("difficulty", "incentive", "oprange", "mental", "physical", "temporal", "performance", "effort", "frustration", "sum", "weighted")
	df[!is.na(df$oprange) & df$oprange == 0, ]$oprange = "[1 12]"
	df[!is.na(df$oprange) & df$oprange == 1, ]$oprange = "[13 25]"
	df
}
getAllTLX <- function(subjects) {
	ldply(subjects,
		function(s) {
			transform(getTLX(s), subject = s);
		})
}
flatTLX <- function(tlx) {
	melt.data.frame(tlx, id.var = c("weighted", "sum"))
}
meanTLX <- function(tlx) {
	res = ddply(tlx,
		~interaction(difficulty,speed,oprange),
		function(frame) {
			res = cbind(
				rbind(
					colMeans(
						subset(frame, select=-c(difficulty,speed,oprange))
						)
					),
				frame[1,c("difficulty", "speed", "oprange")])
			res$difficulty = as.factor(res$difficulty)
			res$speed = as.factor(res$speed)
			res$oprange = as.factor(res$oprange)
			res
		})
	levels(res$oprange) = c("[1 12]", "[13 25]")
	res
}
getModelWorkload <- function(type, block, subject) {
	blockData = getBlock(subject, block)
	workloads = read.table(sprintf("output/subject%d/block%d/%s.txt",subject,block,type), header=TRUE, sep=",", strip.white=TRUE)
	if(type == "module") {
		colnames(workloads) = c("clock", "vision", "audio", "production", "declarative", "imaginary", "motor", "speech")
	} else if(type == "subnetwork") {
		colnames(workloads) = c("clock", "perceptual", "cognitive", "motor")
	}
	transform(workloads, difficulty = as.factor(blockData$targetDifficulty), speed = as.factor(blockData$targetSpeed), oprange = as.factor(blockData$additionDifficulty))
}
getModule <- function(block, subject) {
	getModelWorkload("module", block, subject)
}
getSubnetwork <- function(block, subject) {
	getModelWorkload("subnetwork", block, subject)
}
getAllModules <- function() {
	ldply(1:14, getModule)
}
getAllSubnetwork <- function() {
	ldply(1:14, getSubnetwork)
}
getOneWorkloadMean <- function(workload) {
	# make array of factor names
	factors = c("difficulty", "speed", "oprange")
	# take means
	res = cbind(rbind(colMeans(subset(workload, select=-c(difficulty, speed, oprange)))), workload[1,factors])
	res$difficult = as.factor(res$difficulty)
	res$oprange = as.factor(res$oprange)
	res$speed = as.factor(res$speed)
	res
}
getWorkloadMean <- function(type, subject) {
	res = ldply(1:14,
		function(block) {
			# get module loads for block
			module = getModelWorkload(type,block,subject)
			# make array of factor names
			factors = c("difficulty", "speed", "oprange")
			# take means
			res = cbind(rbind(colMeans(subset(module, select=-c(difficulty, speed, oprange)))), module[1,factors])
			res$difficult = as.factor(res$difficulty)
			res$oprange = as.factor(res$oprange)
			res$speed = as.factor(res$speed)
			res
			})
	levels(res$oprange) = c("[1 12]", "[13 25]")
	res
}
getModuleMean <- function() {
	getWorkloadMean("module")
}
getSubnetworkMean <- function() {
	getWorkloadMean("subnetwork")
}
combWorkload <- function(expression, data) {
	transform(data, results = eval(expression, data))
}
compareWorkload <- function(tlxExpression = quote(weighted), modelExpression, modelType = "subnetwork", subject) {
	both = rmerge(transform(combWorkload(substitute(modelExpression), getWorkloadMean(modelType, subject)), perf="model"),
					transform(combWorkload(substitute(tlxExpression), meanTLX(getAllTLX(1:20))), perf="human"))
	ggplot(subset(both, !is.na(difficulty) & !is.na(oprange) & !is.na(speed)), aes(x=interaction(difficulty,speed,oprange), y=results, fill=perf)) + geom_bar(pos="dodge",stat="identity")
}

plotWeighted <- function(tlx) {
	ggplot(tlx, aes(interaction(difficulty,speed,oprange),weighted)) + stat_summary(fun.y=mean, geom="bar")
}
# get a data frame from a table
getDF <- function(data, tablename) {
	data[[tablename]]
}
# combine data from multiple subjects into one data frame
combineData <- function(data, tablename) {
	i <- 1
	ldply(data,
		function(d,t) {
			res <- cbind(eval(t, d), subject = i);
			i <<- i + 1
			res
		},
		substitute(tablename)
	)
}
# get a list of data by type and case
byCase <- function(vertData) {
	l = subset(vertData, oprange == "[1 12]")
	h = subset(vertData, oprange == "[13 25]")
	es = subset(vertData, difficulty == 0 & speed == 0)
	hs = subset(vertData, difficulty == 1 & speed == 0)
	ef = subset(vertData, difficulty == 0 & speed == 200)
	hf = subset(vertData, difficulty == 1 & speed == 200)
	list(
		al = subset(l, type == "addition"),
		ah = subset(h, type == "addition"),
		tes = subset(es, type == "targeting"),
		ths = subset(hs, type == "targeting"),
		tef = subset(ef, type == "targeting"),
		thf = subset(hf, type == "targeting"),
		desl = subset(es, type == "main" & oprange == "[1 12]"),
		dhsl = subset(hs, type == "main" & oprange == "[1 12]"),
		defl = subset(ef, type == "main" & oprange == "[1 12]"),
		dhfl = subset(hf, type == "main" & oprange == "[1 12]"),
		desh = subset(es, type == "main" & oprange == "[13 25]"),
		dhsh = subset(hs, type == "main" & oprange == "[13 25]"),
		defh = subset(ef, type == "main" & oprange == "[13 25]"),
		dhfh = subset(hf, type == "main" & oprange == "[13 25]")
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
getVertCase <- function(data, oprangeLevel, incentiveLevel) {
	# be forgiving with level names
	if(oprangeLevel == 0 | oprangeLevel == "low") oprangeLevel = "[1 12]";
	if(oprangeLevel == 1 | oprangeLevel == "high") oprangeLevel = "[13 25]";
	# force to string
	incentiveLevel = ifelse(!!incentiveLevel, "true", "false")
	# get subset
	subset(data, (incentive == incentiveLevel) & (oprange == oprangeLevel | is.na(oprange)));
}
# plot the completion times for the addition, targeting, and combined tasks from a vertical case data frame
plotVert <- function(data) {
	ggplot(data, aes(complete, fill=type,xmin=0,xmax=6)) + geom_histogram(pos="dodge", xmin=0,xmax=6)
}

# compare vertical cases between model and subject data
compareVertCase <- function(humanData, modelData, difficultyLevel, speedLevel, oprangeLevel) {
	# get vertical data for each
	humanVert = getVertCase(humanData, difficultyLevel, speedLevel, oprangeLevel)
	modelVert = getVertCase(modelData, difficultyLevel,speedLevel, oprangeLevel)
	# plot human
	print(plotVert(humanVert) + labs(title=paste("Human ", difficultyLevel, speedLevel, oprangeLevel)))
	# open new window
	quartz()
	# plot model
	print(plotVert(modelVert) + labs(title=paste("Model ", difficultyLevel, speedLevel, oprangeLevel)))

}
# put comparison charts on facet grid
compareVertCaseFacet <- function(humanData, modelData, difficultyLevel, speedLevel, oprangeLevel) {
	# get vertical data for each
	humanVert = getVertCase(humanData, difficultyLevel, speedLevel, oprangeLevel)
	modelVert = getVertCase(modelData, difficultyLevel,speedLevel, oprangeLevel)
	# combine and add separating column
	combined = rbind(within(humanVert, perf<-"Human"), within(modelVert, perf<-"Model"))
	# plot
	p = plotVert(combined)
	# facet
	p + facet_grid(perf ~ .)
}
compareDualTimes <- function(humanData, modelData, difficultyLevel, speedLevel, oprangeLevel) {
	# get vertical data for each
	humanVert = getVertCase(humanData, difficultyLevel, speedLevel, oprangeLevel)
	modelVert = getVertCase(modelData, difficultyLevel,speedLevel, oprangeLevel)
	# combine and add separating column
	combined = subset(rbind(within(humanVert, perf<-"Human"), within(modelVert, perf<-"Model")), type=="main")
	# melt addition and targeting times
	melted = melt(combined, measure.var = c("addition", "target"))
	# plot
	ggplot(melted, aes(value, fill=variable,xmin=0,xmax=6)) + geom_histogram(pos="dodge", xmin=0,xmax=6) +
	# facet
	facet_grid(perf ~ .) +
	# labels
	labs(x="Time", fill="Task")
}
compareDualToSingle <- function(d, difficultyLevel, speedLevel, oprangeLevel) {
	# get vertical data
	vert = getVertCase(d, difficultyLevel, speedLevel, oprangeLevel)
	# melt addition and targeting times
	melted = melt(vert, measure.var = c("addition", "target"))
	# label single vs dual
	melted = within(melted, mode <- ifelse(type=="addition" | type=="targeting", "single", "dual"))
	# remove NA
	# melted = subset(melted, !is.na(value))
	# plot
	ggplot(melted, aes(value, fill=variable,xmin=0,xmax=6)) + geom_histogram(pos="dodge") +
	# facet
	facet_grid(mode ~ .) +
	# labels
	labs(x="Time", fill="Task")
}
compareSingleTasks <- function(human, model) {
	# separate data
	human = within(human, perf <- "human")
	model = within(model, perf <- "model")
	f = dlply(subset(rbind(human,model), type != "main"), .(type, oprange),
		function(df) {
			i <- sapply(df, is.factor)
			df[i] <- lapply(df[i], as.character)
			# df[,c("type","speed", "difficulty", "oprange")] <- as.character(df[,c("type","speed", "difficulty", "oprange")])
			quartz();
			print(
				ggplot(df, aes(complete, fill=perf)) +
				geom_histogram(pos="dodge") +
				labs(title = paste0(df[1,c("type","oprange")],collapse=" "))
			)
		})
}
compareSingleTaskValue <- function(human, model, value) {
	# separate data
	combined = rbind(within(human, perf <- "human"), within(model, perf <- "model"))
	varName = substitute(value)

	# addition
	print(
		ggplot(subset(combined, type == "addition"), eval(substitute(aes(var, fill=perf), list(var = varName)))) +
			geom_histogram(pos="dodge") +
			facet_grid(oprange~.)
	)

	# targeting
	quartz();
	print(
		ggplot(subset(combined, type == "targeting"), eval(substitute(aes(var, fill=perf), list(var = varName)))) +
			geom_histogram(pos="dodge") +
			facet_grid(speed~difficulty)
	)
}
compareDualTaskValue <- function(human, model, value) {
	# separate data
	combined = rbind(within(human, perf <- "human"), within(model, perf <- "model"))
	varName = substitute(value)

	# addition
	print(
		ggplot(subset(combined, type == "main"), eval(substitute(aes(var, fill=perf), list(var = varName)))) +
			geom_histogram(pos="dodge") +
			facet_grid(oprange~difficulty~speed)
	)
}
boxDualTaskValue <- function(human, model, value) {
	# separate data
	combined = rbind(within(human, perf <- "human"), within(model, perf <- "model"))
	varName = substitute(value)

	# addition
	print(
		ggplot(subset(combined, type == "main"), eval(substitute(aes(x=interaction(oprange,difficulty,speed), y=var,fill=perf), list(var = varName)))) +
			geom_boxplot(notch=TRUE)# +
			# facet_grid(oprange~difficulty~speed)
	)
}
getDualCase <- function(data, diff, speed, oprange) {
	subset(getVertCase(data, diff, speed, oprange), type == "main")
}

getFactorValue <- function(fac, idx) {
	sapply(strsplit(as.character(fac), "\\."), "[", idx)
}

# compare all cases between model and subject in separate plots
compareVertAllSeparate <- function(humanData, modelData) {
	# get interaction list between difficulty, speed, and oprange
	# get from only dual task data to avoid NA
	main = subset(humanData, type=="main")
	combs = unique(interaction(main$difficulty, main$speed, main$oprange))
	l_ply(combs,
		function(inter) {
			print(paste("doing ", inter))
			quartz()
			compareVertCase(humanData, modelData, getFactorValue(inter, 1), getFactorValue(inter,2), getFactorValue(inter,3))
		}
	)
}
# compare all cases between model and subject in a single plot
compareVertAll <- function(humanData, modelData) {
	# combine all data
	all = rmerge(transform(humanData, perf="Human"), transform(modelData, perf="Model"))
	# separate dual task, addition, and targeting trials
	dual = subset(all, type=="main")
	add = subset(all, type=="addition")
	targ = subset(all, type=="targeting")
	# expand addition to create observations for each combination of difficulty and speed
	add = rmerge(
		transform(add, difficulty = 0, speed = 0),
		transform(add, difficulty = 1, speed = 0),
		transform(add, difficulty = 0, speed = 200),
		transform(add, difficulty = 1, speed = 200))
	# expand targeting to create observations for low and high addends
	targ = rmerge(
		transform(targ, oprange = "[1 12]"),
		transform(targ, oprange = "[13 25]"))
	# recomine data
	all = rmerge(dual, add, targ)
	# add an interaction column to store the interaction between cases
	all$inter = interaction(all$difficulty, all$speed, all$oprange)
	# plot
	print(ggplot(all, aes(complete, fill=type)) + geom_histogram(pos="dodge") + facet_grid(perf ~ inter))
}
# plot human vs model on one case
compareCase <- function(humanData, modelData, case) {
	ggplot(rbind(within(humanData[[case]], perf<-"Human"), within(modelData[[case]], perf<-"Model")),
		aes(complete, fill=perf)) + geom_histogram(pos="dodge") + labs(title=case)
}
compareGender <- function(data) {
	#### completion times ####
	# get just dual task data
	dual = subset(data, type == "main")
	# box plot by interaction and gender
	print(
		ggplot(dual, aes(interaction(speed, difficulty, oprange), complete, color=gender)) +
		geom_boxplot(notch=TRUE) +
		labs(title = "Dual Task Completion Time by Gender")
	)
	# get just addition data
	addition = subset(data, type == "addition")
	# box plot by level and gender
	quartz();
	print(
		ggplot(addition, aes(oprange, complete, color = gender)) +
		geom_boxplot(notch=TRUE) +
		labs(title = "Single Task Addition Completion Time by Gender")
	)
	# get just targeting data
	targeting = subset(data, type == "targeting")
	# box plot by interaction and gender
	quartz();
	print(
		ggplot(targeting, aes(interaction(speed, difficulty), complete, color = gender)) +
		geom_boxplot(notch=TRUE) +
		labs(title = "Single Task Targeting Completion Time by Gender")
	)

	#### concurrency values ####
	# box plot by interaction and gender
	quartz();
	print(
		ggplot(dual, aes(interaction(speed, difficulty, oprange), concurrency, color = gender)) +
		geom_boxplot(notch=TRUE) +
		labs(title = "Dual Task Concurrency by Gender")
	)
}

# get concurrency for a given condition
getConcurrencyCase = function(vertData, agg=mean, ...) {
	case = getVertCase(vertData, ...)
	getConcurrency(case, agg)
}
# get concurrency for data that is already filtered for condition
getConcurrency = function(vertData, agg=mean) {
	addmean = agg(subset(vertData,type=="addition")$complete)
	targetingmean = agg(subset(vertData,type=="targeting")$complete)
	dualmean = agg(subset(vertData,type=="main")$complete)
	(addmean + targetingmean - dualmean) / min(addmean, targetingmean)
}
# get concurrency for population by calculating separately for each subject, then combining
getPopConcurrency = function(vertData, agg=mean, ...) {
	case = getVertCase(vertData, ...)
	agg(daply(case, .(subject), function(df) {
		getConcurrency(df)
		}))
}
# produce a data frame of concurrency for human data and model data in all cases
compareConcurrency = function(humanData, modelData, agg=mean) {
	casesDF = expand.grid(c(0,1),c(0,1),c(0,1))
	colnames(casesDF) = c("oprange", "speed", "difficulty")
	ddply(casesDF, .(difficulty,speed,oprange), function(df) {
		transform(df,
			human = getPopConcurrency(humanData, agg, df$difficulty, df$speed, df$oprange),
			model = getConcurrencyCase(modelData, agg, df$difficulty, df$speed, df$oprange)
			# humanAll = getConcurrencyCase(humanData, agg, df$difficulty, df$speed, df$oprange)
			)
		})
}
# plot concurrency comparison
plotConcurrency = function(humanData, modelData, agg=mean) {
	df = compareConcurrency(humanData, modelData, agg);
	ggplot(melt(df, id.var = c("difficulty", "speed", "oprange")),
		aes(fill=variable,x=interaction(difficulty,speed,oprange),y=value,ymin=0.4)) +
	geom_bar(pos="dodge", stat="identity") +
	labs(x="Difficulty, Speed, Range", y="Concurrency", fill="Subject")
}
plotConcurrencyBox <- function(humanData, modelData) {
	# get separate concurrencies for each subject
	# casesDF = expand.grid(c(0,1), c(0,1), c(0,1))
	# colnames(casesDF) = c("oprange", "speed", "difficulty")
	# ddply(casesDF, .(difficulty,speed,oprange), function(df) {
	# 	realdf = getVertCase(humanData, df$difficulty, df$speed, df$oprange)
	# 	ddply(realdf, .(subject), function(dfsubj) {
	# 		dfsubj$concurrency
	# 		})
	# 	})
	# get separate concurrencies for each subject
	casesDF = expand.grid(c(0,1), c(0,1), c(0,1))
	colnames(casesDF) = c("oprange", "speed", "difficulty")
	means=ddply(casesDF, .(difficulty,speed,oprange), function(df) {
		transform(df,
			human = mean(subset(getVertCase(humanData, df$difficulty, df$speed, df$oprange),type=="main")$concurrency),
			model = mean(subset(getVertCase(modelData, df$difficulty, df$speed, df$oprange),type=="main")$concurrency))
		})
	ggplot(melt(means, id.var = c("difficulty", "speed", "oprange")),
		aes(fill=variable,x=interaction(difficulty,speed,oprange),y=value)) +
	geom_bar(pos="dodge", stat="identity") +
	labs(x="Difficulty, Speed, Range", y="Concurrency", fill="Subject")
}
# plot concurrency distribution for one case
plotConcurrencyCase = function(humanData, modelData,...) {
	ggplot(subset(getVertCase(rbind(humanData, modelData),...), type == "main"), aes(concurrency, fill=perf)) + geom_histogram(pos="dodge")
}
plotCaseMeans <- function(humanData, modelData, expr) {
	exprsub = substitute(expr)
	# combine data
	combined = rbind(within(humanData, perf<-"human"), within(modelData, perf <- "model"));
	eval(substitute(
		ggplot(combined, aes(x=interaction(difficulty, speed, oprange), expression, fill=perf)) +
			geom_boxplot(notch=TRUE),
		list(expression = exprsub)))
}
getCombined <- function(human, model) {
	rbind(within(human, perf<-"human"), within(model, perf<-"model"))
}
boxSingleTask <- function(human, model, expr) {
	# separate data
	combined = rbind(within(human, perf <- "human"), within(model, perf <- "model"))
	varName = substitute(expr)

	# addition
	print(
		ggplot(subset(combined, type == "addition"), eval(substitute(aes(oprange, var, fill=perf), list(var = varName)))) +
			geom_boxplot(notch=TRUE) +
			facet_grid(oprange~.)
	)

	# targeting
	quartz();
	print(
		ggplot(subset(combined, type == "targeting"), eval(substitute(aes(oprange, var, fill=perf), list(var = varName)))) +
			geom_boxplot(notch=TRUE) +
			facet_grid(speed~difficulty)
	)
}
removeOutliersArray <- function(array) {
	array[!array %in% boxplot.stats(array)$out]
}
removeOutliers <- function(data, expr) {
	exprsub = substitute(expr)
	eval(substitute(
		data[which(!data$expression %in% boxplot.stats(data$expression)$out),]
		, list(expression = exprsub)
	))
}

compareSubjects = function(human, model, name) {
	model = within(model, perf<-"model")
	namesub = substitute(name)
	# ggplot(subset(combined, type == "addition"), eval(substitute(aes(var, fill=perf), list(var = varName)))) +
	ddply(human, .(subject), function(df) {
		new = eval(substitute(wilcox.test(namevar~perf,rbind(within(df, perf<-"human"), model)), list(namevar=namesub)))$p.value
		data.frame(subject = df$subject[[1]], p = new)
	});
}

# show plots of addition for each df provided
compareAddition = function(...) {
	l_ply(list(...), function(df) {
		quartz();
		print(
			ggplot(subset(df, type=="addition" & complete <= 4),
				aes(complete, fill=oprange,xmin=0,xmax=4))
			+ geom_histogram(pos="dodge",xmin=0,xmax=4) + labs(title=df$perf[[1]]))
		})
}
# load model results and assign to normal variable names
loadModel = function(num) {
	d = assembleData(num)
	.GlobalEnv[[paste0("d",num)]] = d
	v = getAll(list(d),1)
	v$perf = paste0("model",num)
	.GlobalEnv[[paste0("vert",num)]] = v
	.GlobalEnv[[paste0("case",num)]] = byCase(v)
}

# bind dataframes into one with the columns that they all share
rmerge <- function(...) {
	rbind.fill(...)
	# cols <- Reduce(intersect, llply(list(...), colnames))
	# Reduce(rbind, llply(list(...), function (df) {df[,cols, drop=FALSE]}))
}

# determine if two operands have a carry
carry <- function(op1, op2) {
	(op1 %% 10) + (op2 %% 10) >= 10;
}
# determine if result of addition is single digit
singleDigit <- function(op1, op2) {
	op1 + op2 < 10;
}

# load the data for a single subject into separate data frames for addition, targeting, and dual-task,
# and return them in a list
assembleData <- function(subject) {
	# hard coded gender array from subject number to gender
	genders = c("male", "female")
	gender = aaply(c(2,1,2,1,2,1,1,2,1,2,1,2,1,1,1,1,2,2,2,2),1,function(g) {genders[g]})

	# get the filename for the main file
	mainfile <- sprintf("output/subject%d/r1.txt", subject)
	# read in the data
	mainData <- read.table(mainfile, header=TRUE, sep=",", strip.white=TRUE)
	mainData$subject <- subject
	mainData$gender = as.factor(gender[subject])

	# add addition info
	mainData$carry <- carry(mainData$op1, mainData$op2)
	mainData$singleDigit <- singleDigit(mainData$op1, mainData$op2)
	mainData$bothSingle <- mainData$op1 < 10 & mainData$op2 < 10

	# change -1 indicators to NA
	mainData$addition[mainData$addition == -1] <- NA
	mainData$target[mainData$target == -1] <- NA

	# add misses
	mainData$misses = mainData$shots - mainData$hits - mainData$friendHits

	# make factor columns
	factorColumns <- c("practice", "speed", "oprange", "difficulty", "op1", "op2", "subject")
	mainData[factorColumns] = llply(mainData[factorColumns], as.factor)

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
	additionData$speed <- as.factor(NA)
	additionData$difficulty <- as.factor(NA)
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
	targetingData$addition <- NA
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

	# return results in a list
	return(list(
		main = mainData,
		addition = additionData,
		targeting = targetingData,
		practice = practiceData
		))
}

se <- function(data) {
	sqrt(var(data, na.rm = TRUE)/length(data))
}
# concurrency not split by subject
concurrencyAll <- function (vert) {
	cases = expand.grid(c(0,1), c(0,1))
	names(cases) = c("oprange", "incentive")
	ddply(cases, .(incentive, oprange), function(df) {
		datadf = getVertCase(vert, df$oprange, df$incentive)
		conc <- concByCase(datadf)
		data.frame(
			concurrency = conc$concurrency,
			concurrencySE = conc$se,
			concLow = conc$concurrency - 2*conc$se,
			concHigh = conc$concurrency + 2*conc$se,
			additionSingle = mean(subset(datadf, type == "addition")$addition),
			additionDual = mean(subset(datadf, type == "main")$addition, na.rm = TRUE),
			targetSingle = mean(subset(datadf, type == "targeting")$target),
			targetDual = mean(subset(datadf, type == "main")$target, na.rm = TRUE))
	})
}
concurrency <- function(vert) {
	cases = expand.grid(c(0,1), c(0,1), levels(vert$subject))
	names(cases) = c("oprange", "incentive", "subject")
	ddply(cases, .(incentive, oprange, subject), function(df) {
		datadf = subset(getVertCase(vert, df$oprange, df$incentive), subject == df$subject)
		conc <- concByCase(datadf)
		data.frame(
			concurrency = conc$concurrency,
			concurrencySE = conc$se,
			concLow = conc$concurrency - 2*conc$se,
			concHigh = conc$concurrency + 2*conc$se,
			additionSingle = mean(subset(datadf, type == "addition")$addition),
			additionDual = mean(subset(datadf, type == "main")$addition, na.rm = TRUE),
			targetSingle = mean(subset(datadf, type == "targeting")$target),
			targetDual = mean(subset(datadf, type == "main")$target, na.rm = TRUE))
	})
}
concByCase <- function(caseData, vertData, oprange, incentive) {
	ret = list()
	if(is.null(caseData)) {
		caseData <- getVertCase(vertData, oprange, incentive)
	}
	targeting = subset(caseData, type == "targeting")
	addition = subset(caseData, type == "addition")
	main = subset(caseData, type == "main")
	AT = mean(addition$addition, na.rm = TRUE)
	ATse <- se(addition$addition)
	TT = mean(targeting$target, na.rm = TRUE)
	TTse <- se(targeting$target)
	DAT = mean(main$addition, na.rm = TRUE)
	DATse <- se(main$addition)
	DTT = mean(main$target, na.rm = TRUE)
	DTTse <- se(main$target)
	# EAT = DAT - AT
	# ETT = DTT - AT
	# WAT = DAT - EAT
	# WTT = DTT - ETT
	# 1 - (EAT + ETT / (WAT + WTT))
	# TODO double check that these are equivalent
	ret$concurrency <- 1 - ((DAT + DTT - AT - TT) / (AT + TT))
	numse <- sqrt(sum(c(DATse, DTTse, ATse, TTse)^2))
	dense <- sqrt(sum(c(ATse, TTse)^2))
	ret$se <- ((DAT + DTT - AT - TT) / (AT + TT)) * sqrt(sum(c(numse/(DAT + DTT - AT - TT), dense / (AT + TT))^2))
	ret
}

exp2Results <-function(data, modelData) {
	ret = list()
	# incentive / oprange effects on single task execution time
	ret$single = singleTaskIVEffects(data, modelData);
	# incentive / oprange effects on dual task execution time
	ret$dual = dualTaskIVEffects(data);
	# incentive effect on concurrency
	ret$concurrency = incentiveConcurrency(data);
	# TODO investigative things explaining lack of concurrency increase

	ret$model = modelValidation(data, modelData)

	ret
}
singleTaskIVEffects <- function(data, model) {
	ret = list()

	ret$addition = list()
	# addition time aov by oprange and incentive
	# TODO subject in anova?
	ret$addition$aov = aov(addition~oprange*incentive, subset(data, type == "addition"))
	# t tests of addition times by incentive in each difficulty case
	ret$addition$low.by.incentive = wilcox.test(addition~incentive, subset(data, type == "addition" & oprange == "[1 12]"))
	ret$addition$high.by.incentive = wilcox.test(addition~incentive, subset(data, type == "addition" & oprange == "[13 25]"))

	# effect is negative when the unincentivized trials have higher times, so the effect is strong
	ret$addition$skill.low <- ddply(subset(data, type == 'addition' & oprange == '[1 12]'), .(subject), function(df) {
		data.frame(skill = mean(df$addition),
					effect = mean(df[df$incentive == 'true','addition']) - mean(df[df$incentive == 'false', 'addition']))
	})
	ret$addition$skill.low.plot = ggplot(ret$addition$skill.low, aes(x = skill, y = effect, color=as.factor(subject))) + geom_point()

	ret$addition$skill.high = ddply(subset(data, type == 'addition' & oprange == '[13 25]'), .(subject), function(df) {
		data.frame(skill = mean(df$addition),
					effect = mean(df[df$incentive == 'true', 'addition']) - mean(df[df$incentive == 'false', 'addition']))
	})
	ret$addition$skill.high.plot = ggplot(ret$addition$skill.high, aes(x = skill, y = effect, color=as.factor(subject))) + geom_point()

	ret$addition$model$vert <- subset(rbind(within(data, perf <- 'human'), model), type == 'addition')
	ret$addition$model$agg <- ddply(ret$addition$model$vert, .(oprange, incentive, perf), function(df) {
			# TODO remove outliers?
			add <- mean(df$addition)
			add.se <- se(df$addition)
			data.frame(
				addition = add,
				addition.se = add.se,
				addition.low = add - 2*add.se,
				addition.high = add + 2*add.se
				)
		})
	ret$addition$model$plot <- plotBars(ret$addition$model$agg, interaction(incentive, oprange), addition, addition.low, addition.high) +
		facet_grid(.~perf)

	ret$targeting = list()
	ret$targeting$aov = aov(target~incentive, subset(data, type == "targeting"))
	ret$targeting$by.incentive <- wilcox.test(target~incentive, subset(data, type == "targeting"))
	ret$targeting$skill = ddply(subset(data, type == 'targeting'), .(subject), function(df) {
		data.frame(skill = mean(df$target),
					effect = mean(df[df$incentive == 'true', 'target']) - mean(df[df$incentive == 'false', 'target']))
		})
	ret$targeting$skill.plot = ggplot(ret$targeting$skill, aes(x = skill, y = effect, color = as.factor(subject))) + geom_point()

	ret$targeting$model$vert <- subset(rbind(within(data, perf <- 'human'), model), type == 'targeting')
	ret$targeting$model$agg <- ddply(ret$targeting$model$vert, .(incentive, perf), function(df) {
		# TODO remove outliers?
		targ <- mean(df$target)
		targ.se <- se(df$target)
		data.frame(
			target = targ,
			target.se = targ.se,
			target.low = targ - 2*targ.se,
			target.high = targ + 2*targ.se)
		})
	ret$targeting$model$plot <- plotBars(ret$targeting$model$agg, incentive, target, target.low, target.high) +
		facet_grid(.~perf)

	ret$addition$incentive <- ddply(subset(data, type != 'main'), .(subject, incentive), function(df) {
		data.frame(addition.low = mean(subset(df, oprange == '[1 12]')$addition, na.rm = TRUE),
					addition.high = mean(subset(df, oprange == '[13 25]')$addition, na.rm = TRUE))
		})
	ret$addition$incentive.flat <- recast(ret$addition$incentive, measure.var = c("addition.low", "addition.high"), subject~incentive*variable)

	ret$addition$incentive.plot <- ggplot(ret$addition$incentive, aes(addition.low, addition.high, color = as.factor(subject))) +
		geom_point(aes(shape = incentive)) +
		geom_segment(data = ret$addition$incentive.flat,
			aes(x = false_addition.low, xend = true_addition.low, y = false_addition.high, yend = true_addition.high))

	ret
}
diffs <- function(data) {
	ddply(subset(data,type == 'main'),
		.(subject, oprange),
		function(df) {
			data.frame(
				addition = mean(df[df$incentive == 'true','addition'], na.rm = TRUE) -
					mean(df[df$incentive == 'false','addition'], na.rm = TRUE),
				target = mean(df[df$incentive == 'true','target'], na.rm = TRUE) -
					mean(df[df$incentive == 'false','target'], na.rm = TRUE)
			)
		})
}
clean <- function(data) {
	data_diffs <- diffs(data)
	ret = data
	d_ply(data_diffs, .(subject, oprange), function(df) {
		print(df[,'addition'])
		if(df[,'addition'] > 0) {
			print(paste0('removing subject', df$subject, ' oprange ', df$oprange, ' for addition'))
			ret <<- subset(ret, !(type == 'main' & subject == df$subject & oprange == df$oprange & !is.na(addition)))
		}
		if(df[,'target'] > 0) {
			ret <<- subset(ret, subject != df$subject | oprange != df$oprange | is.na(target))
		}
	})
	ret
}
dualTaskIVEffects <- function(data) {
	ret = list()

	ret$addition = list()
	ret$addition$aov = aov(addition~oprange*incentive, subset(data, type == "main"))
	ret$addition$low.by.incentive = wilcox.test(addition~incentive, subset(data, type == "main" & oprange == "[1 12]"))
	ret$addition$high.by.incentive = wilcox.test(addition~incentive, subset(data, type == "main" & oprange == "[13 25]"))

	ret$targeting = list()
	ret$targeting$aov = aov(target~oprange*incentive, subset(data, type == "main"))
	ret$targeting$low.by.incentive = wilcox.test(target~incentive, subset(data, type == 'main' & oprange == '[1 12]'))
	ret$targeting$high.by.incentive = wilcox.test(target~incentive, subset(data, type == 'main' & oprange == '[13 25]'))

	# calculate target and addition mean by subjectxblock
	ret$tradeoff = ddply(subset(data, type == "main"), .(subject, incentive, oprange), function(df) {
		data.frame(addition = mean(df$addition, na.rm = TRUE), target = mean(df$target, na.rm = TRUE))
		})
	# effect of completion times on incentive effect:
	# create a dataframe with the mean addition and target times for unincentivized block by subjectxoprange
	# and add a column with the addition and target time differences between incentivization added together
	# this is to look at whether absolute performance effects increase in performance from incentivization
	# incentiveEffect is positive when subjects do better with incentive
	ret$command = ddply(ret$tradeoff, .(subject, oprange), function(df) {
		within(df[df$incentive == 'false',], {
			incentiveEffect <- sum(df[df$incentive == 'false',c('addition', 'target')]-df[df$incentive == 'true',c('addition','target')])
			additionIncentive <- df[df$incentive == 'true', 'addition']
			targetIncentive <- df[df$incentive == 'true', 'target']
			meanTime <- mean(c(df[, c('addition', 'target')],recursive=TRUE))
			})
	})
	ret$tradeoff.plot = ggplot(ret$tradeoff, aes(addition, target, shape=incentive, color=as.factor(subject))) +
		geom_point() +
		geom_segment(data = ret$command,
			aes(x = addition, xend = additionIncentive, y = target, yend = targetIncentive))

	# TODO bar plot with error bars of addition and targeting times by oprange and incentive like in the concurrency plot
	# this will show time improvement as opposed to concurrency improvement
	# TODO remove outliers?
	ret$aggregate$data <- ddply(subset(data, type == 'main'), .(oprange, incentive), function(df) {
		# calculate scores
		# TODO this doesn't count misses, friend hits, and the last target hit if it isn't a second target hit
		# calculate scores by trial from the original data frame
		scores = c(daply(subset(data, type == 'main' & oprange == df$oprange[1] & incentive == df$incentive[1]),
			.(subject, block, trial, oprange, incentive),
			function(df) {
				0.1 * sum(!is.na(df$addition)) + 0.1 * sum(!is.na(df$target))
				}))
		scores = scores[!is.na(scores)]
		score = mean(scores)
		score.se = se(scores)

		# calculate statistics
		add.inliers <- removeOutliersArray(df$addition)
		add <- mean(add.inliers, na.rm = TRUE)
		add.se <- se(add.inliers)
		targ.inliers <- removeOutliersArray(df$target)
		targ <- mean(targ.inliers, na.rm = TRUE)
		targ.se <- se(targ.inliers)
		sum.mean <- add + targ
		sum.se <- sqrt(add.se^2 + targ.se^2)

		# convert times into equivalent scores and propagate error
		add.score <- 0.1 * 90 / add
		add.score.se <- add.score * abs(-1) * add.se / add
		targ.score <- 0.1 * 90 / targ
		targ.score.se <- targ.score * abs(-1) * targ.se / targ
		# compute equivalent score
		score <- add.score + targ.score
		score.se <- sqrt(add.score.se^2 + targ.score.se^2)

		data.frame(addition = add,
					addition.se = add.se,
					addition.low = add - 2*add.se,
					addition.high = add + 2*add.se,
					target = targ,
					target.se = targ.se,
					target.low = targ - 2*targ.se,
					target.high = targ + 2*targ.se,
					sum = sum.mean,
					sum.se = sum.se,
					sum.low = sum.mean - 2*sum.se,
					sum.high = sum.mean + 2*sum.se,
					# score = score,
					# score.se = score.se,
					# score.low = score - 2*score.se,
					# score.high = score + 2*score.se)
					score = score,
					score.se = score.se,
					score.low = score - 2*score.se,
					score.high = score + 2*score.se)
		})
	ret$aggregate$addition.plot <- ggplot(ret$aggregate$data, aes(interaction(incentive, oprange), addition)) +
		geom_bar(stat='identity') +
		geom_errorbar(aes(ymin = addition.low, ymax = addition.high))
	ret$aggregate$targeting.plot <- ggplot(ret$aggregate$data, aes(interaction(incentive, oprange), target)) +
		geom_bar(stat='identity') +
		geom_errorbar(aes(ymin = target.low, ymax = target.high))
	ret$aggregate$sum.plot <- ggplot(ret$aggregate$data, aes(interaction(incentive, oprange), sum)) +
		geom_bar(stat='identity') +
		geom_errorbar(aes(ymin = sum.low, ymax = sum.high))
	# TODO do error bars by subject? maybe by trial
	ret$aggregate$score.plot <- ggplot(ret$aggregate$data, aes(interaction(incentive, oprange), score)) +
		geom_bar(stat='identity') +
		geom_errorbar(aes(ymin = score.low, ymax = score.high))
	ret
}
plotBars <- function(data, x.expr, y.expr, low, high) {
	xvar = substitute(x.expr)
	yvar = substitute(y.expr)
	lowvar = substitute(low)
	highvar = substitute(high)
	eval(substitute(
		ggplot(data, aes(xsub, ysub)) +
			geom_bar(stat='identity') +
			geom_errorbar(aes(ymin=lowsub, ymax = highsub)),
		list(xsub = xvar, ysub = yvar, lowsub = lowvar, highsub = highvar)
	))
}
incentiveConcurrency <- function(data) {
	ret = list()

	ret$concurrency.by.subj <- concurrency(data)
	ret$concurrency.by.subj.plot <- ggplot(ret$concurrency.by.subj, aes(interaction(incentive, oprange), concurrency, fill = as.factor(subject))) +
		geom_bar(stat='identity', pos='dodge') +
		geom_errorbar(aes(ymin = concLow, ymax = concHigh), pos='dodge')

	ret$concurrency <- concurrencyAll(data)
	ret$concurrency.plot <- ggplot(ret$concurrency, aes(interaction(incentive, oprange), y=concurrency)) +
		geom_bar(stat = 'identity', pos='dodge') +
		geom_errorbar(aes(ymin = concLow, ymax = concHigh))

	ret
}
modelValidation <- function(data, modelData) {
	ret = list()

	# combine data
	combined <- rbind(within(data, perf <- "human"), within(modelData, perf <- "model"))

	# comparison plots by condition
	ret$single$addition$low$incentive.plot <-
		ggplot(subset(combined, type == 'addition' & oprange == '[1 12]' & incentive == 'true'),
			aes(x = addition, fill = perf)) + geom_histogram(pos='dodge')
	ret$single$addition$low$unincentive.plot <-
		ggplot(subset(combined, type == 'addition' & oprange == '[1 12]' & incentive == 'false'),
			aes(x = addition, fill = perf)) + geom_histogram(pos='dodge')
	ret$single$addition$high$incentive.plot <-
		ggplot(subset(combined, type == 'addition' & oprange == '[13 25]' & incentive == 'true'),
			aes(x = addition, fill = perf)) + geom_histogram(pos='dodge')
	ret$single$addition$high$unincentive.plot <-
		ggplot(subset(combined, type == 'addition' & oprange == '[13 25]' & incentive == 'false'),
			aes(x = addition, fill = perf)) + geom_histogram(pos='dodge')
	ret$single$target$incentive.plot <-
		ggplot(subset(combined, type == 'targeting' & incentive == 'true'),
			aes(x = target, fill = perf)) + geom_histogram(pos='dodge')

	# TODO dual tasks

	ret
}

maxdepth = 7
saveLatexPlots <- function(results) {
	# search through results to find plots with $latex.labels and save them
	scanObjectForPlots(results, 0)
}
scanObjectForPlots <- function(object, depth) {
	# if object has a latex label save the plot
	if('latex.label' %in% names(object)) {
		ggsave(paste0('images/',object$latex.label, '.pdf'), object)
	} else {
		if(depth < maxdepth & is.list(object) & !is.data.frame(object)) {
			for(n in names(object)) {
				scanObjectForPlots(object[[n]], depth + 1)
			}
		}
	}
}