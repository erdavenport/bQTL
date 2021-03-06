#!/usr/bin/env Rscript

###### 
# This script will take the initial bacterial proportions file and trim it down to 
# the number of samples you want to look at. It will then also ensure that the sample order
# is the same in the phenotype files (for the traits and diseases) and covariates files. This
# uses the same normalizing strategies as seasons averaged, but for each season separately.
# input: 	data tables of bacteria (5 levels)
#			covariate file (sex and age of individuals)
# output: 	list of FINDIVs used in analysis, 
#			data table of all of the bacteria after trimming by individual, trimming by presence cutoff, log transforming, and trimming by correlation to other bacteria
#			covariate file in the same order as findivs in bacteria files
#			table with which bacteria were trimmed for correlation and what bacteria they were correlated to
######

###### PARAMETERS ##########
# Set the parameters:
today <- Sys.Date()							# Set the date that will go on the end of the files generated by this script
today <- format(today, format="%m%d%y")
output.path <- c("/Users/erdavenport/Dropbox/Lab/Poop/Sequencing_Results/39_FC1to4_seasons_individually/")	# path for all output to go into
subfolder <- c("1_Initial_data_processing_052614/")		# Optional folder for putting initial data files into
cor.cutoff = 0.9							# What Pearson correlation cutoff should be used?
presence.cutoff = 0.75						# In what proportion of individuals should the bacteria be in?
#############################


##### First, load in all levels of data across all individuals, both seasons:
all.bacteria <- c()
initial.bacteria <- c()
print("Loading all initial bacteria proportion tables...")
print("Number of taxa before any pruning:")
for (a in c("phylum", "class", "order", "family", "genus")) {
	data <- read.table(file=paste("/Users/erdavenport/Dropbox/Lab/Poop/Sequencing_Results/20_FC1to4_for_QTLs/FC1to4.subsampled.2mil.",a,".standardized.reps.combined.no.abs.052313ERD.txt", sep=""), sep="\t", header=TRUE)
	print(c(a, dim(data)[1]))
	initial.bacteria <- c(initial.bacteria, dim(data)[1])
	all.bacteria <- rbind(all.bacteria, data)
}
print(c("all taxa", dim(all.bacteria)[1]))



##### Trim to just the individuals we're interested in looking at - eliminate the individual without genotype data:
print("trimming individuals from full table:")
all.bacteria.trimmed <- all.bacteria[,-grep("154112", colnames(all.bacteria))]

# Separate into winter and summer to prune individuals:
w.bacteria.trimmed <- all.bacteria.trimmed[,grep("W", colnames(all.bacteria.trimmed))]
s.bacteria.trimmed <- all.bacteria.trimmed[,grep("S", colnames(all.bacteria.trimmed))]




##### Prune the bacteria that are lower than the presence cutoff in each season:
print(paste("Pruning bacteria that are in fewer than ",presence.cutoff*100,"% of individuals...", sep=""))
zeros <- c()
for (i in 1:dim(w.bacteria.trimmed)[1]) {
	x <- 0
	for (j in 1:dim(w.bacteria.trimmed)[2]) {
        if (w.bacteria.trimmed[i,j] == 0 ) {
        	x <- x+1
    	}
    }
    zeros <- c(zeros, x)
}
w.perc <- 1-zeros/dim(w.bacteria.trimmed)[2]

zeros <- c()
for (i in 1:dim(s.bacteria.trimmed)[1]) {
	x <- 0
	for (j in 1:dim(s.bacteria.trimmed)[2]) {
        if (s.bacteria.trimmed[i,j] == 0 ) {
        	x <- x+1
    	}
    }
    zeros <- c(zeros, x)
}
s.perc <- 1-zeros/dim(s.bacteria.trimmed)[2]

# Eliminate bacteria that are present in fewer individuals than the presence.cutoff:
w.QTL.taxa <- w.bacteria.trimmed[-which(w.perc <= presence.cutoff), ] 
s.QTL.taxa <- s.bacteria.trimmed[-which(s.perc <= presence.cutoff), ] 

