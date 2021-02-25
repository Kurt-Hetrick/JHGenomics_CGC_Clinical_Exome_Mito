#!/bin/bash

#########error reporting###########
# exit when any command fails
set -e
# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT
###################################

#argument order for script

input=$1 #path of mitochondrial reads bam directory
outdir=$2 #path of output folder


#folder setup
mkdir $outdir/metadata
metad=$outdir/metadata


#execution loop
cd $input
dir=$(pwd)

for f in *.bam; do 
	SM_TAG="${f%%.*}"
	extens="${f#*.}"
	echo -e "$dir/$SM_TAG.$extens\t$SM_TAG" > $metad/$SM_TAG".txt"
	
done;

##usage example
#
#	/mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/bamstoeKLIPse.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/BAM/mtdna /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/Coriel_full
#	/mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/bamstoeKLIPse.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/DDL_200820_HNYMLDRXX_51612/mtdna /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/DDL_200820_HNYMLDRXX_51612
#	/mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/bamstoeKLIPse.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/BAM_BH14153/mtdna /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/BH14153

#	/mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/bamstoeKLIPse.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/DDL_200708_HKLMMDRXX_51583/mtdna /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/DDL_200708_HKLMMDRXX_51583
#	/mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/bamstoeKLIPse.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/DDL_200715_HN7JWDRXX_51599/mtdna /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/eKLIPse/DDL_200715_HN7JWDRXX_51599