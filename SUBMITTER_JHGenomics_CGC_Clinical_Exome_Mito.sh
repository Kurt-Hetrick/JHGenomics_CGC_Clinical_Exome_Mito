#!/usr/bin/env bash

# INPUT VARIABLES

	SAMPLE_SHEET=$1

	PED_FILE=$2

	PRIORITY=$3 # optional. how high you want the tasks to have when submitting.
		# if no 3rd argument present then the default is -9.

			if [[ ! $PRIORITY ]]
				then
				PRIORITY="-9"
			fi

	QUEUE_LIST=$4 # optional. the queues that you want to submit to.
		# if you want to set this then you need to set the 3rd argument as well (even to the default)
		# if no 4th argument present then the default is cgc.q

			if [[ ! $QUEUE_LIST ]]
				then
				QUEUE_LIST="cgc.q"
			fi

	THREADS=$5 # optional. how many cpu processors you want to use for programs that are multi-threaded
		# if you want to set this then you need to set the 4th argument as well (even to the default)
		# if no 5th argument present then the default is 6

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

	# grab email addy

		SEND_TO=`cat $SCRIPT_DIR/../email_lists.txt`

	# grab submitter's name

		PERSON_NAME=`getent passwd | awk 'BEGIN {FS=":"} $1=="'$SUBMITTER_ID'" {print $5}'`

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

#####################
# PIPELINE PROGRAMS #
#####################

	MITO_MUTECT2_CONTAINER="/mnt/clinical/ddl/NGS/Exome_Resources/PIPELINES/JHGenomics_CGC_Clinical_Exome_Mito/containers/mito_mutect2-4.1.3.0.0.simg"
		# uses broadinstitute/gatk:4.1.3.0 as the base image (as /gatk/gatk.jar)
			# added
				# bcftools-1.10.2
				# haplogrep-2.1.20.jar (as /jars/haplogrep-2.1.20.jar)
				# annovar

	MITO_EKLIPSE_CONTAINER="/mnt/clinical/ddl/NGS/Exome_Resources/PIPELINES/JHGenomics_CGC_Clinical_Exome_Mito/containers/mito_eklipse-master-c25931b.0.simg"
		# https://github.com/dooguypapua/eKLIPse AND all of its dependencies

	MT_COVERAGE_R_SCRIPT="$SCRIPT_DIR/mito_coverage_graph.r"

##################
# PIPELINE FILES #
##################

	MT_PICARD_INTERVAL_LIST="/mnt/clinical/ddl/NGS/Exome_Resources/PIPELINES/JHGenomics_CGC_Clinical_Exome_Mito/resources/MT.interval_list"

	MT_MASK="/mnt/clinical/ddl/NGS/Exome_Resources/PIPELINES/JHGenomics_CGC_Clinical_Exome_Mito/resources/hg37_MT_blacklist_sites.hg37.MT.bed"

	GNOMAD_MT="/mnt/clinical/ddl/NGS/Exome_Resources/PIPELINES/JHGenomics_CGC_Clinical_Exome_Mito/resources/GRCh37_MT_gnomAD.vcf.gz"

	ANNOVAR_MT_DB_DIR="/mnt/clinical/ddl/NGS/Exome_Resources/PIPELINES/JHGenomics_CGC_Clinical_Exome_Mito/resources/annovar_db/"

	MT_GENBANK="/mnt/clinical/ddl/NGS/Exome_Resources/PIPELINES/JHGenomics_CGC_Clinical_Exome_Mito/resources/NC_012920.1.gb"

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
			{split($18,INDEL,";"); \
			print $1,$8,$9,$10,$12,$14,$15,$16,$17,INDEL[1],INDEL[2],$20,$21,$22,$23,$24}' \
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
		mkdir -p $CORE_PATH/$PROJECT/{FASTQ,SUBMISSION_SETUP,TEMP,COMMAND_LINES} \
		$CORE_PATH/$PROJECT/LOGS/$SM_TAG \
		$CORE_PATH/$PROJECT/$FAMILY/{PCA,RELATEDNESS} \
		$CORE_PATH/$PROJECT/$FAMILY/VCF/{RAW,VQSR} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/BAM \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/GVCF \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/INDEL/{FILTERED_ON_BAIT,FILTERED_ON_TARGET} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/MIXED/{FILTERED_ON_BAIT,FILTERED_ON_TARGET} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/SNV/{FILTERED_ON_BAIT,FILTERED_ON_TARGET} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/VCF/{FILTERED_ON_BAIT,FILTERED_ON_TARGET} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/{ALIGNMENT_SUMMARY,ANEUPLOIDY_CHECK,ANNOVAR,LOCAL_REALIGNMENT_INTERVALS,PICARD_DUPLICATES,TI_TV,VERIFYBAMID,VERIFYBAMID_CHR,RG_HEADER,QUALITY_YIELD,ERROR_SUMMARY} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/BAIT_BIAS/{METRICS,SUMMARY} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/BASE_DISTRIBUTION_BY_CYCLE/{METRICS,PDF} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/BASECALL_Q_SCORE_DISTRIBUTION/{METRICS,PDF} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/COUNT_COVARIATES/{GATK_REPORT,PDF} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/DEPTH_OF_COVERAGE/{PADDED_REFSEQ_CODING,TARGET} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/GC_BIAS/{METRICS,PDF,SUMMARY} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/HYB_SELECTION/PER_TARGET_COVERAGE \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/INSERT_SIZE/{METRICS,PDF} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/MEAN_QUALITY_BY_CYCLE/{METRICS,PDF} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/REPORTS/PRE_ADAPTER/{METRICS,SUMMARY} \
		$CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/MT_OUTPUT/{COLLECTHSMETRICS_MT,MUTECT2_MT,HAPLOTYPES,ANNOVAR_MT,EKLIPSE} \
		$CORE_PATH/$PROJECT/TEMP/$SM_TAG"_ANNOVAR_MT"
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