print(paste("number of taxa remaining: winter = ", dim(w.QTL.taxa)[1], " summer = ", dim(s.QTL.taxa)[1], sep=""))




##### Quantile transform data:
print("qqnorming data")
w.log.QTL.data <- matrix(NA, ncol=dim(w.QTL.taxa)[2], nrow=dim(w.QTL.taxa)[1])
s.log.QTL.data <- matrix(NA, ncol=dim(s.QTL.taxa)[2], nrow=dim(s.QTL.taxa)[1])

# By bacteria:
# Randomly shuffle assignments to break ties w/qqnorm:
for (i in 1:dim(w.QTL.taxa)[1]) {
	x <- sample(1:dim(w.QTL.taxa)[2])
	normed <- qqnorm(w.QTL.taxa[i,x], plot.it=FALSE)$x
	w.log.QTL.data[i,] <- normed[order(x)]
}

for (i in 1:dim(s.QTL.taxa)[1]) {
	x <- sample(1:dim(s.QTL.taxa)[2])
	normed <- qqnorm(s.QTL.taxa[i,x], plot.it=FALSE)$x
	s.log.QTL.data[i,] <- qqnorm(s.QTL.taxa[i,], plot.it=F)$x
}

colnames(w.log.QTL.data) <- colnames(w.QTL.taxa)
rownames(w.log.QTL.data) <- rownames(w.QTL.taxa)
colnames(s.log.QTL.data) <- colnames(s.QTL.taxa)
rownames(s.log.QTL.data) <- rownames(s.QTL.taxa)




##### Filter lower bacteria by pairwise Pearson correlation:
w.present.bacteria <- c()
for (a in c("phylum", "class", "order", "family", "genus")) {
	w.present.bacteria <- c(w.present.bacteria, length(grep(a, rownames(w.log.QTL.data))))
}

s.present.bacteria <- c()
for (a in c("phylum", "class", "order", "family", "genus")) {
	s.present.bacteria <- c(s.present.bacteria, length(grep(a, rownames(s.log.QTL.data))))
}

print("Filtering bacteria by Pearson correlation...")
# Get all pairwise Pearson correlations, winter:	
w.bacterial.cors <- c()
i <- 1
while(i < dim(w.log.QTL.data)[1]) {
	j <- i + 1
	while (j < dim(w.log.QTL.data)[1]){
		w.bacterial.cors <- rbind(w.bacterial.cors, c(rownames(w.log.QTL.data)[i], rownames(w.log.QTL.data)[j], cor(as.numeric(w.log.QTL.data[i,]), as.numeric(w.log.QTL.data[j,]))))
		j <- j + 1
	}
	i <- i + 1
}		

s.bacterial.cors <- c()
i <- 1
while(i < dim(s.log.QTL.data)[1]) {
	j <- i + 1
	while (j < dim(s.log.QTL.data)[1]){
		s.bacterial.cors <- rbind(s.bacterial.cors, c(rownames(s.log.QTL.data)[i], rownames(s.log.QTL.data)[j], cor(as.numeric(s.log.QTL.data[i,]), as.numeric(s.log.QTL.data[j,]))))
		j <- j + 1
	}
	i <- i + 1
}	

# Save a histogram of pearson correlations:
pdf(paste(output.path,subfolder,"hist.bacterial.correlations.winter.",cor.cutoff,".qqnormed.",today,"ERD.pdf", sep=""))
hist(as.numeric(w.bacterial.cors[,3]), breaks=100, col="blue", xlab="pearson correlation", main=paste("Distribution of bacteria-to-bacteria correlations (winter)\n qqnormed and trimmed at ",presence.cutoff*100,"%", sep=""))
abline(v=cor.cutoff, col="red")
dev.off()

pdf(paste(output.path,subfolder,"hist.bacterial.correlations.summer.",cor.cutoff,".qqnormed.",today,"ERD.pdf", sep=""))
hist(as.numeric(s.bacterial.cors[,3]), breaks=100, col="tomato", xlab="pearson correlation", main=paste("Distribution of bacteria-to-bacteria correlations (summer)\n qqnormed and trimmed at ",presence.cutoff*100,"%", sep=""))
abline(v=cor.cutoff, col="red")
dev.off()

