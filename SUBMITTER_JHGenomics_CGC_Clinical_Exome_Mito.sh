#!/usr/bin/env bash

# INPUT VARIABLES

	SAMPLE_SHEET=$1

	PRIORITY=$2 # optional. how high you want the tasks to have when submitting.
		# if no 2nd argument present then the default is -9.

			if [[ ! $PRIORITY ]]
				then
				PRIORITY="-9"
			fi

	QUEUE_LIST=$3 # optional. the queues that you want to submit to.
		# if you want to set this then you need to set the 2nd argument as well (even to the default)
		# if no 3rd argument present then the default is cgc.q

			if [[ ! $QUEUE_LIST ]]
				then
				QUEUE_LIST="cgc.q"
			fi

	THREADS=$4 # optional. how many cpu processors you want to use for programs that are multi-threaded
		# if you want to set this then you need to set the 3rd argument as well (even to the default)
		# if no 4th argument present then the default is 6

			if [[ ! $THREADS ]]
				then
				THREADS="6"
			fi

# CHANGE SCRIPT DIR TO WHERE YOU HAVE HAVE THE SCRIPTS BEING SUBMITTED

	SUBMITTER_SCRIPT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

	SCRIPT_DIR="$SUBMITTER_SCRIPT_PATH/scripts"

##################
# CORE VARIABLES #
##################

	## This will always put the current working directory in front of any directory for PATH
	## added /bin for RHEL6

		export PATH=".:$PATH:/bin"

	# where the input/output sequencing data will be located.

		CORE_PATH="/mnt/clinical/ddl/NGS/Exome_Data"

	# Directory where NovaSeqa runs are located.

		NOVASEQ_REPO="/mnt/instrument_files/novaseq"

	# used for tracking in the read group header of the cram file

		PIPELINE_VERSION=`git --git-dir=$SCRIPT_DIR/../.git --work-tree=$SCRIPT_DIR/.. log --pretty=format:'%h' -n 1`

	# load gcc for programs like verifyBamID
	## this will get pushed out to all of the compute nodes since I specify env var to pushed out with qsub

		module load gcc/7.2.0

	# explicitly setting this b/c not everybody has had the $HOME directory transferred and I'm not going to through
	# and figure out who does and does not have this set correctly

		umask 0007

	# SUBMIT TIMESTAMP

		SUBMIT_STAMP=`date '+%s'`

	# SUBMITTER_ID

		SUBMITTER_ID=`whoami`

	# bind the host file system /mnt to the singularity container. in case I use it in the submitter.

		export SINGULARITY_BINDPATH="/mnt:/mnt"

	# QSUB ARGUMENTS LIST
		# set shell on compute node
		# start in current working directory
		# transfer submit node env to compute node
		# set SINGULARITY BINDPATH
		# set queues to submit to
		# set priority
		# combine stdout and stderr logging to same output file

			QSUB_ARGS="-S /bin/bash" \
				QSUB_ARGS=$QSUB_ARGS" -cwd" \
				QSUB_ARGS=$QSUB_ARGS" -V" \
				QSUB_ARGS=$QSUB_ARGS" -v SINGULARITY_BINDPATH=/mnt:/mnt" \
				QSUB_ARGS=$QSUB_ARGS" -p $PRIORITY" \
				QSUB_ARGS=$QSUB_ARGS" -j y"

		# $QSUB_ARGS WILL BE A GENERAL BLOCK APPLIED TO ALL JOBS
		# BELOW ARE TIMES WHEN WHEN A QSUB ARGUMENT IS ADDED OR CHANGED.

			# DEFINE STANDARD LIST OF SERVERS TO SUBMIT TO.
			# THIS IS DEFINED AS AN INPUT ARGUMENT VARIABLE TO THE PIPELINE (DEFAULT: cgc.q)

				STANDARD_QUEUE_QSUB_ARG=" -q $QUEUE_LIST"

			# SPLICEAI WILL NOT RUN ON SERVERS THAT DO NOT HAVE INTEL AVX CHIPSETS.
			# which for us is the c6100s (prod.q and rnd.q).
			# so I am removing those from $QUEUE_LIST if present and create a new variable to run spliceai

				SPLICEAI_QUEUE_QSUB_ARG=$(echo " -q $QUEUE_LIST" | sed 's/rnd.q//g' | sed 's/prod.q//g')

			# REQUESTING AN ENTIRE SERVER (specifically for cgc.q)

				REQUEST_ENTIRE_SERVER_QSUB_ARG=" -pe slots 5"