#########################################
##### MUTECT2 IN MITO MODE WORKFLOW #####
##### WORKS ON FULL BAM FILE ############
#########################################

	#####################################################
	# run mutect2 in mitochondria mode on full bam file #
	#####################################################

		MUTECT2_MT ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A01-MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-MUTECT2_MT.log" \
			$SCRIPT_DIR/A01-MUTECT2_MT.sh \
				$MITO_MUTECT2_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$FAMILY \
				$SM_TAG \
				$REF_GENOME \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

	#######################################
	# apply filters to mutect2 vcf output #
	#######################################

		FILTER_MUTECT2_MT ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A01-A01-FILTER_MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-FILTER_MUTECT2_MT.log" \
				-hold_jid A01-MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
			$SCRIPT_DIR/A01-A01-FILTER_MUTECT2_MT.sh \
				$MITO_MUTECT2_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$SM_TAG \
				$REF_GENOME \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

	###################################################
	# apply masks to mutect2 mito filtered vcf output #
	###################################################

		MASK_MUTECT2_MT ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A01-A01-A01-MASK_MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-MASK_MUTECT2_MT.log" \
				-hold_jid A01-A01-FILTER_MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
			$SCRIPT_DIR/A01-A01-A01-MASK_MUTECT2_MT.sh \
				$MITO_MUTECT2_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$SM_TAG \
				$MT_MASK \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

	#############################################
	# run haplogrep2 on mutect2 mito vcf output #
	#############################################

		HAPLOGREP2_MUTECT2_MT ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A01-A01-A01-A01-HAPLOGREP2_MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-HAPLOGREP2_MUTECT2_MT.log" \
				-hold_jid A01-A01-A01-MASK_MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
			$SCRIPT_DIR/A01-A01-A01-A01-HAPLOGREP2_MUTECT2_MT.sh \
				$MITO_MUTECT2_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$FAMILY \
				$SM_TAG \
				$REF_GENOME \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

	#############################################################
	# add gnomad annotation to info field of mutect2 vcf output #
	#############################################################

		GNOMAD_MUTECT2_MT ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A01-A01-A01-A02-GNOMAD_MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-GNOMAD_MUTECT2_MT.log" \
				-hold_jid A01-A01-A01-MASK_MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
			$SCRIPT_DIR/A01-A01-A01-A02-GNOMAD_MUTECT2_MT.sh \
				$MITO_MUTECT2_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$FAMILY \
				$SM_TAG \
				$GNOMAD_MT \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

	##########################################
	# run annovar on final mutect2 based vcf #
	##########################################

		RUN_ANNOVAR_MUTECT2_MT ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A01-A01-A01-A02-A01-RUN_ANNOVAR_MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-RUN_ANNOVAR_MUTECT2_MT.log" \
				-hold_jid A01-A01-A01-A02-GNOMAD_MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
			$SCRIPT_DIR/A01-A01-A01-A02-A01-RUN_ANNOVAR_MUTECT2_MT.sh \
				$MITO_MUTECT2_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$FAMILY \
				$SM_TAG \
				$ANNOVAR_MT_DB_DIR \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

	##########################################
	# run annovar on final mutect2 based vcf #
	##########################################

		FIX_ANNOVAR_MUTECT2_MT ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A01-A01-A01-A02-A01-A01-FIX_ANNOVAR_MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-FIX_ANNOVAR_MUTECT2_MT.log" \
				-hold_jid A01-A01-A01-A02-A01-RUN_ANNOVAR_MUTECT2_MT"_"$SGE_SM_TAG"_"$PROJECT \
			$SCRIPT_DIR/A01-A01-A01-A02-A01-A01-FIX_ANNOVAR_MUTECT2_MT.sh \
				$CORE_PATH \
				$PROJECT \
				$FAMILY \
				$SM_TAG \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