# Going to prune out higher levels that are stronger than cor.cutoff correlated with any level below it:
w.list.to.prune <- c()
w.trimmed.bact <- c()
for (i in 1:dim(w.bacterial.cors)[1]) { 
	if (as.numeric(w.bacterial.cors[i,3]) >= cor.cutoff) {
		w.list.to.prune <- c(w.list.to.prune, w.bacterial.cors[i,1])
		w.trimmed.bact <- rbind(w.trimmed.bact, w.bacterial.cors[i,])
	}
}
colnames(w.trimmed.bact) <- c("trimmed_bacteria", "remaining_bacteria", "correlation")
w.u.prune <- unique(w.list.to.prune)

final.w.bacteria.data <- w.log.QTL.data[!(rownames(w.log.QTL.data) %in% w.u.prune),]

s.list.to.prune <- c()
s.trimmed.bact <- c()
for (i in 1:dim(s.bacterial.cors)[1]) { 
	if (as.numeric(s.bacterial.cors[i,3]) >= cor.cutoff) {
		s.list.to.prune <- c(s.list.to.prune, s.bacterial.cors[i,1])
		s.trimmed.bact <- rbind(s.trimmed.bact, s.bacterial.cors[i,])
	}
}
colnames(s.trimmed.bact) <- c("trimmed_bacteria", "remaining_bacteria", "correlation")
s.u.prune <- unique(s.list.to.prune)

final.s.bacteria.data <- s.log.QTL.data[!(rownames(s.log.QTL.data) %in% s.u.prune),]

colnames(final.w.bacteria.data) <- gsub("_W", "", colnames(final.w.bacteria.data))
colnames(final.s.bacteria.data) <- gsub("_S", "", colnames(final.s.bacteria.data))

write.table(w.trimmed.bact, paste(output.path, subfolder, "table.bacteria.winter.trimmed.in.presence.trimming.with.correlated.bacteria.",today,"ERD.txt", sep=""), sep="\t", row.names=FALSE, quote=FALSE)
write.table(final.w.bacteria.data, paste(output.path, "FC1to4.winter.filtered.bacteria.QTL.analysis.cor.cutoff.",cor.cutoff,".presence.cutoff.",presence.cutoff,".qqnormed.seasons.individually.",today,"ERD.txt", sep=""), sep="\t", quote=FALSE)

write.table(s.trimmed.bact, paste(output.path, subfolder, "table.bacteria.summer.trimmed.in.presence.trimming.with.correlated.bacteria.",today,"ERD.txt", sep=""), sep="\t", row.names=FALSE, quote=FALSE)
write.table(final.s.bacteria.data, paste(output.path, "FC1to4.summer.filtered.bacteria.QTL.analysis.cor.cutoff.",cor.cutoff,".presence.cutoff.",presence.cutoff,".qqnormed.seasons.individually.",today,"ERD.txt", sep=""), sep="\t", quote=FALSE)

w.final.bacteria <- c()
for (a in c("phylum", "class", "order", "family", "genus")) {
	w.final.bacteria <- c(w.final.bacteria, length(grep(a, rownames(final.w.bacteria.data))))
}

s.final.bacteria <- c()
for (a in c("phylum", "class", "order", "family", "genus")) {
	s.final.bacteria <- c(s.final.bacteria, length(grep(a, rownames(final.s.bacteria.data))))
}



##### Output table with bacteria at each level:
w.bacteria.data <- cbind(initial.bacteria, w.present.bacteria, w.final.bacteria)
w.bacteria.data <- rbind(w.bacteria.data, colSums(w.bacteria.data))
rownames(w.bacteria.data) <- c("phylum", "class", "order", "family", "genus", "all_levels")
colnames(w.bacteria.data) <- c("starting_bacteria", "bacteria_after_presence_filtering", "bacteria_after_correlation_filtering")
write.table(w.bacteria.data, paste(output.path,subfolder,"w.bacteria.remaining.after.filtering.",today,"ERD.txt", sep=""), sep="\t", quote=FALSE)

