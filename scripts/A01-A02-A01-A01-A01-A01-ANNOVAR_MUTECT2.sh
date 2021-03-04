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
	SM_TAG=$4
	ANNOVAR_MT=$5

	SAMPLE_SHEET=$6
		SAMPLE_SHEET_NAME=$(basename $SAMPLE_SHEET .csv)
	SUBMIT_STAMP=$7

## run gnomad on mutect2 vcf annotated with gnomad

START_ANNOVAR_MUTECT2=`date '+%s'` # capture time process starts for wall clock tracking purposes.

	# construct command line

		CMD="singularity exec $ALIGNMENT_CONTAINER perl" \
		CMD=$CMD" table_annovar.pl" \
			CMD=$CMD" $SAMPLE_ID".intermediate.vcf"" \
			CMD=$CMD" /mnt/research/statgen/gatk-4.1.3.0/annovar_resources/2019/annovar/humandb/" \
			CMD=$CMD" --buildver GRCh37_MT" \
			CMD=$CMD" --protocol ensGene,vcf,vcf,vcf,clinvar_20200316,avsnp150" \
			CMD=$CMD" g,f,f,f,f,f" \
			CMD=$CMD" --vcfdbfile GRCh37_MT_MMpolymorphisms.vcf,GRCh37_MT_MMdisease.vcf,GRCh37_MT_gnomAD.vcf" \
			CMD=$CMD" --vcfinput" \
			CMD=$CMD" --outfile $outdir/$SAMPLE_ID/anno2019vers/withCV_DB150/$SAMPLE_ID" \

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

END_ANNOVAR_MUTECT2=`date '+%s'` # capture time process starts for wall clock tracking purposes.

# write out timing metrics to file

	echo $SM_TAG"_"$PROJECT",F.01,ANNOVAR_MUTECT2,"$HOSTNAME","$START_ANNOVAR_MUTECT2","$END_ANNOVAR_MUTECT2 \
	>> $CORE_PATH/$PROJECT/REPORTS/$PROJECT".WALL.CLOCK.TIMES.csv"

# exit with the signal from samtools bam to cram

	exit $SCRIPT_STATUS
