# ---qsub parameter settings---
# --these can be overrode at qsub invocation--

# tell sge to execute in bash
#$ -S /bin/bash

# tell sge that you are in the users current working directory
#$ -cwd

# tell sge to export the users environment variables
#$ -V

# tell sge to submit at this priority setting
#$ -p -10

# tell sge to output both stderr and stdout to the same file
#$ -j y

# export all variables, useful to find out what compute node the program was executed on

	set

	echo

# INPUT VARIABLES

	ALIGNMENT_CONTAINER=$1
	CORE_PATH=$2

	PROJECT=$3

	SCRIPT_DIR=$4
	SEND_TO=$5
	SUBMITTER_ID=$6
		PERSON_NAME=`getent passwd | awk 'BEGIN {FS=":"} $1=="'$SUBMITTER_ID'" {print $5}'`
	THREADS=$7

	SAMPLE_SHEET=$8
		SAMPLE_SHEET_NAME=(`basename $SAMPLE_SHEET .csv`)
		SAMPLE_SHEET_FILE_NAME=(`basename $SAMPLE_SHEET`)
	SUBMIT_STAMP=$9

		TIMESTAMP=`date '+%F.%H-%M-%S'`

##############################################################
##### CLEAN-UP OR NOT DEPENDING ON IF JOBS FAILED OR NOT #####
##### RUN MD5 CHECK ON REMAINING FILES #######################
##############################################################

	# CREATE SAMPLE ARRAY, USED DURING PROJECT CLEANUP

		CREATE_SAMPLE_ARRAY_FOR_FILE_CLEANUP ()
		{
			SAMPLE_ARRAY=(`awk 1 $SAMPLE_SHEET \
				| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
				| awk 'BEGIN {FS=",";OFS="\t"} $1=="'$PROJECT'"&&$8=="'$SM_TAG'" {print $1,$8}' \
				| sort -k 1,1 -k 2,2 \
				| uniq`)

				#  1  Project=the Seq Proj folder name
				PROJECT_FILE_CLEANUP=${SAMPLE_ARRAY[0]}

				#  8  SM_Tag=sample ID
				SM_TAG_FILE_CLEANUP=${SAMPLE_ARRAY[1]}
		}

	# RUN MD5 IN PARALLEL USING 90% OF THE CPU PROCESSORS ON THE PIPELINE OUTPUT FILES

		RUN_MD5_PARALLEL_OUTPUT_FILES ()
		{
			find $CORE_PATH/$PROJECT/*/*/MT_OUTPUT -type f \
				| cut -f 2 \
				| singularity exec $ALIGNMENT_CONTAINER \
					parallel \
						--no-notice \
						-j $THREADS \
						md5sum {} \
			> $CORE_PATH/$PROJECT/REPORTS/"md5_mt_output_files_"$PROJECT"_"$TIMESTAMP".txt"
		}

	# RUN MD5 IN PARALLEL USING 90% OF THE CPU PROCESSORS ON THE PIPELINE RESOURCE FILES

		RUN_MD5_PARALLEL_RESOURCE_FILES ()
		{
			find \
				$SCRIPT_DIR/../resources/ \
				-type f \
			| cut -f 2 \
			| singularity exec $ALIGNMENT_CONTAINER \
				parallel \
					--no-notice \
					-j $THREADS \
					md5sum {} \
			> $CORE_PATH/$PROJECT/REPORTS/"md5_mt_pipeline_resources_"$PROJECT"_"$TIMESTAMP".txt"
		}