#####################
# PIPELINE PROGRAMS #
#####################

	ALIGNMENT_CONTAINER="/mnt/clinical/ddl/NGS/CFTR_Full_Gene_Sequencing_Pipeline/containers/ddl_ce_control_align-0.0.4.simg"
		# contains the following software and is on Ubuntu 16.04.5 LTS
			# gatk 4.0.11.0 (base image). also contains the following.
				# Python 3.6.2 :: Continuum Analytics, Inc.
					# samtools 0.1.19
					# bcftools 0.1.19
					# bedtools v2.25.0
					# bgzip 1.2.1
					# tabix 1.2.1
					# samtools, bcftools, bgzip and tabix will be replaced with newer versions.
					# R 3.2.5
						# dependencies = c("gplots","digest", "gtable", "MASS", "plyr", "reshape2", "scales", "tibble", "lazyeval")    # for ggplot2
						# getopt_1.20.0.tar.gz
						# optparse_1.3.2.tar.gz
						# data.table_1.10.4-2.tar.gz
						# gsalib_2.1.tar.gz
						# ggplot2_2.2.1.tar.gz
					# openjdk version "1.8.0_181"
					# /gatk/gatk.jar -> /gatk/gatk-package-4.0.11.0-local.jar
			# added
				# picard.jar 2.17.0 (as /gatk/picard.jar)
				# samblaster-v.0.1.24
				# sambamba-0.6.8
				# bwa-0.7.15
				# datamash-1.6
				# verifyBamID v1.1.3
				# samtools 1.10
				# bgzip 1.10
				# tabix 1.10
				# bcftools 1.10.2
				# parallel 20161222

	GATK_3_7_0_CONTAINER="/mnt/clinical/ddl/NGS/CFTR_Full_Gene_Sequencing_Pipeline/containers/gatk3-3.7-0.simg"
		# singularity pull docker://broadinstitute/gatk3:3.7-0
			# used for generating the depth of coverage reports.
				# comes with R 3.1.1 with appropriate packages needed to create gatk pdf output
				# also comes with some version of java 1.8
				# jar file is /usr/GenomeAnalysisTK.jar

	GATK_3_5_0_CONTAINER="/mnt/clinical/ddl/NGS/CFTR_Full_Gene_Sequencing_Pipeline/containers/gatk3-3.5-0.simg"
		# singularity pull docker://broadinstitute/gatk3:3.7-0

	MANTA_CONTAINER="/mnt/clinical/ddl/NGS/CFTR_Full_Gene_Sequencing_Pipeline/containers/manta-1.6.0.0.simg"
		# singularity 2 creates a simg file (this is what I used)
		# singularity 3 (this is what the cgc nodes have) creates a .sif file

	SPLICEAI_CONTAINER="/mnt/clinical/ddl/NGS/CFTR_Full_Gene_Sequencing_Pipeline/containers/spliceai-1.3.1.1.simg"
		# singularity pull docker://ubuntudocker.jhgenomics.jhu.edu:443/illumina/spliceai:1.3.1.1
			# has to run an servers where the CPU supports AVX
			# the only ones that don't are the c6100s (prod.q,rnd.q,c6100-4,c6100-8)

	VEP_CONTAINER="/mnt/clinical/ddl/NGS/CFTR_Full_Gene_Sequencing_Pipeline/containers/vep-102.0.simg"

	CRYPTSPLICE_CONTAINER="/mnt/clinical/ddl/NGS/CFTR_Full_Gene_Sequencing_Pipeline/containers/cryptsplice-1.simg"

	VT_CONTAINER="/mnt/clinical/ddl/NGS/CFTR_Full_Gene_Sequencing_Pipeline/containers/vt-0.5772.ca352e2c.0.simg"

	ANNOVAR_CONTAINER="/mnt/clinical/ddl/NGS/CFTR_Full_Gene_Sequencing_Pipeline/containers/annovarwrangler-20210126.simg"

	COMBINE_ANNOVAR_WITH_SPLICING_R_CONTAINER="/mnt/clinical/ddl/NGS/CFTR_Full_Gene_Sequencing_Pipeline/containers/r-cftr-3.4.4.1.simg"

	COMBINE_ANNOVAR_WITH_SPLICING_R_SCRIPT="$SCRIPT_DIR/CombineCryptSpliceandSpliceandmergeAnnovar_andmergeCFTR2-02.16.2021fix.R"

