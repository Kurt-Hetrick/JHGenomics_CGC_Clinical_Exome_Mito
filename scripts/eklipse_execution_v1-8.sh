#!/bin/bash

#requires python 2.7 and biopython libraries installed

#########error reporting###########
# exit when any command fails
set -e
# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT
###################################



#argument order for script

input=$1 #path of metadata directory
outdir=$2 #path of project folder

(#run log start

#execution loop
cd $input

for f in *.txt; do 
	SM_TAG="${f%%.*}"
	mkdir $outdir/$SM_TAG
	outfold=$outdir/$SM_TAG
	
	(#sample log start
	
	#run eKLIPse
	python /mnt/research/statgen/mitoAnalyzer/eKLIPse_v1-8/eKLIPse.py \
		-in $f \
		-ref /mnt/research/statgen/mitoAnalyzer/eKLIPse/data/NC_012920.1.gb \
		-samtools /mnt/research/tools/LINUX/SAMTOOLS/samtools-1.9/samtools \
		-blastn /mnt/linuxtools/BLAST/ncbi-blast-2.9.0+/bin/blastn \
		-circos /mnt/research/statgen/mitoAnalyzer/circos-0.69-9/bin/circos \
		-makeblastdb /mnt/linuxtools/BLAST/ncbi-blast-2.9.0+/bin/makeblastdb \
		-thread 7 \
		-downcov 0 \
		-scsize 15 \
		-mapsize 10 \
		-out $outfold
		
	) | tee $outfold/sample_run.log 
	
	#attempt to remove asci coding in log
	#sed 's/\^\[\[3J\^\[\[H\^\[\[2J\^\[\[1;33m//g; s/\^\[\[0m\^\[\[0;33m//g; s/\^\[\[0m\^\[\[1;33m//g; s/\^\[\[0m|\^H\/\^H\-\^H\^H//g; s/\^\[\[1;37m//g; s/\^\[\[0m\^\[\[0;37m//g; s/\^\[\[0m//g; s/\^H//g; s/\^\[\[1;32m//g; s/\^\[\[0;32m//g' sample_run.log > sample_run_clean.log
	
	#temporary fix to log problem
	sed -i '1s/^/ \n This file contains ASCI terminal color and formatting codes\. To view unformatted, use <cat filename> on a linux system to display the file\. \n /' $outfold/sample_run.log

done;



) | tee $outdir/run.log




##usage
#	nohup /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/eklipse_execution_v1-8.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/run2_v1-8/metadata /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/run2_v1-8 &
#	nohup /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/eklipse_execution_v1-8.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/BH14153/metadata /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/BH14153 &

#	nohup /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/eklipse_execution_v1-8.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/DDL_200708_HKLMMDRXX_51583/metadata /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/DDL_200708_HKLMMDRXX_51583 &
#	nohup /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/eklipse_execution_v1-8.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/DDL_200715_HN7JWDRXX_51599/metadata /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/DDL_200715_HN7JWDRXX_51599 &