s.bacteria.data <- cbind(initial.bacteria, s.present.bacteria, s.final.bacteria)
s.bacteria.data <- rbind(s.bacteria.data, colSums(s.bacteria.data))
rownames(s.bacteria.data) <- c("phylum", "class", "order", "family", "genus", "all_levels")
colnames(s.bacteria.data) <- c("starting_bacteria", "bacteria_after_presence_filtering", "bacteria_after_correlation_filtering")
write.table(s.bacteria.data, paste(output.path,subfolder,"s.bacteria.remaining.after.filtering.",today,"ERD.txt", sep=""), sep="\t", quote=FALSE)



##### Set covariates to be in the same order as the data file:
print("saving covariate table")
colonies <- read.table(file="/Users/erdavenport/Dropbox/Lab/Poop/Sequencing_Results/1_General/Microbiome_colony_4-16-14.txt", sep="\t", header=TRUE)



wFINDIVS <- gsub("FC1to4_poop_", "", gsub("_W", "", colnames(final.w.bacteria.data)))

# Set covariates:
covs <- read.table("/Users/erdavenport/Dropbox/Lab/Poop/Sequencing_results/20_FC1to4_for_QTLs/Findiv.age.sex.txt", sep="\t", header=TRUE)
my.w.covs <- c()
for (i in 1:length(wFINDIVS)) {
	my.w.covs <- rbind(my.w.covs, covs[which(covs$ID. == wFINDIVS[i]),])
}

w.cols <- c()
for (i in 1:dim(my.w.covs)[1]) {
	if (colonies$WINTER.COLONY[which(colonies$FINDIV == my.w.covs$ID.[i])] != "") {
		w.cols <- c(w.cols, as.character(colonies$WINTER.COLONY[which(colonies$FINDIV == my.w.covs$ID.[i])]))
	} else {
		w.cols <- c(w.cols, as.character(colonies$SUMMER.COLONY[which(colonies$FINDIV == my.w.covs$ID.[i])]))
	}
}

my.w.covs <- cbind(my.w.covs, w.cols)
colnames(my.w.covs)[4] <- "colony"

write.table(my.w.covs, paste(output.path, "w.covariates.QTL.analysis.",today,"ERD.txt", sep=""), sep="\t", row.names=FALSE, quote=FALSE)
write.table(wFINDIVS, paste(output.path,"w.FINDIVS.used.in.poopQTL.analysis.",today,"ERD.txt", sep=""), sep="\n", row.names=FALSE, col.names=FALSE, quote=FALSE)



sFINDIVS <- gsub("FC1to4_poop_", "", gsub("_S", "", colnames(final.s.bacteria.data)))
# Set covariates:
my.s.covs <- c()
for (i in 1:length(sFINDIVS)) {
	my.s.covs <- rbind(my.s.covs, covs[which(covs$ID. == sFINDIVS[i]),])
}

s.cols <- c()
for (i in 1:dim(my.s.covs)[1]) {
	if (colonies$SUMMER.COLONY[which(colonies$FINDIV == my.s.covs$ID.[i])] != "") {
		s.cols <- c(s.cols, as.character(colonies$SUMMER.COLONY[which(colonies$FINDIV == my.s.covs$ID.[i])]))
	} else {
		s.cols <- c(s.cols, as.character(colonies$WINTER.COLONY[which(colonies$FINDIV == my.s.covs$ID.[i])]))
	}
}

my.s.covs <- cbind(my.s.covs, s.cols)
colnames(my.s.covs)[4] <- "colony"

write.table(my.s.covs, paste(output.path, "s.covariates.QTL.analysis.",today,"ERD.txt", sep=""), sep="\t", row.names=FALSE, quote=FALSE)
write.table(sFINDIVS, paste(output.path,"s.FINDIVS.used.in.poopQTL.analysis.",today,"ERD.txt", sep=""), sep="\n", row.names=FALSE, col.names=FALSE, quote=FALSE)

print("DONE!")
