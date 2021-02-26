#!/bin/bash

#########Usage##############
#currently compatible with GRCh37

#runs on a directory of sorted BAM/BAI files

#	nohup /mnt/research/statgen/gatk-4.1.3.0/scripts/mitomode_bams.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/BAM/sorted /mnt/research/statgen/gatk-4.1.3.0/results/ClinExome_2020/Coriell_full_plusgnomAD /mnt/research/tools/PIPELINE_FILES/bwa_mem_0.7.5a_ref/human_g1k_v37_decoy.fasta &

#	nohup /mnt/research/statgen/gatk-4.1.3.0/scripts/mitomode_bams.sh /mnt/clinical/ddl/NGS/Exome_Data/DDL_200820_HNYMLDRXX_51612_PIPELINE_2_0_0/TEMP/ /mnt/research/statgen/gatk-4.1.3.0/results/ClinExome_2020/DDL_200820_HNYMLDRXX_51612_plusgnomAD /mnt/research/tools/PIPELINE_FILES/bwa_mem_0.7.5a_ref/human_g1k_v37_decoy.fasta &

#	nohup /mnt/research/statgen/gatk-4.1.3.0/scripts/mitomode_bams.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/BAM_BH14153/sorted  /mnt/research/statgen/gatk-4.1.3.0/results/ClinExome_2020/BH14153_plusgnomAD /mnt/research/tools/PIPELINE_FILES/bwa_mem_0.7.5a_ref/human_g1k_v37_decoy.fasta &

#	nohup /mnt/research/statgen/gatk-4.1.3.0/scripts/mitomode_bams.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/DDL_200708_HKLMMDRXX_51583/sorted /mnt/research/statgen/gatk-4.1.3.0/results/ClinExome_2020/DDL_200708_HKLMMDRXX_51583_plusgnomAD /mnt/research/tools/PIPELINE_FILES/bwa_mem_0.7.5a_ref/human_g1k_v37_decoy.fasta &

#	nohup /mnt/research/statgen/gatk-4.1.3.0/scripts/mitomode_bams.sh /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/DDL_200715_HN7JWDRXX_51599/sorted /mnt/research/statgen/gatk-4.1.3.0/results/ClinExome_2020/DDL_200715_HN7JWDRXX_51599_plusgnomAD /mnt/research/tools/PIPELINE_FILES/bwa_mem_0.7.5a_ref/human_g1k_v37_decoy.fasta &
############################


#########error reporting###########
# exit when any command fails
set -e
# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT
###################################


#argument order

input=$1 #full path to bam directory
outdir=$2 #full path to project folder
ref=$3 #ful path to reference used to align bams/crams