##################
# PIPELINE FILES #
##################

	MT_PICARD_INTERVAL_LIST="/mnt/clinical/ddl/NGS/Exome_Resources/PIPELINES/JHGenomics_CGC_Clinical_Exome_Mito/resources/ClinExome_2020/MT.interval_list"

	VERIFY_VCF="/mnt/clinical/ddl/NGS/CFTR_Full_Gene_Sequencing_Pipeline/resources/config_misc/Omni25_genotypes_1525_samples_v2.b37.PASS.ALL.sites.vcf"

	# ANNOVAR PARAMETERS AND INPUTS
		ANNOVAR_DATABASE_FILE="/mnt/clinical/ddl/NGS/CFTR_Full_Gene_Sequencing_Pipeline/resources/config_misc/CFTR.final.csv"
		ANNOVAR_REF_BUILD="hg19"

		ANNOVAR_INFO_FIELD_KEYS="VariantType," \
			ANNOVAR_INFO_FIELD_KEYS=$ANNOVAR_INFO_FIELD_KEYS"DP" \

		ANNOVAR_HEADER_MAPPINGS="af=gnomad211_exome_AF," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"af_popmax=gnomad211_exome_AF_popmax," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"af_male=gnomad211_exome_AF_male," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"af_female=gnomad211_exome_AF_female," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"af_raw=gnomad211_exome_AF_raw," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"af_afr=gnomad211_exome_AF_afr," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"af_sas=gnomad211_exome_AF_sas," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"af_amr=gnomad211_exome_AF_amr," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"af_eas=gnomad211_exome_AF_eas," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"af_nfe=gnomad211_exome_AF_nfe," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"af_fin=gnomad211_exome_AF_fin," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"af_asj=gnomad211_exome_AF_asj," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"af_oth=gnomad211_exome_AF_oth," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"non_topmed_af_popmax=gnomad211_exome_non_topmed_AF_popmax," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"non_neuro_af_popmax=gnomad211_exome_non_neuro_AF_popmax," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"non_cancer_af_popmax=gnomad211_exome_non_cancer_AF_popmax," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"controls_af_popmax=gnomad211_exome_controls_AF_popmax," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF=gnomad211_genome_AF," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF_popmax=gnomad211_genome_AF_popmax," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF_male=gnomad211_genome_AF_male," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF_female=gnomad211_genome_AF_female," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF_raw=gnomad211_genome_AF_raw," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF_afr=gnomad211_genome_AF_afr," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF_sas=gnomad211_genome_AF_sas," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF_amr=gnomad211_genome_AF_amr," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF_eas=gnomad211_genome_AF_eas," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF_nfe=gnomad211_genome_AF_nfe," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF_fin=gnomad211_genome_AF_fin," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF_asj=gnomad211_genome_AF_asj," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"AF_oth=gnomad211_genome_AF_oth," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"non_topmed_AF_popmax=gnomad211_genome_non_topmed_AF_popmax," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"non_neuro_AF_popmax=gnomad211_genome_non_neuro_AF_popmax," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"non_cancer_AF_popmax=gnomad211_genome_non_cancer_AF_popmax," \
			ANNOVAR_HEADER_MAPPINGS=$ANNOVAR_HEADER_MAPPINGS"controls_AF_popmax=gnomad211_genome_controls_AF_popmax"

			ANNOVAR_VCF_COLUMNS="CHROM,"
				ANNOVAR_VCF_COLUMNS=$ANNOVAR_VCF_COLUMNS"POS,"
				ANNOVAR_VCF_COLUMNS=$ANNOVAR_VCF_COLUMNS"REF,"
				ANNOVAR_VCF_COLUMNS=$ANNOVAR_VCF_COLUMNS"ALT"

#################################
##### MAKE A DIRECTORY TREE #####
#################################

