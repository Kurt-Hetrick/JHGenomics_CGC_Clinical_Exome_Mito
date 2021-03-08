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
	FAMILY=$4
	SM_TAG=$5

	SAMPLE_SHEET=$6
		SAMPLE_SHEET_NAME=$(basename $SAMPLE_SHEET .csv)
	SUBMIT_STAMP=$7

## run haplogrep2 on mutect2 output

START_HAPLOGREP2_MUTECT2_MT=`date '+%s'` # capture time process starts for wall clock tracking purposes.

	# construct command line

		CMD="singularity exec $MITO_MUTECT2_CONTAINER java -jar" \
		CMD=$CMD" /jars/haplogrep-2.1.20.jar" \
			CMD=$CMD" --in $CORE_PATH/$PROJECT/TEMP/$SM_TAG".MUTECT2_MT_FILTERED_MASKED.vcf.gz"" \
			CMD=$CMD" --extend-report" \
			CMD=$CMD" --format vcf" \
			CMD=$CMD" --hits 5" \
			CMD=$CMD" --out $CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/MT_OUTPUT/HAPLOTYPES/$SM_TAG".haplotypes.txt""

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

END_HAPLOGREP2_MUTECT2_MT=`date '+%s'` # capture time process starts for wall clock tracking purposes.

# write out timing metrics to file

	echo $SM_TAG"_"$PROJECT",F.01,HAPLOGREP2_MUTECT2_MT,"$HOSTNAME","$START_HAPLOGREP2_MUTECT2_MT","$END_HAPLOGREP2_MUTECT2_MT \
	>> $CORE_PATH/$PROJECT/REPORTS/$PROJECT".WALL.CLOCK.TIMES.csv"

# exit with the signal from samtools bam to cram

	exit $SCRIPT_STATUS
