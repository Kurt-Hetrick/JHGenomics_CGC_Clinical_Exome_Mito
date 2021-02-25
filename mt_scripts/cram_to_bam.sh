#!/bin/bash

#loop to iterate over crams in a project folder and convert to bams 1000genomes phase 2 ref

cramdir=$1
bamdir=$2

cd $cramdir

for f in *.cram; do 
	filename="${f%%.*}"
	samtools view -b $f -o $bamdir/${filename}.bam -T /mnt/research/tools/PIPELINE_FILES/bwa_mem_0.7.5a_ref/human_g1k_v37_decoy.fasta
done

# /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/scripts/cram_to_bam.sh /mnt/research/active/M_Valle_MD_SeqWholeExome_120417_3/Released_Data/BH14153 /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/BAM_BH14153