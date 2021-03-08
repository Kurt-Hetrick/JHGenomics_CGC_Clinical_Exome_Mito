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

	MITO_MUTECT2_CONTAINER=$1
	CORE_PATH=$2

	PROJECT=$3
	SM_TAG=$4
	REF_GENOME=$5

	SAMPLE_SHEET=$6
		SAMPLE_SHEET_NAME=$(basename $SAMPLE_SHEET .csv)
	SUBMIT_STAMP=$7

## apply recommended filters on mutect2 mito mode vcf output
#### although I think they are not ultimately helpful since they are based on whole genome autosomal coverage

START_FILTER_MUTECT2_MT=`date '+%s'` # capture time process starts for wall clock tracking purposes.

	# construct command line

		CMD="singularity exec $MITO_MUTECT2_CONTAINER java -jar" \
		CMD=$CMD" /gatk/gatk.jar" \
		CMD=$CMD" FilterMutectCalls" \
			CMD=$CMD" --variant $CORE_PATH/$PROJECT/TEMP/$SM_TAG.MUTECT2_MT_RAW.vcf" \
			CMD=$CMD" --reference $REF_GENOME" \
			CMD=$CMD" --mitochondria-mode true" \
			CMD=$CMD" --max-alt-allele-count 4" \
			CMD=$CMD" --min-allele-fraction 0.03" \
			CMD=$CMD" --contamination-estimate 0.0" \
			CMD=$CMD" --stats $CORE_PATH/$PROJECT/TEMP/$SM_TAG.MUTECT2_MT_RAW.vcf.stats" \
			CMD=$CMD" --output $CORE_PATH/$PROJECT/TEMP/$SM_TAG.MUTECT2_MT_FILTERED.vcf" \

	# write command line to file and execute the command line

		echo $CMD >> $CORE_PATH/$PROJECT/COMMAND_LINES/$SM_TAG"_command_lines.txt"
		echo >> $CORE_PATH/$PROJECT/COMMAND_LINES/$SM_TAG"_command_lines.txt"
		echo $CMD | bash

	# check the exit signal at this point.

		SCRIPT_STATUS=`echo $?`

	# if exit does not equal 0 then exit with whatever the exit signal is at the end.
	# also write to file that this job failed

		if [ "$SCRIPT_STATUS" -ne 0 ]
		 then
			echo $SM_TAG $HOSTNAME $JOB_NAME $USER $SCRIPT_STATUS $SGE_STDERR_PATH \
			>> $CORE_PATH/$PROJECT/TEMP/$SAMPLE_SHEET_NAME"_"$SUBMIT_STAMP"_ERRORS.txt"
			exit $SCRIPT_STATUS
		fi

END_FILTER_MUTECT2_MT=`date '+%s'` # capture time process starts for wall clock tracking purposes.

# write out timing metrics to file

	echo $SM_TAG"_"$PROJECT",F.01,FILTER_MUTECT2_MT,"$HOSTNAME","$START_FILTER_MUTECT2_MT","$END_FILTER_MUTECT2_MT \
	>> $CORE_PATH/$PROJECT/REPORTS/$PROJECT".WALL.CLOCK.TIMES.csv"

# exit with the signal from samtools bam to cram

	exit $SCRIPT_STATUS
