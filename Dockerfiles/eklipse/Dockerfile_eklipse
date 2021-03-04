FROM python:2.7.18-stretch

ENV SAMTOOLS_URL    https://github.com/samtools/samtools/releases/download/1.11/samtools-1.11.tar.bz2
ENV BLAST_URL       https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.11.0/ncbi-blast-2.11.0+-x64-linux.tar.gz
ENV CIRCOS_URL      http://circos.ca/distribution/circos-0.69-6.tgz
ENV EKLIPSE_GIT_URL https://github.com/dooguypapua/eKLIPse.git
ENV EKLIPSE_COMMIT  c25931b48f9db0c6e26068eab9d733c55956785d

ARG EKLIPSE_DIR="/eklipse"
ARG DEPS_DIR="$EKLIPSE_DIR/dependencies"

RUN mkdir $EKLIPSE_DIR \
 && mkdir $DEPS_DIR

RUN pip install biopython==1.74 \
				tqdm==4.26.0

RUN cd /tmp \
 && wget -nv $SAMTOOLS_URL \
 && tar -xvf samtools-1.11.tar.bz2 \
 &&	cd samtools-1.11 \
 &&	./configure --prefix=/usr \
 &&	make all all-htslib \
 &&	make install install-htslib \
 &&	cd .. \
 &&	rm -rf samtools-1.11*

RUN cd $DEPS_DIR \
 && wget $BLAST_URL \
 && tar -xvf ncbi-blast-2.11.0+-x64-linux.tar.gz \
 && rm ncbi-blast-2.11.0+-x64-linux.tar.gz

ENV PATH "$PATH:$DEPS_DIR/ncbi-blast-2.11.0+/bin"

RUN apt-get update \
 && apt-get install -y libgd-dev

ENV PERL_MM_USE_DEFAULT=1 
RUN cpan App::cpanminus \
 && cpanm Clone \
          Config::General \
          Font::TTF::Font \
          GD \
          GD::Polyline \
          List::MoreUtils \
          Math::Bezier \
          Math::Round \
          Math::VecStat \
          Params::Validate \
          Readonly \
          Regexp::Common \
          SVG \
          Set::IntSpan \
          Statistics::Basic \
          Text::Format;

RUN cd $DEPS_DIR \
 && wget -nv http://circos.ca/distribution/circos-0.69-6.tgz \
 && tar -xvf circos-0.69-6.tgz \
 && rm circos-0.69-6.tgz

ENV PATH "$PATH:$DEPS_DIR/circos-0.69-6/bin"

RUN cd $EKLIPSE_DIR \
 && git clone $EKLIPSE_GIT_URL \
 && cd eKLIPse/ \
 && git checkout $EKLIPSE_COMMIT \
 && echo '#!/usr/bin/env python2' > shebang_eKLIPse.py \
 && echo >> shebang_eKLIPse.py \
 && cat eKLIPse.py >> shebang_eKLIPse.py \
 && mv shebang_eKLIPse.py eKLIPse.py \
 && chmod 777 eKLIPse.py

ENV PATH "$PATH:$EKLIPSE_DIR/eKLIPse"

CMD eKLIPse.py