##### CREATING A DIRECTORY IN USER'S HOME TO MERGE THE SAMPLE MANIFEST WITH THE PED FILE

	mkdir -p ~/CGC_PIPELINE_TEMP

	MANIFEST_PREFIX=`basename $SAMPLE_SHEET .csv`
	PED_PREFIX=`basename $PED_FILE .ped`

	FORMAT_MANIFEST ()
	{
		awk 1 $SAMPLE_SHEET \
		| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
		| awk 'NR>1' \
		| sed 's/,/\t/g' \
		| sort -k 8,8 \
		>| ~/CGC_PIPELINE_TEMP/SORTED.$MANIFEST_PREFIX.txt
	}

	MERGE_PED_MANIFEST ()
	{
		awk 1 $PED_FILE \
		| sed 's/\r//g' \
		| sort -k 2,2 \
		| join -1 8 -2 2 -e '-'  -t $'\t' \
		-o '1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9,1.10,1.11,1.12,1.13,1.14,1.15,1.16,1.17,1.18,1.19,2.1,2.3,2.4,2.5,2.6' \
		~/CGC_PIPELINE_TEMP/SORTED.$MANIFEST_PREFIX.txt /dev/stdin \
		>| ~/CGC_PIPELINE_TEMP/$MANIFEST_PREFIX.$PED_PREFIX.join.txt
	}

	CREATE_SAMPLE_ARRAY ()
	{
		SAMPLE_ARRAY=(`awk 'BEGIN {FS="\t"; OFS="\t"} $8=="'$SAMPLE'" \
			{split($19,INDEL,";"); \
			print $1,$8,$9,$10,$12,$15,$16,$17,$18,INDEL[1],INDEL[2],$20,$21,$22,$23,$24}' \
				~/CGC_PIPELINE_TEMP/$MANIFEST_PREFIX.$PED_PREFIX.join.txt \
				| sort \
				| uniq`)

		#  1  Project=the Seq Proj folder name

			PROJECT=${SAMPLE_ARRAY[0]}

		################################################################################
		# 2 SKIP : FCID=flowcell that sample read group was performed on ###############
		# 3 SKIP : Lane=lane of flowcell that sample read group was performed on] ######
		# 4 SKIP : Index=sample barcode ################################################
		# 5 SKIP : Platform=type of sequencing chemistry matching SAM specification ####
		# 6 SKIP : Library_Name=library group of the sample read group #################
		# 7 SKIP : Date=should be the run set up date to match the seq run folder name #
		################################################################################

		#  8  SM_Tag=sample ID

			SM_TAG=${SAMPLE_ARRAY[1]}
				SGE_SM_TAG=$(echo $SM_TAG | sed 's/@/_/g') # If there is an @ in the qsub or holdId name it breaks

		#  9  Center=the center/funding mechanism

			CENTER=${SAMPLE_ARRAY[2]}

		# 10  Description=Generally we use to denote the sequencer setting (e.g. rapid run)
		# “HiSeq-X”, “HiSeq-4000”, “HiSeq-2500”, “HiSeq-2000”, “NextSeq-500”, or “MiSeq”.

			SEQUENCER_MODEL=${SAMPLE_ARRAY[3]}

		#########################
		# 11  SKIP : Seq_Exp_ID #
		#########################

		# 12  Genome_Ref=the reference genome used in the analysis pipeline

			REF_GENOME=${SAMPLE_ARRAY[4]}

		#####################################
		# 13  Operator: SKIP ################
		# 14  Extra_VCF_Filter_Params: SKIP #
		#####################################

		# 15  TS_TV_BED_File=where ucsc coding exons overlap with bait and target bed files

			TITV_BED=${SAMPLE_ARRAY[5]}

		# 16  Baits_BED_File=a super bed file incorporating bait, target, padding and overlap with ucsc coding exons.
		# Used for limited where to run base quality score recalibration on where to create gvcf files.

			BAIT_BED=${SAMPLE_ARRAY[6]}

		# 17  Targets_BED_File=bed file acquired from manufacturer of their targets.

			TARGET_BED=${SAMPLE_ARRAY[7]}

		# 18  KNOWN_SITES_VCF=used to annotate ID field in VCF file. masking in base call quality score recalibration.

			DBSNP=${SAMPLE_ARRAY[8]}

		# 19  KNOWN_INDEL_FILES=used for BQSR masking, sensitivity in local realignment.

			KNOWN_INDEL_1=${SAMPLE_ARRAY[9]}
			KNOWN_INDEL_2=${SAMPLE_ARRAY[10]}

		# 20 family that sample belongs to

			FAMILY=${SAMPLE_ARRAY[11]}

		# 21 MOM

			MOM=${SAMPLE_ARRAY[12]}

		# 22 DAD

			DAD=${SAMPLE_ARRAY[13]}

		# 23 GENDER

			GENDER=${SAMPLE_ARRAY[14]}

		# 24 PHENOTYPE

			PHENOTYPE=${SAMPLE_ARRAY[15]}
	}

