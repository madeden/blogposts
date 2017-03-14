#!/bin/bash

mkdir -p "${DATA_DIR}/checkpoints"

cd "${DATA_DIR}/checkpoints"
curl -O http://download.tensorflow.org/models/image/imagenet/inception-v3-2016-03-01.tar.gz
tar xzf inception-v3-2016-03-01.tar.gz

mkdir -p "${DATA_DIR}/${DATASET}"

cd /models/inception

bazel build inception/download_and_preprocess_${DATASET}

bazel-bin/inception/download_and_preprocess_${DATASET} "${DATA_DIR}/${DATASET}"




