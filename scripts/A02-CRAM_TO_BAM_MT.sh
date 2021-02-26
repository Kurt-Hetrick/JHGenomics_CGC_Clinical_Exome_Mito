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
	FAMILY=$4
	SM_TAG=$5
	REF_GENOME=$6

	SAMPLE_SHEET=$7
		SAMPLE_SHEET_NAME=$(basename $SAMPLE_SHEET .csv)
	SUBMIT_STAMP=$8

## --write lossless cram file. this is the deliverable

START_CRAM_TO_BAM_MT=`date '+%s'` # capture time process starts for wall clock tracking purposes.

	# construct command line

		CMD="singularity exec $ALIGNMENT_CONTAINER samtools" \
		CMD=$CMD" view" \
		CMD=$CMD" -b $CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/CRAM/$SM_TAG".cram"" \
		CMD=$CMD" -o $CORE_PATH/$PROJECT/TEMP/$SM_TAG".bam"" \
		CMD=$CMD" -T $REF_GENOME" \
		CMD=$CMD" -@ $THREADS" \
		CMD=$CMD" MT" \
		CMD=$CMD" &&" \
		CMD=$CMD" singularity exec $ALIGNMENT_CONTAINER samtools" \
		CMD=$CMD" index" \
		CMD=$CMD" -o $CORE_PATH/$PROJECT/TEMP/$SM_TAG".bam"" \
		CMD=$CMD" -@ $THREADS"

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

END_CRAM_TO_BAM_MT=`date '+%s'` # capture time process starts for wall clock tracking purposes.

# write out timing metrics to file

	echo $SM_TAG"_"$PROJECT",F.01,CRAM_TO_BAM_MT,"$HOSTNAME","$START_CRAM_TO_BAM_MT","$END_CRAM_TO_BAM_MT \
	>> $CORE_PATH/$PROJECT/REPORTS/$PROJECT".WALL.CLOCK.TIMES.csv"

# exit with the signal from samtools bam to cram

	exit $SCRIPT_STATUS
