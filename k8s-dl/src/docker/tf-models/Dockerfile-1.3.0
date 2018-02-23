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

ENV DATA_DIR=/var/tensorflow/
ENV IMAGENET_USERNAME=username
ENV IMAGENET_ACCESS_KEY=api_key
ENV DATASET=imagenet

RUN apt update && apt install -yqq --no-install-recommends \
        wget \
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
COPY download.sh /download.sh
COPY ps.sh /ps.sh
COPY worker.sh /worker.sh
COPY eval.sh /eval.sh

# Note: we use download by default
# but load the train.sh as well to allow users to train on CPU via this image
CMD [ "/download.sh" ]
