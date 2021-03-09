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

	MITO_EKLIPSE_CONTAINER=$1
	CORE_PATH=$2

	PROJECT=$3
	FAMILY=$4
	SM_TAG=$5
	THREADS=$6

	SAMPLE_SHEET=$7
		SAMPLE_SHEET_NAME=$(basename $SAMPLE_SHEET .csv)
	SUBMIT_STAMP=$8

## --extract out the MT reads in the bam file

START_MAKE_MT_BAM=`date '+%s'` # capture time process starts for wall clock tracking purposes.

	# construct command line

		CMD="singularity exec $MITO_EKLIPSE_CONTAINER samtools" \
		CMD=$CMD" view" \
		CMD=$CMD" -bh" \
		CMD=$CMD" -@ $THREADS" \
		CMD=$CMD" -o $CORE_PATH/$PROJECT/TEMP/$SM_TAG"_MT.bam"" \
		CMD=$CMD" $CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/BAM/$SM_TAG".bam"" \
		CMD=$CMD" MT" \
		CMD=$CMD" &&" \
		# index the new bam file
		CMD=$CMD" singularity exec $MITO_EKLIPSE_CONTAINER samtools" \
		CMD=$CMD" index" \
		CMD=$CMD" $CORE_PATH/$PROJECT/TEMP/$SM_TAG"_MT.bam"" \
		CMD=$CMD" -@ $THREADS" \
		CMD=$CMD" &&" \
		# eklipse for some reason reads in a text file with the file path and ?sample name?
		# so generating that now
		CMD=$CMD" echo -e $CORE_PATH/$PROJECT/TEMP/$SM_TAG"_MT.bam"'\t'$SM_TAG" \
		CMD=$CMD" >| $CORE_PATH/$PROJECT/TEMP/$SM_TAG"_EKLIPSE_CONFIG.txt""

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

END_MAKE_MT_BAM=`date '+%s'` # capture time process starts for wall clock tracking purposes.

# write out timing metrics to file

	echo $SM_TAG"_"$PROJECT",F.01,MAKE_MT_BAM,"$HOSTNAME","$START_MAKE_MT_BAM","$END_MAKE_MT_BAM \
	>> $CORE_PATH/$PROJECT/REPORTS/$PROJECT".WALL.CLOCK.TIMES.csv"

# exit with the signal from samtools bam to cram

	exit $SCRIPT_STATUS
