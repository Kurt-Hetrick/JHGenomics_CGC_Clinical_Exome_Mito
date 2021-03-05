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

## run collecthsmetrics on full bam file targeting only the mt genome

START_MUTECT2_MT=`date '+%s'` # capture time process starts for wall clock tracking purposes.

	# construct command line

		CMD="singularity exec $ALIGNMENT_CONTAINER java -jar" \
		CMD=$CMD" /gatk/gatk.jar" \
		CMD=$CMD" Mutect2" \
			CMD=$CMD" --input $CORE_PATH/$PROJECT/$FAMILY/$SM_TAG/BAM/$SM_TAG".bam"" \
			CMD=$CMD" --reference $REF_GENOME" \
			CMD=$CMD" --mitochondria-mode true" \
			CMD=$CMD" --max-mnp-distance 0" \
			CMD=$CMD" --max-reads-per-alignment-start 75" \
			CMD=$CMD" --max-disc-ar-extension 25" \
			CMD=$CMD" --max-gga-ar-extension 300" \
			CMD=$CMD" --padding-around-indels 150" \
			CMD=$CMD" --padding-around-snps 20" \
			CMD=$CMD" --pruning-lod-threshold 1.0" \
			CMD=$CMD" --debug-graph-transformations false" \
			CMD=$CMD" --capture-assembly-failure-bam false" \
			CMD=$CMD" --error-correct-reads false" \
			CMD=$CMD" --kmer-length-for-read-error-correction 25" \
			CMD=$CMD" --min-observations-for-kmer-to-be-solid 20" \
			CMD=$CMD" --likelihood-calculation-engine PairHMM" \
			CMD=$CMD" --annotation StrandBiasBySample" \
			CMD=$CMD" --intervals MT:1-16569" \
			CMD=$CMD" --output $CORE_PATH/$PROJECT/TEMP/$SM_TAG".MUTECT2_MT_RAW.vcf""

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

END_MUTECT2_MT=`date '+%s'` # capture time process starts for wall clock tracking purposes.

# write out timing metrics to file

	echo $SM_TAG"_"$PROJECT",F.01,MUTECT2_MT,"$HOSTNAME","$START_MUTECT2_MT","$END_MUTECT2_MT \
	>> $CORE_PATH/$PROJECT/REPORTS/$PROJECT".WALL.CLOCK.TIMES.csv"

# exit with the signal from samtools bam to cram

	exit $SCRIPT_STATUS