# IF THERE ARE NO FAILED JOBS THEN DELETE TEMP FILES STARTING WITH SM_TAG OR PLATFORM_UNIT
# ELSE; DON'T DELETE ANYTHING BUT SUMMARIZE WHAT FAILED.
# AFTER TEMP FILES ARE DELETED RUN MD5 IN PARALLEL

	if [[ ! -f $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_ERRORS.txt" ]]
		then
			for SM_TAG in $(awk 'BEGIN {FS=","} $1=="'$PROJECT'" {print $8}' $SAMPLE_SHEET | sort | uniq)
				do
					CREATE_SAMPLE_ARRAY_FOR_FILE_CLEANUP

					echo rm -rf $CORE_PATH/$PROJECT_FILE_CLEANUP/TEMP/$SM_TAG_FILE_CLEANUP*

					# rm -rf $CORE_PATH/$PROJECT_FILE_CLEANUP/TEMP/$SM_TAG_FILE_CLEANUP* | bash

			done

			RUN_MD5_PARALLEL_OUTPUT_FILES
			RUN_MD5_PARALLEL_RESOURCE_FILES

			printf "\n$PERSON_NAME Was The Submitter\n\n \
				FILE MD5 HASHSUMS:\n "md5_mt_output_files_"$PROJECT"_"$TIMESTAMP".txt"\n \
				"md5_mt_pipeline_resources_"$PROJECT"_"$TIMESTAMP".txt"\n\n \
				NO JOBS FAILED: TEMP FILES DELETED" \
				| mail -s "$SAMPLE_SHEET FOR $PROJECT has finished processing SUBMITTER_JHGenomics_CGC_Clinical_Exome_Mito.sh" \
					$SEND_TO

			# printf "\n$PERSON_NAME Was The Submitter\n\n \
			# 	REPORTS ARE AT:\n $CORE_PATH/$PROJECT/REPORTS/QC_REPORTS\n\n \
			# 	BATCH QC REPORT:\n $SAMPLE_SHEET_NAME".QC_REPORT.csv"\n\n \
			# 	FILE MD5 HASHSUMS:\n "md5_mt_output_files_"$PROJECT"_"$TIMESTAMP".txt"\n \
			# 	"md5_mt_pipeline_resources_"$PROJECT"_"$TIMESTAMP".txt"\n\n \
			# 	NO JOBS FAILED: TEMP FILES DELETED" \
			# 	| mail -s "$SAMPLE_SHEET FOR $PROJECT has finished processing SUBMITTER_JHGenomics_CGC_Clinical_Exome_Mito.sh" \
			# 		$SEND_TO

		else
			# CONSTRUCT MESSAGE TO BE SENT SUMMARIZING THE FAILED JOBS
				printf "SO BAD THINGS HAPPENED AND THE TEMP FILES WILL NOT BE DELETED FOR:\n" \
					>| $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				printf "$SAMPLE_SHEET\n" \
					>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				printf "FOR PROJECT:\n" \
					>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				printf "$PROJECT\n" \
					>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				printf "SOMEWHAT FULL LISTING OF FAILED JOBS ARE HERE:\n" \
					>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				printf "$CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_ERRORS.txt"\n" \
					>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				printf "###################################################################\n" \
					>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				printf "BELOW ARE THE SAMPLES AND THE MINIMUM NUMBER OF JOBS THAT FAILED PER SAMPLE:\n" \
					>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				printf "###################################################################\n" \
					>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				egrep -v CONCORDANCE $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_ERRORS.txt" \
					| awk 'BEGIN {OFS="\t"} NF==6 {print $1}' \
					| sort \
					| singularity exec $ALIGNMENT_CONTAINER datamash -g 1 count 1 \
				>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				printf "###################################################################\n" \
					>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				printf "FOR THE SAMPLES THAT HAVE FAILED JOBS, THIS IS ROUGHLY THE FIRST JOB THAT FAILED FOR EACH SAMPLE:\n" \
					>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				printf "###################################################################\n" \
					>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

				printf "SM_TAG NODE JOB_NAME USER EXIT LOG_FILE\n" | sed 's/ /\t/g' \
						>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

			for sample in $(awk 'BEGIN {OFS="\t"} NF==6 {print $1}' $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_ERRORS.txt" | sort | uniq);
				do
					awk '$1=="'$sample'" {print $0 "\n" "\n"}' $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_ERRORS.txt" | head -n 1 \
					>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"
			done

			sleep 2s

			mail -s "FAILED JOBS: $PROJECT: $SAMPLE_SHEET_FILE_NAME" \
			$SEND_TO \
			< $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_EMAIL_SUMMARY.txt"

	fi

	sleep 2s

####################################################
##### Clean up the Wall Clock minutes tracker. #####
####################################################

	# clean up records that are malformed
	# only keep jobs that ran longer than 3 minutes

		awk 'BEGIN {FS=",";OFS=","} $1~/^[A-Z 0-9]/&&$2!=""&&$3!=""&&$4!=""&&$5!=""&&$6!=""&&$7==""&&$5!~/A-Z/&&$6!~/A-Z/&&($6-$5)>180 \
		{print $1,$2,$3,$4,$5,$6,($6-$5)/60,strftime("%F",$5),strftime("%F",$6),strftime("%F.%H-%M-%S",$5),strftime("%F.%H-%M-%S",$6)}' \
		$CORE_PATH/$PROJECT/REPORTS/$PROJECT".WALL.CLOCK.TIMES.csv" \
		| sed 's/_'"$PROJECT"'/,'"$PROJECT"'/g' \
		| awk 'BEGIN {print "SAMPLE,PROJECT,TASK_GROUP,TASK,HOST,EPOCH_START,EPOCH_END,WC_MIN,START_DATE,END_DATE,TIMESTAMP_START,TIMESTAMP_END"} \
		{print $0}' \
		>| $CORE_PATH/$PROJECT/REPORTS/$PROJECT".WALL.CLOCK.TIMES.FIXED.csv"

# put a stamp as to when the run was done

	echo MT pipeline finished at `date` >> $CORE_PATH/$PROJECT/REPORTS/PROJECT_START_END_TIMESTAMP.txt

# this is black magic that I don't know if it really helps. was having problems with getting the emails to send so I put a little delay in here.

	sleep 2s
