#!/usr/bin/env Rscript

###### 
# This script will take the initial bacterial proportions file and trim it down to 
# the number of samples you want to look at. It will then also ensure that the sample order
# is the same in the phenotype files (for the traits and diseases) and covariates files. This
# uses the same normalizing strategies as seasons averaged, but for each season separately.
# This script will calculate three diversity metrics for each season (richness, shannon diversity
# and evenness)
# input: 	data tables of bacteria (5 levels)
# output: 	table listing the three diversity measures for each sample for each season
######

###### PARAMETERS ##########
# Set the parameters:
today <- Sys.Date()							# Set the date that will go on the end of the files generated by this script
today <- format(today, format="%m%d%y")
output.path <- c("/Users/erdavenport/Dropbox/Lab/Poop/Sequencing_Results/39_FC1to4_seasons_individually/")	# path for all output to go into
subfolder <- c("8_diversity_061914/")		# Optional folder for putting initial data files into
#############################


##### Load libraries:
library(vegan)



##### First, load in genus level:
all.bacteria <- c()
print("Loading genus proportion tables...")
for (a in c("genus")) {
	data <- read.table(file=paste("/Users/erdavenport/Dropbox/Lab/Poop/Sequencing_Results/20_FC1to4_for_QTLs/FC1to4.subsampled.2mil.",a,".standardized.reps.combined.no.abs.052313ERD.txt", sep=""), sep="\t", header=TRUE)
	print(c(a, dim(data)[1]))
	all.bacteria <- rbind(all.bacteria, data)
}
print(c("all taxa", dim(all.bacteria)[1]))



##### Trim to just the individuals we're interested in looking at - eliminate the individual without genotype data:
print("trimming individuals from full table:")
all.bacteria.trimmed <- all.bacteria[,-grep("154112", colnames(all.bacteria))]

# Separate into winter and summer to prune individuals:
w.bacteria.trimmed <- all.bacteria.trimmed[,grep("W", colnames(all.bacteria.trimmed))]
s.bacteria.trimmed <- all.bacteria.trimmed[,grep("S", colnames(all.bacteria.trimmed))]



##### Calculate diversity easures for each person:
print("calculating diversity metrics")
# winter:
S <- specnumber(t(w.bacteria.trimmed))
H <- diversity(t(w.bacteria.trimmed), index="shannon")
J <- H/log(S)

w.diversity <- cbind(S, H, J)
rownames(w.diversity) <- gsub("_W", "", rownames(w.diversity))

# summer:
S <- specnumber(t(s.bacteria.trimmed))
H <- diversity(t(s.bacteria.trimmed), index="shannon")
J <- H/log(S)

s.diversity <- cbind(S, H, J)
rownames(s.diversity) <- gsub("_S", "", rownames(s.diversity))



##### qqnorm the diversity metrics (in addition to leaving them as is):
# winter:
normed.log.QTL.data <-  w.diversity

set.seed(1)	
for (i in 1:dim(normed.log.QTL.data)[2]) {
	x <- sample(1:dim(normed.log.QTL.data)[1])
	normed <- qqnorm(normed.log.QTL.data[x,i], plot.it=FALSE)$x
	normed.log.QTL.data[,i] <- normed[order(x)]
}	

colnames(normed.log.QTL.data) <- paste("normalized_",colnames(normed.log.QTL.data), sep="")

w.log.QTL.data <- t(cbind(w.diversity, normed.log.QTL.data))

# summer;
normed.log.QTL.data <-  s.diversity

set.seed(1)	
for (i in 1:dim(normed.log.QTL.data)[2]) {
	x <- sample(1:dim(normed.log.QTL.data)[1])
	normed <- qqnorm(normed.log.QTL.data[x,i], plot.it=FALSE)$x
	normed.log.QTL.data[,i] <- normed[order(x)]
}	

colnames(normed.log.QTL.data) <- paste("normalized_",colnames(normed.log.QTL.data), sep="")

s.log.QTL.data <- t(cbind(s.diversity, normed.log.QTL.data))


##### Write out diversity tables:
print("writing out diversity tables")
write.table(w.log.QTL.data, paste(output.path, subfolder, "diversity.measures.w.",today,"ERD.txt", sep=""), sep="\t", quote=FALSE)
write.table(s.log.QTL.data, paste(output.path, subfolder, "diversity.measures.s.",today,"ERD.txt", sep=""), sep="\t", quote=FALSE)



print("DONE!")
