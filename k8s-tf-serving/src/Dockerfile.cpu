FROM ubuntu:16.04

MAINTAINER Samuel Cozannet <samuel.cozannet@madeden.com>

ENV ARCH=cpu
ENV VERSION=optimized
ENV PORT=9000
ENV MODEL_NAME=inception
ENV MODEL_PATH="/serving/model-data"

#        build-essential \
#        python-dev \
#        python-pip \
#        zlib1g-dev && \
#        pkg-config \
#        git \

RUN apt update && apt install -yqq --no-install-recommends \
    curl \
    libcurl3-dev \
    libfreetype6-dev \
    libpng12-dev \
    libzmq3-dev \
    python-numpy \
    software-properties-common \
    swig \
    zip \
    && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

ADD bin/tensorflow_model_server.${ARCH}-${VERSION} /usr/local/bin/tensorflow_model_server
ADD src/entrypoint.sh /entrypoint.sh 

EXPOSE ${PORT}

CMD [ "/entrypoint.sh" ] 
