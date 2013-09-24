library(ggplot2)
library(plyr)
library(rjson)
library(reshape)
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
			res = c(unlist(block[c("targetDifficulty", "targetSpeed", "additionDifficulty")]), unlist(results), sum(unlist(results)), unlist(results) %*% unlist(weights) / 15 )
			})
	colnames(df) = c("difficulty", "speed", "oprange", "mental", "physical", "temporal", "performance", "effort", "frustration", "sum", "weighted")
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
getVertCase <- function(data, difficultyLevel, speedLevel, oprangeLevel) {
	# be forgiving with level names
	if(oprangeLevel == 0 | oprangeLevel == "low") oprangeLevel = "[1 12]";
	if(oprangeLevel == 1 | oprangeLevel == "high") oprangeLevel = "[13 25]";
	if(speedLevel == 1 | speedLevel == "high") speedLevel = 200;
	# get subset
	subset(data, (difficulty == difficultyLevel | is.na(difficulty)) &
				 (speed == speedLevel | is.na(speed)) &
				 (oprange == oprangeLevel | is.na(oprange)));
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
	f = dlply(subset(rbind(human,model), type != "main"), .(type, speed, difficulty, oprange),
		function(df) {
			i <- sapply(df, is.factor)
			df[i] <- lapply(df[i], as.character)
			# df[,c("type","speed", "difficulty", "oprange")] <- as.character(df[,c("type","speed", "difficulty", "oprange")])
			quartz();
			print(
				ggplot(df, aes(complete, fill=perf)) +
				geom_histogram(pos="dodge") +
				labs(title = paste0(df[1,c("type","speed","difficulty","oprange")],collapse=" "))
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
# plot concurrency distribution for one case
plotConcurrencyCase = function(humanData, modelData,...) {
	ggplot(subset(getVertCase(rbind(humanData, modelData),...), type == "main"), aes(concurrency, fill=perf)) + geom_histogram(pos="dodge")
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
loadAddModel = function(num) {
	d = assembleData(num)
	.GlobalEnv[[paste0("d",num)]] = d
	v = d$addition
	v$perf <- paste0('model',num)
	v$accuracy <- NA
	v$concurrency <- NA
	v$concurrency2 <- NA
	v$type <- 'addition'
	.GlobalEnv[[paste0("vert",num)]] = v
}
loadTargetModel <- function(num) {
	d = assembleData(num)
	.GlobalEnv[[paste0("d",num)]] = d
	v = d$target
	v$perf <- paste0('model',num)
	v$accuracy <- NA
	v$concurrency <- NA
	v$concurrency2 <- NA
	v$type <- 'targeting'
	.GlobalEnv[[paste0("vert",num)]] = v
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
	if(nrow(additionData) > 0) {
		additionData$speed <- as.factor(NA)
		additionData$difficulty <- as.factor(NA)
		additionData$target <- NA
		# get rid of targeting accuracy columns from addition data
		additionData$hits <- NA
		additionData$friendHits <- NA
		additionData$shots <- NA
		# remove empty levels
		additionData$oprange <- factor(additionData$oprange)
	}

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
		# TODO when working with partial data, set levels so means dfs are not messed up
		levels(targetingData$speed) <- c(0,200)
		levels(targetingData$difficulty) <- c(0,1)
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

		# TODO when working with partial data, the non-loop version fails
		# compute concurrency
		# mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeLow] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeLow], additionLowMean, targetLowLowMean)
		# mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeLow] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeLow], additionLowMean, targetLowHighMean)
		# mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeLow] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeLow], additionLowMean, targetHighLowMean)
		# mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeLow] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeLow], additionLowMean, targetHighHighMean)
		# mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeHigh] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeHigh], additionHighMean, targetLowLowMean)
		# mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeHigh] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeHigh], additionHighMean, targetLowHighMean)
		# mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeHigh] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeHigh], additionHighMean, targetHighLowMean)
		# mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeHigh] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeHigh], additionHighMean, targetHighHighMean)

		# compute concurrency in a loop
		for(o in unique(mainData$oprange)) {
			for(d in unique(mainData$difficulty)) {
				for(s in unique(mainData$speed)) {
					mainData$concurrency[mainData$oprange == o & mainData$difficulty == d & mainData$speed == s] <-
					getConcurrencyVec(mainData$complete[mainData$oprange == o & mainData$difficulty == d & mainData$speed == s],
						additionMeans$mean[additionMeans$oprange == o],
						targetMeans$mean[targetMeans$speed == s & targetMeans$difficulty == d])
				}
			}
		}
		mainData$concurrency2 <- mainData$concurrency

		# test that loop produces same as flat
		# print("concurrencies equal:")
		# print(all(mainData$concurrency == mainData$concurrency2))
	}

	# return results in a list
	return(list(
		main = mainData,
		addition = additionData,
		targeting = targetingData,
		practice = practiceData
		))
}
computeConcurrency <- function(data) {
	mainData = subset(data, type == 'main')
	additionData = subset(data, type == 'addition')
	targetingData = subset(data, type == 'targeting')

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
		# mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeLow] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeLow], additionLowMean, targetLowLowMean)
		# mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeLow] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeLow], additionLowMean, targetLowHighMean)
		# mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeLow] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeLow], additionLowMean, targetHighLowMean)
		# mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeLow] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeLow], additionLowMean, targetHighHighMean)
		# mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeHigh] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedLow & mainData$oprange==oprangeHigh], additionHighMean, targetLowLowMean)
		# mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeHigh] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedLow & mainData$oprange==oprangeHigh], additionHighMean, targetLowHighMean)
		# mainData$concurrency[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeHigh] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyLow & mainData$speed==speedHigh & mainData$oprange==oprangeHigh], additionHighMean, targetHighLowMean)
		# mainData$concurrency[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeHigh] <-
		# 	getConcurrencyVec(mainData$complete[mainData$difficulty==difficultyHigh & mainData$speed==speedHigh & mainData$oprange==oprangeHigh], additionHighMean, targetHighHighMean)

		# compute concurrency in a loop
		for(o in unique(mainData$oprange)) {
			for(d in unique(mainData$difficulty)) {
				for(s in unique(mainData$speed)) {
					mainData$concurrency[mainData$oprange == o & mainData$difficulty == d & mainData$speed == s] <-
					getConcurrencyVec(mainData$complete[mainData$oprange == o & mainData$difficulty == d & mainData$speed == s],
						additionMeans$mean[additionMeans$oprange == o],
						targetMeans$mean[targetMeans$speed == s & targetMeans$difficulty == d])
				}
			}
		}
	}

	data[data$type == 'main','concurrency'] <- mainData$concurrency
	data$concurrency
	list(addmeans = additionMeans, targmeans = targetMeans)
}

getConcurrencyVec <- function(completionTimes, additionTime, targetTime) {
	# low value
	low = max(additionTime, targetTime)
	# high value
	high = additionTime + targetTime
	((completionTimes - high) / (low - high))
}
se <- function(data) {
	sqrt(var(data, na.rm = TRUE)/length(data))
}

exp1Results <- function(data, modelData) {
	ret <- list()

	ret$single <- singleResults(data)
	ret$dual <- dualResults(data)
	ret$model <- modelResults(data, modelData)

	ret
}

singleResults <- function(data) {
	ret <- list()

	ret$addition$data <- subset(data, type == 'addition')
	# TODO this should be a bar plot to be consistent with all the other things
	ret$addition$plot <- ggplot(ret$addition$data, aes(addition, fill=oprange)) +
		geom_histogram(pos='dodge') +
		labs(title='Addition single-task execution times',
			y='Count',
			x='Execution time (s)') +
		scale_fill_discrete('Addend range')

	if(nrow(subset(data, type == 'targeting')) > 0) {

		ret$targeting$data <- ddply(subset(data, type == 'targeting'), .(speed, difficulty),
			function(df) {
				# TODO remove outliers?
				targ <- mean(df$target)
				targ.se <- se(df$target)
				data.frame(
					target = targ,
					target.se = targ.se,
					target.low = targ - 2*targ.se,
					target.high = targ + 2*targ.se)
			})
		# ret$targeting$data <- subset(data, type == 'targeting')
		ret$targeting$plot <- ggplot(ret$targeting$data, aes(difficulty, target, fill=speed)) +
			geom_bar(stat='identity', pos='dodge') +
			geom_errorbar(aes(ymin=target.low, ymax=target.high), pos=position_dodge(width=0.9), width = 0.25) +
			labs(title='Targeting single-task execution time',
				x='Difficulty',
				y='Execution time (s)') +
			scale_fill_discrete('Speed\n(pixels/s)')
	}

	ret
}

dualResults <- function(data) {
	ret <- list()

	if(nrow(subset(data, type == 'main')) > 0) {
		ret$agg$data <- ddply(subset(data, type == 'main'), .(difficulty, oprange),
			function(df) {
				# TODO remove outliers?
				complete <- mean(df$complete)
				complete.se <- se(df$complete)
				data.frame(
					complete = complete,
					complete.se = complete.se,
					complete.low = complete - 2*complete.se,
					complete.high = complete + 2*complete.se)
				})
		ret$agg$plot <- ggplot(ret$agg$data, aes(difficulty, complete, fill=oprange)) +
			geom_bar(stat='identity', pos='dodge') +
			geom_errorbar(aes(ymin=complete.low, ymax=complete.high), pos=position_dodge(width=0.9), width=0.25) +
			labs(title='Dual-task execution time',
				x='Targeting difficulty',
				y='Execution time (s)') +
			scale_fill_discrete('Addend range')
		ret$agg$plot$latex.label = 'exp1-dual-times-iv'
	}

	ret
}

modelResults <- function(data, model) {
	ret <- list()

	combined <- rbind(within(data, perf <- 'human'), model)
	levels(combined$difficulty) = c("Low", "High")

	ret$single$addition$data <- ddply(subset(combined, type == 'addition'), .(oprange, perf),
		function(df) {
			# TODO remove outliers?
			add <- mean(df$addition)
			add.se <- se(df$addition)
			data.frame(
				addition = add,
				addition.se = add.se,
				addition.low = add - 2*add.se,
				addition.high = add + 2*add.se)
			})
	# reusable fill scale labels
	perf_fill_scale = scale_fill_discrete('Data source', labels=c("Human", "Model"))
	# reusable x title rotation
	rotate_x_text = theme(axis.text.x = element_text(angle=90,hjust=1,vjust=0.5))
	ret$single$addition$plot <- ggplot(ret$single$addition$data, aes(oprange, addition, fill=perf)) +
		geom_bar(stat='identity', pos='dodge') +
		geom_errorbar(aes(ymin=addition.low, ymax=addition.high), pos=position_dodge(width=0.9), width=0.25) +
		labs(title="Addition single-task execution times",
			x="Addend range",
			y="Execution time (s)") +
		perf_fill_scale
	ret$single$addition$plot$latex.label = 'exp1-single-addition-bar'

	ret$single$addition$boxplot <- ggplot(subset(combined, type == 'addition'),
		aes(oprange, addition, fill=perf)) +
		geom_boxplot(notch=TRUE)

	ret$single$addition$dist <- ggplot(subset(combined, type == 'addition'),
		aes(addition, fill=perf)) +
		geom_histogram(pos='dodge') +
		labs(title="Execution time distributions",
			x='Execution time (s)',
			y='Count') +
		perf_fill_scale +
		facet_grid(oprange~.)
	ret$single$addition$dist$latex.label = 'exp1-single-addition-dist'

	ret$single$targeting$data <- ddply(subset(combined, type == 'targeting'), .(speed, difficulty, perf),
		function(df) {
			# TODO remove outliers?
			targ <- mean(df$target)
			targ.se <- se(df$target)
			data.frame(
				target = targ,
				target.se = targ.se,
				target.low = targ - 2*targ.se,
				target.high = targ + 2*targ.se)
			});
	# set better factor levels for plot
	# levels(ret$single$targeting$data$difficulty) <- c("Low", "High")
	ret$single$targeting$plot <- ggplot(ret$single$targeting$data, aes(interaction(speed, difficulty), target, fill=perf)) +
		geom_bar(stat='identity', pos='dodge') +
		geom_errorbar(aes(ymin=target.low, ymax=target.high), pos=position_dodge(width=0.9), width=0.25) +
		labs(title="Targeting single-task execution times",
			x="Speed, difficulty interaction",
			y="Execution time(s)") +
		perf_fill_scale
	ret$single$targeting$plot$latex.label <- 'exp1-single-target-bar'

	ret$single$targeting$dist <- ggplot(subset(combined, type == 'targeting'),
		aes(target, fill=perf)) +
		geom_histogram(pos='dodge') +
		labs(title="Execution time distributions",
			x='Execution time (s)',
			y='Count') +
		perf_fill_scale +
		facet_grid(speed~difficulty, labeller = label_both)
	ret$single$targeting$dist$latex.label = 'exp1-single-targeting-dist'

	ret$single$targeting$error$data <- ddply(subset(combined, type == 'targeting'), .(speed, difficulty, perf),
		function(df) {
			data.frame(error = (sum(df$misses) / sum(df$shots)))
			})
	ret$single$targeting$error$plot <- ggplot(ret$single$targeting$error$data, aes(x = interaction(speed, difficulty), y=error, fill=perf)) +
		geom_bar(stat='identity', pos='dodge') +
		labs(title="Single task targeting error rate",
			x = "Speed, difficulty interaction",
			y = "Error rate") +
		perf_fill_scale
	ret$single$targeting$error$plot$latex.label = 'exp1-single-target-error'

	ret$dual$data <- ddply(subset(combined, type == 'main'), .(speed, difficulty, oprange, perf),
		function(df) {
			# TODO remove outliers?
			add <- mean(df$addition)
			add.se <- se(df$addition)
			targ <- mean(df$target)
			targ.se <- se(df$target)
			complete <- mean(df$complete)
			complete.se <- se(df$complete)
			conc <- mean(df$concurrency)
			conc.se <- se(df$concurrency)
			data.frame(
				addition = add,
				addition.se = add.se,
				addition.low = add - 2*add.se,
				addition.high = add + 2*add.se,
				target = targ,
				target.se = targ.se,
				target.low = targ - 2*targ.se,
				target.high = targ + 2*targ.se,
				complete = complete,
				complete.se = complete.se,
				complete.low = complete - 2*complete.se,
				complete.high = complete + 2*complete.se,
				concurrency = conc,
				concurrency.se = conc.se,
				concurrency.low = conc - 2*conc.se,
				concurrency.high = conc + 2*conc.se,
				error = sum(df$misses) / sum(df$shots)
				)
			})
	ret$dual$addition$plot <- ggplot(ret$dual$data, aes(interaction(speed, difficulty, oprange), addition, fill=perf)) +
		geom_bar(stat='identity', pos='dodge') +
		geom_errorbar(aes(ymin=addition.low, ymax=addition.high), pos=position_dodge(width=0.9), width=0.25) +
		labs(title="Addition dual-task execution times",
			x="Speed, difficulty, addend range interaction",
			y="Completion time (s)") +
		perf_fill_scale +
		rotate_x_text
	ret$dual$addition$plot$latex.label = 'exp1-dual-addition-bar'

	ret$dual$targeting$plot <- ggplot(ret$dual$data, aes(interaction(speed, difficulty, oprange), target, fill=perf)) +
		geom_bar(stat='identity', pos='dodge') +
		geom_errorbar(aes(ymin=target.low, ymax=target.high), pos=position_dodge(width=0.9), width = 0.25) +
		labs(title="Targeting dual-task execution times",
			x="Speed, difficulty, addend range interaction",
			y="Completion time (s)") +
		perf_fill_scale +
		rotate_x_text
	ret$dual$targeting$plot$latex.label = 'exp1-dual-targeting-bar'

	ret$dual$complete$plot <- ggplot(ret$dual$data, aes(interaction(speed, difficulty, oprange), complete, fill=perf)) +
		geom_bar(stat='identity', pos='dodge') +
		geom_errorbar(aes(ymin=complete.low, ymax=complete.high), pos=position_dodge(width=0.9), width = 0.25) +
		labs(title="Dual task execution times",
			x="Speed, difficulty, addend range interaction",
			y="Execution time (s)") +
		perf_fill_scale +
		rotate_x_text
	ret$dual$complete$plot$latex.label = 'exp1-dual-complete-bar'

	ret$dual$concurrency$plot <- ggplot(ret$dual$data, aes(interaction(speed, difficulty, oprange), concurrency, fill=perf)) +
		geom_bar(stat='identity', pos='dodge') +
		geom_errorbar(aes(ymin=concurrency.low, ymax=concurrency.high), pos=position_dodge(width=0.9), width = 0.25) +
		labs(title="Concurrency",
			x="Speed, difficulty, addend range interaction",
			y="Concurrency") +
		perf_fill_scale +
		rotate_x_text
	ret$dual$concurrency$plot$latex.label = 'exp1-dual-concurrency-bar'

	ret$dual$error$plot <- ggplot(ret$dual$data, aes(interaction(speed, difficulty, oprange), error, fill=perf)) +
		geom_bar(stat='identity', pos='dodge') +
		labs(title = 'Dual task targeting error rate',
			x='Speed, difficulty, addend range interaction',
			y='Error rate') +
		perf_fill_scale +
		rotate_x_text
	ret$dual$error$plot$latex.label <- 'exp1-dual-target-error'

	ret$dual$order$plot <- compareDualTimes(data, model, 1, 0, 1) +
		labs(title = 'Subtask completion time distribution',
			x='Completion time (s)',
			y='Count') +
		scale_fill_discrete('Subtask', labels=c('Addition', 'Targeting'))
	ret$dual$order$plot$latex.label <- 'exp1-dual-task-order'

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