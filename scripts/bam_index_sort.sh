#!/bin/bash

#loop to sort bams

bamdir=$1
sortdir=$2

cd $bamdir

for f in *.bam; do
	filename="${f%%.*}"
	samtools sort $f > $sortdir/${filename}.sorted.bam
done

cd $sortdir
#loop to index bams
for f in *.sorted.bam; do
	filename="${f%%.*}"
	samtools index ${filename}.sorted.bam
done;

# usage
# /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/bam_index_sort.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/BAM_BH14153 /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/BAM_BH14153/sorted

# /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/bam_index_sort.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/DDL_200708_HKLMMDRXX_51583 /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/DDL_200708_HKLMMDRXX_51583/sorted

# /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/bam_index_sort.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/DDL_200715_HN7JWDRXX_51599 /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/DDL_200715_HN7JWDRXX_51599/sorted