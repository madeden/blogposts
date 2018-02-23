# This dockerfile downloads ImageNet to ${DATA_DIR}/imagenet
# 
# * Set IMAGENET_USERNAME and IMAGENET_ACCESS_KEY
# * Mount a 500GB+ file system on ${DATA_DIR}
# * Launch and wait
# 
# It can also be used to train the model. In this context, 
# it assumes being run on Kubernetes therefore
#  * takes CLUSTER_CONF as an ENV, set by k8s via configMap
#  * takes POD_NAME as entry to evaluate its role and task id via POD_NAME=<job name>-<task id>
# 
# Note: this is hugely inspired from Google's Tensorflow Worshop 
# from August (old version of https://github.com/amygdala/tensorflow-workshop)
FROM tensorflow/tensorflow:1.3.0
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

RUN apt update && apt install -yqq --no-install-recommends \
        jq \
		curl \
		git && \
	apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/tensorflow/models.git /models

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

RUN echo "build --spawn_strategy=standalone --genrule_strategy=standalone" \
    >>/root/.bazelrc
ENV BAZELRC /root/.bazelrc

COPY bin/bazel /bin/bazel
COPY bin/bazel-real /bin/bazel-real

# PYTHON_BIN_PATH=/usr/bin/python PYTHON_LIB_PATH=/usr/local/lib/python2.7/dist-packages CC_OPT_FLAGS="-march=native" TF_NEED_JEMALLOC=1 TF_NEED_GCP=0 TF_NEED_HDFS=0 TF_ENABLE_XLA=0 TF_NEED_OPENCL=0 TF_NEED_CUDA=0 TF_CUDA_VERSION=v8.0 ./configure 

RUN git clone --recurse-submodules https://github.com/tensorflow/serving /serving && \
    cd /serving/tensorflow && \
    ./configure && \
    cd .. && \
    bazel build -c opt tensorflow_serving/...

COPY serve.sh /serve.sh

CMD [ "/serve.sh" ]