# PROJECT DIRECTORY TREE CREATOR

	MAKE_PROJ_DIR_TREE ()
	{
		mkdir -p $CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/LOGS \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/CRAM \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/HC_CRAM \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/INDEL/{FILTERED_ON_BAIT,FILTERED_ON_TARGET} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/SNV/{FILTERED_ON_BAIT,FILTERED_ON_TARGET} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/MIXED/{FILTERED_ON_BAIT,FILTERED_ON_TARGET} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/VCF/{FILTERED_ON_BAIT,FILTERED_ON_TARGET} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/GVCF \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/MITO_OUTPUT/mitomode_results \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/MITO_OUTPUT/eklipse_results \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/{ALIGNMENT_SUMMARY,ANNOVAR,PICARD_DUPLICATES,TI_TV,VERIFYBAMID,VERIFYBAMID_AUTO,RG_HEADER,QUALITY_YIELD,ERROR_SUMMARY} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/BAIT_BIAS/{METRICS,SUMMARY} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/PRE_ADAPTER/{METRICS,SUMMARY} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/BASECALL_Q_SCORE_DISTRIBUTION/{METRICS,PDF} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/BASE_DISTRIBUTION_BY_CYCLE/{METRICS,PDF} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/CONCORDANCE \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/COUNT_COVARIATES/{GATK_REPORT,PDF} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/GC_BIAS/{METRICS,PDF,SUMMARY} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/DEPTH_OF_COVERAGE/{TARGET_PADDED,CODING_PADDED} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/HYB_SELECTION/PER_TARGET_COVERAGE \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/INSERT_SIZE/{METRICS,PDF} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/LOCAL_REALIGNMENT_INTERVALS \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/MEAN_QUALITY_BY_CYCLE/{METRICS,PDF} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/ANEUPLOIDY_CHECK \
		$CORE_PATH/$PROJECT/$FAMILY/{LOGS,VCF,RELATEDNESS,PCA} \
		$CORE_PATH/$PROJECT/TEMP/$SM_TAG_ANNOVAR \
		$CORE_PATH/$PROJECT/TEMP/{VCF_PREP,PLINK,KING} \
		$CORE_PATH/$PROJECT/{TEMP,FASTQ,REPORTS,LOGS,COMMAND_LINES}
	}

	SETUP_PROJECT ()
	{
		FORMAT_MANIFEST
		MERGE_PED_MANIFEST
		CREATE_SAMPLE_ARRAY
		MAKE_PROJ_DIR_TREE
		echo Project started at `date` >| $CORE_PATH/$PROJECT/REPORTS/PROJECT_START_END_TIMESTAMP.txt
	}

for SAMPLE in $(awk 1 $SAMPLE_SHEET \
		| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
		| awk 'BEGIN {FS=","} NR>1 {print $8}' \
		| sort \
		| uniq );
	do
		SETUP_PROJECT
done

	######################################
	# convert full cram file back to bam #
	######################################

		CRAM_TO_BAM_FULL ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A01-CRAM_TO_BAM_FULL"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-CRAM_TO_BAM_FULL.log" \
			$SCRIPT_DIR/A01-CRAM_TO_BAM_FULL.sh \
				$ALIGNMENT_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$FAMILY \
				$SM_TAG \
				$REF_GENOME \
				$THREADS \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

	##############################################################
	# convert cram file back to bam just for mitochondrial reads #
	##############################################################

		CRAM_TO_BAM_MT ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A02-CRAM_TO_BAM_MT"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-CRAM_TO_BAM_MT.log" \
			$SCRIPT_DIR/A02-CRAM_TO_BAM_MT.sh \
				$ALIGNMENT_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$FAMILY \
				$SM_TAG \
				$REF_GENOME \
				$THREADS \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

	######################################
	# convert full cram file back to bam #
	######################################

		COLLECTHSMETRICS_MT ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A01-A01-COLLECTHSMETRICS_MT"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-COLLECTHSMETRICS_MT.log" \
				-hold_jid A01-CRAM_TO_BAM_FULL"_"$SGE_SM_TAG"_"$PROJECT \
			$SCRIPT_DIR/A02-CRAM_TO_BAM_MT.sh \
				$ALIGNMENT_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$SM_TAG \
				$REF_GENOME \
				$MT_PICARD_INTERVAL_LIST \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

	#####################################################
	# run mutect2 in mitochondria mode on full bam file #
	#####################################################

		MUTECT2_MT ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A01-A02-MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-MUTECT2_MT.log" \
				-hold_jid A01-CRAM_TO_BAM_FULL"_"$SGE_SM_TAG"_"$PROJECT \
			$SCRIPT_DIR/A02-CRAM_TO_BAM_MT.sh \
				$ALIGNMENT_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$SM_TAG \
				$REF_GENOME \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