##############################################################
##### RUN EKLIPSE TO DETECT LARGE DELETIONS IN MT GENOME #####
##############################################################

	############################################
	# SUBSET BAM FILE TO CONTAIN ONLY MT READS #
	############################################

		SUBSET_BAM_MT ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A02-MAKE_BAM_MT"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-MAKE_BAM_MT.log" \
			$SCRIPT_DIR/A02-MAKE_MT_BAM.sh \
				$MITO_EKLIPSE_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$FAMILY \
				$SM_TAG \
				$THREADS \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

	############################################
	# SUBSET BAM FILE TO CONTAIN ONLY MT READS #
	############################################

		RUN_EKLIPSE ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A02-A01-RUN_EKLIPSE"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-RUN_EKLIPSE.log" \
				-hold_jid A02-MAKE_BAM_MT"_"$SGE_SM_TAG"_"$PROJECT \
			$SCRIPT_DIR/A02-A01-RUN_EKLIPSE.sh \
				$MITO_EKLIPSE_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$FAMILY \
				$SM_TAG \
				$MT_GENBANK \
				$THREADS \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

######################################################
##### COVERAGE STATISTICS AND PLOT FOR MT GENOME #####
######################################################

	##############################################################
	# RUN COLLECTHSMETRICS ON MT ONLY BAM FILE ###################
	# USES GATK IMPLEMENTATION INSTEAD OF PICARD TOOLS ###########
	##############################################################

		COLLECTHSMETRICS_MT ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A02-A02-COLLECTHSMETRICS_MT"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-COLLECTHSMETRICS_MT.log" \
				-hold_jid A02-MAKE_BAM_MT"_"$SGE_SM_TAG"_"$PROJECT \
			$SCRIPT_DIR/A02-A02-COLLECTHSMETRICS_MT.sh \
				$MITO_MUTECT2_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$FAMILY \
				$SM_TAG \
				$REF_GENOME \
				$MT_PICARD_INTERVAL_LIST \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

	###############################################################
	# RUN ALEX'S R SCRIPT TO GENERATE COVERAGE PLOT FOR MT GENOME #
	###############################################################

		PLOT_MT_COVERAGE ()
		{
			echo \
			qsub \
				$QSUB_ARGS \
				$STANDARD_QUEUE_QSUB_ARG \
			-N A02-A02-A01-PLOT_MT_COVERAGE"_"$SGE_SM_TAG"_"$PROJECT \
				-o $CORE_PATH/$PROJECT/LOGS/$SM_TAG/$SM_TAG"-PLOT_MT_COVERAGE.log" \
				-hold_jid A02-A02-COLLECTHSMETRICS_MT"_"$SGE_SM_TAG"_"$PROJECT \
			$SCRIPT_DIR/A02-A02-A01_PLOT_MT_COVERAGE.sh \
				$MITO_MUTECT2_CONTAINER \
				$CORE_PATH \
				$PROJECT \
				$FAMILY \
				$SM_TAG \
				$MT_COVERAGE_R_SCRIPT \
				$SAMPLE_SHEET \
				$SUBMIT_STAMP
		}

