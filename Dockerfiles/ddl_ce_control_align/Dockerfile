# https://hub.docker.com/r/broadinstitute/gatk

FROM broadinstitute/gatk:4.0.11.0

# information on gatk image
	# https://hub.docker.com/layers/broadinstitute/gatk/4.0.11.0/images/sha256-4578d2c6bee54c850190fa3b7d82c8de63e22b5bfbcd9a752623880ecfde4628?context=explore
	# Ubuntu 16.04.5 LTS
	# PATH=/gatk:/opt/miniconda/envs/gatk/bin:/opt/miniconda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
	# ENV CONDA_URL=https://repo.continuum.io/miniconda/Miniconda3-4.3.30-Linux-x86_64.sh
	# Python 3.6.2 :: Continuum Analytics, Inc.
		# samtools 0.1.19
		# bcftools 0.1.19
		# bedtools v2.25.0
		# bgzip 1.2.1
		# tabix 1.2.1
		# samtools, bcftools, bgzip and tabix are going to be overwritten with newer versions in this build
	# R 3.2.5
		# dependencies = c("gplots","digest", "gtable", "MASS", "plyr", "reshape2", "scales", "tibble", "lazyeval")    # for ggplot2
		# getopt_1.20.0.tar.gz
		# optparse_1.3.2.tar.gz
		# data.table_1.10.4-2.tar.gz
		# gsalib_2.1.tar.gz
		# ggplot2_2.2.1.tar.gz
	# openjdk version "1.8.0_181"
	# /gatk/gatk.jar -> /gatk/gatk-package-4.0.11.0-local.jar

# newer versions of gatk have picard wrapped in, but I don't want to dig up what version of picard this is using
ENV PICARD_URL https://github.com/broadinstitute/picard/releases/download/2.17.0/picard.jar
ENV PICARD_MD5 = "72cc527f1e4ca6a799ae0117af60b54e"
ENV SAMBLASTER_URL https://github.com/GregoryFaust/samblaster/releases/download/v.0.1.24/samblaster-v.0.1.24.tar.gz
ENV SAMBLASTER_MD5 = "885d5782cc277865dfb086fc0a20243e"
ENV SAMBAMBA_URL https://github.com/biod/sambamba/releases/download/v0.6.8/sambamba-0.6.8-linux-static.gz
ENV SAMBAMBA_MD5 = "ee61000bcb33a82013c284bac8feb91f"
ENV BWA_URL https://github.com/lh3/bwa/archive/v0.7.15.tar.gz
ENV BWA_MD5 = "54fdee953c5c256d36885a1c5c6b118c"
ENV DATAMASH_URL http://ftp.gnu.org/gnu/datamash/datamash-1.6.tar.gz
ENV DATAMASH_MD5 = "c3c243278a2f35de5ce988c844f8e240"
ENV VERIFYBAMID_URL https://github.com/statgen/verifyBamID/releases/download/v1.1.3/verifyBamIDLibStatGen.1.1.3.tgz
ENV VERIFYBAMID_MD5 = "9b3d4c73c8f72e6b8f1e014702bc5bec"
# the gatk image has installed very old versions of samtools that can't process cram files
# installing newer versions and overwriting previously installed versions
ENV SAMTOOLS_URL https://github.com/samtools/samtools/releases/download/1.10/samtools-1.10.tar.bz2
ENV SAMTOOLS_MD5 = "506b0b9b2628e1f3bbedd77855b4c709"
ENV BCFTOOLS_URL https://github.com/samtools/bcftools/releases/download/1.10.2/bcftools-1.10.2.tar.bz2
ENV BCFTOOLS_MD5 = "081ebb6138f5fdf394cb6a074effadb3"

SHELL ["/bin/bash", "-c"]

WORKDIR /downloads

RUN apt-get update && \
	apt-get install -y \
	parallel=20161222-1~ubuntu0.16.04.1

RUN wget -nv $PICARD_URL && \
	mv picard.jar /gatk/picard.jar

RUN wget -nv $SAMBLASTER_URL && \
	tar -xzf samblaster-v.0.1.24.tar.gz && \
	cd samblaster-v.0.1.24 && \
	make && \
	cp samblaster /usr/bin && \
	cd .. && \
	rm -rf samblaster-v.0.1.24*

RUN wget -nv $SAMBAMBA_URL && \
	gzip -d sambamba-0.6.8-linux-static.gz && \
	chmod a+x sambamba-0.6.8-linux-static && \
	mv sambamba-0.6.8-linux-static /usr/bin/sambamba

RUN wget -nv $BWA_URL && \
	tar -xzf v0.7.15.tar.gz && \
	cd bwa-0.7.15 && \
	make && \
	cp bwa /usr/bin && \
	cd .. && \
	rm -rf bwa-0.7.15* v0.7.15.tar.gz

RUN wget -nv $DATAMASH_URL && \
	tar -xzf datamash-1.6.tar.gz && \
	cd datamash-1.6 && \
	./configure && \
	make && \
	make check && \
	make install && \
	cd .. && \
	rm -rf datamash-1.6* datamash-1.6.tar.gz

RUN wget -nv $VERIFYBAMID_URL && \
	tar -xzf verifyBamIDLibStatGen.1.1.3.tgz && \
	cd verifyBamID_1.1.3 && \
	make && \
	mv /downloads/verifyBamID_1.1.3/verifyBamID/bin/verifyBamID /usr/bin && \
	cd /downloads && \
	rm -rf verifyBamID*

RUN wget -nv $SAMTOOLS_URL && \
	tar -xvf samtools-1.10.tar.bz2 && \
	cd samtools-1.10 && \
	./configure --prefix=/usr && \
	make all all-htslib && \
	make install install-htslib && \
	cd .. && \
	rm -rf samtools-1.10*

RUN wget -nv $BCFTOOLS_URL && \
	tar -xvf bcftools-1.10.2.tar.bz2 && \
	cd bcftools-1.10.2 && \
	./configure --prefix=/usr && \
	make && \
	make install && \
	cd .. && \
	rm -rf bcftools-1.10.2*