( #full run log start


#move to input directory
cd $input

#loops through input directory
for file in *.bam; do 
	SAMPLE_ID="${file%%.*}"
	extens="${file#*.}"
	bampath=$input/$SAMPLE_ID'.'$extens
	
	#make and move to sample folder
	mkdir $outdir/$SAMPLE_ID
	cd $outdir/$SAMPLE_ID

	( #sample run log start
	
	#Collect HS Metrics -- coverage using custom interval list for GRCh37
	echo -e "\n\n BAM file analysis -- CollectHSMetrics is running... \n"
	/mnt/research/statgen/gatk-4.1.3.0/gatk CollectHsMetrics \
		-I $bampath \
		-O $SAMPLE_ID".output.metrics" \
		-R $ref \
		-PER_BASE_COVERAGE $SAMPLE_ID"_per_base_cov.tsv" \
		-TI /mnt/research/statgen/gatk-4.1.3.0/results/ClinExome_2020/MT.interval_list \
		-BI /mnt/research/statgen/gatk-4.1.3.0/results/ClinExome_2020/MT.interval_list



	#mutect2 mitomode arguments
	echo -e "\n\n Mitomode -- Single Alignment Mitochondrial Analysis powered by GATK 4.1.3.0 -- running on $SAMPLE_ID \n"
	/mnt/research/statgen/gatk-4.1.3.0/gatk Mutect2 \
		--mitochondria-mode true \
		--max-mnp-distance 0 \
		--output ./raw.vcf \
		--max-reads-per-alignment-start 75 \
		--intervals MT:1-16569 \
		--input $bampath \
		--reference $ref \
		--annotation StrandBiasBySample \
		--max-disc-ar-extension 25 \
		--max-gga-ar-extension 300 \
		--padding-around-indels 150 \
		--padding-around-snps 20 \
		--pruning-lod-threshold 1.0 \
		--debug-graph-transformations false \
		--capture-assembly-failure-bam false \
		--error-correct-reads false \
		--kmer-length-for-read-error-correction 25 \
		--min-observations-for-kmer-to-be-solid 20 \
		--likelihood-calculation-engine PairHMM



	#Filter
	echo -e "\n\n Mitomode complete. Filtering variants... \n"
	/mnt/research/statgen/gatk-4.1.3.0/gatk FilterMutectCalls \
		--output ./filtered.vcf \
		--stats ./raw.vcf.stats \
		--mitochondria-mode true \
		--max-alt-allele-count 4 \
		--min-allele-fraction 0.03 \
		--contamination-estimate 0.0 \
		--variant ./raw.vcf \
		--reference $ref



	#masks
	echo -e "\n\n Filtering complete. Applying Masks and Filters to VCF output... \n"
	/mnt/research/statgen/gatk-4.1.3.0/gatk VariantFiltration \
		--mask /mnt/research/statgen/mitoAnalyzer/Projects/ClinExomeTwist_2020/inputs/hg37_MT_blacklist_sites.hg37.MT.bed \
		--output $SAMPLE_ID".vcf" \
		--mask-name blacklisted_site \
		--variant ./filtered.vcf


	#create chrM tagged version of output vcf for downstream applications
	sed 's/MT/chrM/g' $SAMPLE_ID".vcf" > $SAMPLE_ID"_chrM.vcf"
	
	
	#bgzip intermediate for annovar
	bgzip -c $SAMPLE_ID".vcf" > $SAMPLE_ID".vcf.gz"
	tabix $SAMPLE_ID".vcf.gz"
	
	
	#add gnomad annotations to vcf intermediate file with bcftools
	/mnt/research/tools/LINUX/BCFTOOLS/bcftools-1.10.2/bcftools annotate --force -a /mnt/research/statgen/gatk-4.1.3.0/annovar_resources/2019/annovar/humandb/GRCh37_MT_gnomAD.vcf.gz -c INFO $SAMPLE_ID".vcf.gz" > $SAMPLE_ID".intermediate.vcf"
	


	#run annotation for SAMPLE_ID, will generate several files, among them a multiannotation text file
	echo -e "\n\n Variant Analysis complete for $SAMPLE_ID. Annoating variants with ANNOVAR 2019... \n"
	mkdir $outdir/$SAMPLE_ID/anno2019vers
	mkdir $outdir/$SAMPLE_ID/anno2019vers/withCV_DB150 
	perl /mnt/research/statgen/gatk-4.1.3.0/annovar_resources/2019/annovar/table_annovar.pl $SAMPLE_ID".intermediate.vcf" /mnt/research/statgen/gatk-4.1.3.0/annovar_resources/2019/annovar/humandb/ \
		--outfile $outdir/$SAMPLE_ID/anno2019vers/withCV_DB150/$SAMPLE_ID \
		--buildver GRCh37_MT \
		--protocol ensGene,vcf,vcf,vcf,clinvar_20200316,avsnp150 \
		--operation g,f,f,f,f,f \
		--vcfdbfile GRCh37_MT_MMpolymorphisms.vcf,GRCh37_MT_MMdisease.vcf,GRCh37_MT_gnomAD.vcf \
		--vcfinput
	#alter multianno.txt headers
	sed -i -e '1s/vcf3/gnomAD/' -e '1s/vcf2/GB_Freq.MMdisease/' -e '1s/vcf/GB_Freq.MMpolymorphisms/' -e '1s/Otherinfo11/gnomADplusVCF-INFO/' $outdir/$SAMPLE_ID/anno2019vers/withCV_DB150/$SAMPLE_ID".GRCh37_MT_multianno.txt"
	
	
	#run Haplogrep2 for haplotype classification; default rCRS
	echo -e "\n\n Annotation complete for $SAMPLE_ID. Running Haplotype prediction software Haplogrep2... \n"
	mkdir $outdir/$SAMPLE_ID/Haplotypes
	java -jar /mnt/research/statgen/mitoAnalyzer/Haplogrep2/haplogrep-2.1.20.jar \
		--in $SAMPLE_ID".vcf" \
		--out $outdir/$SAMPLE_ID/Haplotypes/$SAMPLE_ID".haplotypes.txt" \
		--extend-report \
		--format vcf \
		--hits 5
	
	echo -e "\n\n Haplotype Analysis complete for $SAMPLE_ID."
	
	
	) | tee $outdir/$SAMPLE_ID/sample_run.log
	

	
done; ) | tee $outdir/full_run.log