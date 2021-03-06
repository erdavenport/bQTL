#!/usr/bin/env Rscript

###### 
# This script will pull the nearest gene information from ensembl for use in GO analyses, 
# trim based on a distance cutoff, and then perform GSEA. Script has three arguments on the 
# command line: 1. the name and location of the GWAS file to be analyzed 2. name of bacteria
# 3. the distance (in kb) to nearest gene cutoff 4. The ontology type to run 5. the out path
# of where to write the results to. This script can be submitted using the qsub script 
# "submit_GSEA_postwas_with_distance_trimming_040414ERD.sh" including the same five arguments
# and the -V flag during qsub (otherwise the required R libraries won't load correctly)
# ./GSEA_postgwas_with_distance_trimming_040414ERD.R /Users/erdavenport/clusterhome/poopQTL/8_seasons_averaged/GEMMA_output_bacteria_032514/GWAS.127.season.averaged.bacteria.phylum_Firmicutes.column.1.out.032514ERD.assoc.txt phylum_Firmicutes 10 ~/poopQTL/8_seasons_averaged/GSEA_results_040414/
# input:		table of SNP to gene mapping 
#				GWAS results
#				genotypes in postgwas format
# output: 		table GSEA enrichment results
######

###### PARAMETERS ##########
# Set the parameters:
today <- Sys.Date()											# Set the date that will go on the end of the files generated by this script
today <- format(today, format="%m%d%y")
in.path <- c("/mnt/lustre/home/erdavenport/poopQTL/8_seasons_averaged/SNP_annotation_files_040414/")	# path for all output to go into
#############################



##### Read in command line arguments:
args <- commandArgs(trailingOnly = TRUE)
print(args) 
# args[1]	# This will be the name of the GWAS file (and location) that will be analyzed
# args[2]	# This will be the name of the bacteria being looked at
# args[3] 	# Distance to nearest gene to be cutoff
# args[4] 	# Out path for the GSEA results
bacteria <- args[2]
distance <- as.numeric(args[3])

print(paste("GWAS file being examined: ", args[1], sep=""))
print(paste("Bacteria being examined: ", args[2], sep=""))
print(paste("Considering SNPs within ",distance,"kb of genes", sep=""))



##### Load libraries:
print("loading libraries")
suppressPackageStartupMessages(library(postgwas))
suppressPackageStartupMessages(library(topGO))
suppressPackageStartupMessages(library(org.Hs.eg.db))
suppressPackageStartupMessages(library(qvalue))



##### Read in table that contains nearest gene:
print(paste("calculating distance of each SNP to nearest gene and trimming anything further than ",distance,"kb away",sep=""))
genes <- read.table(file=paste(in.path, "table.SNP.to.gene.from.postgwas.040114ERD.txt", sep=""), sep="\t", header=TRUE, stringsAsFactors=FALSE, na.strings="OOPS")
nSNPs <- dim(genes)[1]


##### Find distance between SNP and nearest gene:
dist <- rep(NA, dim(genes)[1])
for (i in 1:dim(genes)[1]) {
	if (genes$direction[i] == "cover") {
		dist[i] <- 0
	} else if (genes$direction[i] == "up") {
		dist[i] <- genes$BP[i]-genes$end[i]
	} else if (genes$direction[i] == "down") {
		dist[i] <- genes$start[i] - genes$BP[i]
	}
}
genes <- cbind(genes, dist)
genes <- genes[-which(genes$dist > distance*1000),]
print(paste("examining ",dim(genes)[1]," within ",distance,"kb of genes (of ",nSNPs," total SNPs in GWAS)", sep=""))



##### Load in list of assoc files: 
print("loading GWAS data")
assoc <- read.table(file=args[1], sep="\t", header=TRUE, colClasses=c("numeric", "character", "numeric", "numeric", "character", "character", "numeric", "numeric", "numeric"))

# Make a table that can go into the the gene p value converter function: need P-value information: 
pvals <- assoc[,c(2,9)]
colnames(pvals) <- c("SNP", "P")
gwas <- merge(genes, pvals, by="SNP")



##### Get a genewise p-value, splitting by chromosomes:
print("calculating gene-wise p-value, splitting by chromosome")
chroms <- c(sort(as.numeric(names(table(gwas$CHR))[1:22])), "X")
gwas.gp.SpD <- c()
for (i in 1:length(chroms)) {
	print(paste("on chr",chroms[i], sep=""))
	gwas_by_chr <- gwas[gwas$CHR == chroms[i], ]
	gwas.gp.SpD <- rbind(gwas.gp.SpD, suppressMessages(gene2p(gwas_by_chr, method=SpD, gts.source=paste(in.path, "hutt.3chip.genotypes.for.postgwas.040214ERD.txt.gwaa.gz", sep=""))))
}



##### Do the GO gene set enrichment analyses:
print("performing gene set enrichment analyses")

# BP
BP.enrich <- gwasGOenrich(gwas=gwas.gp.SpD, ontology="BP", pruneTermsBySize=8, pkgname.GO= "org.Hs.eg.db", topGOalgorithm="classic", plotSigTermsToFile=0)
Q <- qvalue(BP.enrich$P)$qvalues
BP.enrich <- cbind(BP.enrich, Q)
print("saving biological processes results")
write.table(BP.enrich, paste(args[4],"table.GSEA.enrichment.",bacteria,".snps.",distance,"kb.from.nearest.gene.BP.terms.",today,"ERD.txt", sep=""), sep="\t", col.names=TRUE, row.names=TRUE, quote=FALSE)

# MF
MF.enrich <- gwasGOenrich(gwas=gwas.gp.SpD, ontology="MF", pruneTermsBySize=8, pkgname.GO= "org.Hs.eg.db", topGOalgorithm="classic", plotSigTermsToFile=0)
Q <- qvalue(MF.enrich$P)$qvalues
MF.enrich <- cbind(MF.enrich, Q)
print("saving biological processes results")
write.table(MF.enrich, paste(args[4],"table.GSEA.enrichment.",bacteria,".snps.",distance,"kb.from.nearest.gene.MF.terms.",today,"ERD.txt", sep=""), sep="\t", col.names=TRUE, row.names=TRUE, quote=FALSE)

# CC
CC.enrich <- gwasGOenrich(gwas=gwas.gp.SpD, ontology="CC", pruneTermsBySize=8, pkgname.GO= "org.Hs.eg.db", topGOalgorithm="classic", plotSigTermsToFile=0)
Q <- qvalue(CC.enrich$P)$qvalues
CC.enrich <- cbind(CC.enrich, Q)
print("saving cellular componentresults")
write.table(CC.enrich, paste(args[4],"table.GSEA.enrichment.",bacteria,".snps.",distance,"kb.from.nearest.gene.CC.terms.",today,"ERD.txt", sep=""), sep="\t", col.names=TRUE, row.names=TRUE, quote=FALSE)



print("DONE!")