##############################################
# run alignment steps after bwa to cram file #
##############################################

for SAMPLE in $(awk 1 $SAMPLE_SHEET \
		| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
		| awk 'BEGIN {FS=","} NR>1 {print $8}' \
		| sort \
		| uniq );
	do
		CREATE_SAMPLE_ARRAY
		CRAM_TO_BAM_FULL
		echo sleep 0.1s
		CRAM_TO_BAM_MT
		echo sleep 0.1s
		COLLECTHSMETRICS_MT
		echo sleep 0.1s
		MUTECT2_MT
		echo sleep 0.1s
done

#############################
##### END PROJECT TASKS #####
#############################

# grab email addy

	SEND_TO=`cat $SCRIPT_DIR/../email_lists.txt`

# grab submitter's name

	PERSON_NAME=`getent passwd | awk 'BEGIN {FS=":"} $1=="'$SUBMITTER_ID'" {print $5}'`

# build hold id for qc report prep per sample, per project

	BUILD_HOLD_ID_PATH_PROJECT_WRAP_UP ()
	{
		HOLD_ID_PATH="-hold_jid "

		for SAMPLE in $(awk 1 $SAMPLE_SHEET \
			| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
			| awk 'BEGIN {FS=","} $1=="'$PROJECT'" {print $8}' \
			| sort \
			| uniq);
		do
			CREATE_SAMPLE_ARRAY
			HOLD_ID_PATH=$HOLD_ID_PATH"X.01_QC_REPORT_PREP"_"$SGE_SM_TAG"_"$PROJECT"","
			HOLD_ID_PATH=`echo $HOLD_ID_PATH | sed 's/@/_/g'`
		done
	}

# run end project functions (qc report, file clean-up) for each project

	PROJECT_WRAP_UP ()
	{
		echo \
		qsub \
			$QSUB_ARGS \
			$STANDARD_QUEUE_QSUB_ARG \
		-N X.01-X.01_END_PROJECT_TASKS"_"$PROJECT \
			-o $CORE_PATH/$PROJECT/LOGS/$PROJECT"-END_PROJECT_TASKS.log" \
		$HOLD_ID_PATH \
		$SCRIPT_DIR/X.01-X.01-END_PROJECT_TASKS.sh \
			$ALIGNMENT_CONTAINER \
			$CORE_PATH \
			$PROJECT \
			$SCRIPT_DIR \
			$SUBMITTER_ID \
			$SAMPLE_SHEET \
			$SUBMIT_STAMP \
			$SEND_TO \
			$THREADS
	}

# final loop

for PROJECT in $(awk 1 $SAMPLE_SHEET \
			| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
			| awk 'BEGIN {FS=","} NR>1 {print $1}' \
			| sort \
			| uniq);
	do
		BUILD_HOLD_ID_PATH_PROJECT_WRAP_UP
		PROJECT_WRAP_UP
done

# MESSAGE THAT SAMPLE SHEET HAS FINISHED SUBMITTING

printf "echo\n"

printf "echo $SAMPLE_SHEET has finished submitting at `date`\n"

# EMAIL WHEN DONE SUBMITTING

printf "$SAMPLE_SHEET\nhas finished submitting at\n`date`\nby `whoami`" \
	| mail -s "$PERSON_NAME has submitted SUBMITTER_CFTR_Full_Gene_Sequencing_Pipeline.sh" \
		$SEND_TO