###############################################################
# run steps centered on gatk's mutect2 mitochondrial workflow #
###############################################################

for SAMPLE in $(awk 1 $SAMPLE_SHEET \
		| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
		| awk 'BEGIN {FS=","} NR>1 {print $8}' \
		| sort \
		| uniq );
	do
		CREATE_SAMPLE_ARRAY
		# run mutect2 and then filter, annotate, run haplogrep2
		MUTECT2_MT
		echo sleep 0.1s
		FILTER_MUTECT2_MT
		echo sleep 0.1s
		MASK_MUTECT2_MT
		echo sleep 0.1s
		HAPLOGREP2_MUTECT2_MT
		echo sleep 0.1s
		GNOMAD_MUTECT2_MT
		echo sleep 0.1s
		RUN_ANNOVAR_MUTECT2_MT
		echo sleep 0.1s
		FIX_ANNOVAR_MUTECT2_MT
		echo sleep 0.1s
		# run eklipse workflow
		SUBSET_BAM_MT
		echo sleep 0.1s
		RUN_EKLIPSE
		echo sleep 0.1s
		# generate coverage for mt genome
		COLLECTHSMETRICS_MT
		echo sleep 0.1s
		PLOT_MT_COVERAGE
		echo sleep 0.1s
done

#############################
##### END PROJECT TASKS #####
#############################

# # build hold id for qc report prep per sample, per project

# 	BUILD_HOLD_ID_PATH_PROJECT_WRAP_UP ()
# 	{
# 		HOLD_ID_PATH="-hold_jid "

# 		for SAMPLE in $(awk 1 $SAMPLE_SHEET \
# 			| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
# 			| awk 'BEGIN {FS=","} $1=="'$PROJECT'" {print $8}' \
# 			| sort \
# 			| uniq);
# 		do
# 			CREATE_SAMPLE_ARRAY
# 			HOLD_ID_PATH=$HOLD_ID_PATH"X.01_QC_REPORT_PREP"_"$SGE_SM_TAG"_"$PROJECT"","
# 			HOLD_ID_PATH=`echo $HOLD_ID_PATH | sed 's/@/_/g'`
# 		done
# 	}

# # run end project functions (qc report, file clean-up) for each project

# 	PROJECT_WRAP_UP ()
# 	{
# 		echo \
# 		qsub \
# 			$QSUB_ARGS \
# 			$STANDARD_QUEUE_QSUB_ARG \
# 		-N B.01_END_PROJECT_TASKS"_"$PROJECT \
# 			-o $CORE_PATH/$PROJECT/LOGS/$PROJECT"-END_PROJECT_TASKS.log" \
# 		$HOLD_ID_PATH \
# 		$SCRIPT_DIR/b.01-END_PROJECT_TASKS.sh \
# 			$MITO_MUTECT2_CONTAINER \
# 			$CORE_PATH \
# 			$PROJECT \
# 			$SCRIPT_DIR \
# 			$SUBMITTER_ID \
# 			$SAMPLE_SHEET \
# 			$SUBMIT_STAMP \
# 			$SEND_TO \
# 			$THREADS
# 	}

# # final loop

# for PROJECT in $(awk 1 $SAMPLE_SHEET \
# 			| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
# 			| awk 'BEGIN {FS=","} NR>1 {print $1}' \
# 			| sort \
# 			| uniq);
# 	do
# 		BUILD_HOLD_ID_PATH_PROJECT_WRAP_UP
# 		PROJECT_WRAP_UP
# done

# MESSAGE THAT SAMPLE SHEET HAS FINISHED SUBMITTING

	printf "echo\n"

	printf "echo $SAMPLE_SHEET has finished submitting at `date`\n"

# EMAIL WHEN DONE SUBMITTING

	printf "$SAMPLE_SHEET\nhas finished submitting at\n`date`\nby `whoami`" \
		| mail -s "$PERSON_NAME has submitted SUBMITTER_JHGenomics_CGC_Clinical_Exome_Mito.sh" \
			$SEND_TO
