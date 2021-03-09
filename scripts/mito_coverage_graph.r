#!/usr/bin/env Rscript --vanilla

args=commandArgs(trailingOnly=TRUE)


library(ggplot2)

covtsv.data <- read.csv(file= args[1], sep = "\t", header = TRUE)

pathname <- c(args[1])
sampleid <- c(args[2])
outputdir <- c(args[3])
titlename <- paste("Coverage for", sampleid, sep=" ")
pdfname <- paste(sampleid,"_coverage.pdf", sep = "")
outputfile <- paste(outputdir,pdfname, sep = "/")


covplot <- ggplot() + 
  geom_line(aes(y = coverage, x = pos), data = covtsv.data, color="Red") + 
  scale_x_continuous(breaks=seq(0,18000,1000)) +
  scale_color_brewer(palette="Dark2") + 
  labs(title = titlename, x = "BP Position", y = "Coverage", caption = pathname)


pdf(file= outputfile, width = 13, height = 9)
print(covplot)
dev.off()
