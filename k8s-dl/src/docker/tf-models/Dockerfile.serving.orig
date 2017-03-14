FROM ubuntu:14.04

MAINTAINER Jeremiah Harmsen <jeremiah@google.com>
MAINTAINER Samuel Cozannet <samuel.cozannet@madeden.com>

# This is an evolution of the Dockerfile.devel published by Google for Tensorflow. 
# It adds building the server in the container at the end as documented in 
# https://tensorflow.github.io/serving/serving_inception
# then we moved to 

ENV PORT=8500
ENV MODEL_NAME=inception
ENV MODEL_PATH=/var/tensorflow/output
ENV BATCHING="--enable_batching"

# build variables for serving
ENV PYTHON_BIN_PATH="/usr/bin/python"
ENV PYTHON_LIB_PATH="/usr/local/lib/python2.7/dist-packages"
ENV CC_OPT_FLAGS="-march=native" 
ENV TF_NEED_JEMALLOC=1 
ENV TF_NEED_GCP=0 
ENV TF_NEED_HDFS=0 
ENV TF_ENABLE_XLA=0 
ENV TF_NEED_OPENCL=0 
ENV TF_NEED_CUDA=0 
ENV TF_CUDA_VERSION=v8.0 

RUN apt-get update && apt-get install -y \
        build-essential \
        curl \
        git \
        libfreetype6-dev \
        libpng12-dev \
        libzmq3-dev \
        pkg-config \
        python-dev \
        python-numpy \
        python-pip \
        software-properties-common \
        swig \
        zip \
        zlib1g-dev \
        libcurl3-dev \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fSsL -O https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && \
    rm get-pip.py

# Set up grpc

RUN pip install enum34 futures mock six && \
    pip install --pre 'protobuf>=3.0.0a3' && \
    pip install -i https://testpypi.python.org/simple --pre grpcio

# Set up Bazel.

# We need to add a custom PPA to pick up JDK8, since trusty doesn't
# have an openjdk8 backport.  openjdk-r is maintained by a reliable contributor:
# Matthias Klose (https://launchpad.net/~doko).  It will do until
# we either update the base image beyond 14.04 or openjdk-8 is
# finally backported to trusty; see e.g.
#   https://bugs.launchpad.net/trusty-backports/+bug/1368094
RUN add-apt-repository -y ppa:openjdk-r/ppa && \
    apt-get update && \
    apt-get install -y openjdk-8-jdk openjdk-8-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Running bazel inside a `docker build` command causes trouble, cf:
#   https://github.com/bazelbuild/bazel/issues/134
# The easiest solution is to set up a bazelrc file forcing --batch.
RUN echo "startup --batch" >>/root/.bazelrc
# Similarly, we need to workaround sandboxing issues:
#   https://github.com/bazelbuild/bazel/issues/418
RUN echo "build --spawn_strategy=standalone --genrule_strategy=standalone" \
    >>/root/.bazelrc
ENV BAZELRC /root/.bazelrc
# Install the most recent bazel release.
ENV BAZEL_VERSION 0.4.2
WORKDIR /
RUN mkdir /bazel && \
    cd /bazel && \
    curl -fSsL -O https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
    curl -fSsL -o /bazel/LICENSE.txt https://raw.githubusercontent.com/bazelbuild/bazel/master/LICENSE.txt && \
    chmod +x bazel-*.sh && \
    ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
    cd / && \
    rm -f /bazel/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh

# PYTHON_BIN_PATH=/usr/bin/python PYTHON_LIB_PATH=/usr/local/lib/python2.7/dist-packages CC_OPT_FLAGS="-march=native" TF_NEED_JEMALLOC=1 TF_NEED_GCP=0 TF_NEED_HDFS=0 TF_ENABLE_XLA=0 TF_NEED_OPENCL=0 TF_NEED_CUDA=0 TF_CUDA_VERSION=v8.0 ./configure 

RUN git clone --recurse-submodules https://github.com/tensorflow/serving /serving && \
    cd /serving/tensorflow && \
    ./configure && \
    cd .. && \
    bazel build -c opt tensorflow_serving/...

CMD [ "/serving/bazel-bin/tensorflow_serving/model_servers/tensorflow_model_server" , "--port=${PORT}", "${BATCHING}", "--model_name=${MODEL_NAME}", "--model_base_path=${MODEL_PATH}" ]
