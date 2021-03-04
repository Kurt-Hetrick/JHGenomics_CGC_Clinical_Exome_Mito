FROM broadinstitute/gatk:4.1.3.0

ENV BCFTOOLS_URL https://github.com/samtools/bcftools/releases/download/1.10.2/bcftools-1.10.2.tar.bz2
ENV HAPLOGREP_URL https://github.com/seppinho/haplogrep-cmd/releases/download/v2.1.20/haplogrep-2.1.20.jar

RUN cd /jars \
 && wget -nv $HAPLOGREP_URL

RUN wget -nv $BCFTOOLS_URL \
 && tar -xvf bcftools-1.10.2.tar.bz2 \
 &&	cd bcftools-1.10.2 \
 &&	./configure --prefix=/usr \
 &&	make \
 &&	make install \
 &&	cd .. \
 &&	rm -rf bcftools-1.10.2*

ARG ANNOVAR_DIR="/annovar"

RUN mkdir $ANNOVAR_DIR

COPY ./annovar/ $ANNOVAR_DIR

ENV PATH "$PATH:$ANNOVAR_DIR"
