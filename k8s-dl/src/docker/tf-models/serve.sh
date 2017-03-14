#!/bin/bash

echo "starting with port=$PORT, model $MODEL_NAME and path $MODEL_PATH"

/serving/bazel-bin/tensorflow_serving/model_servers/tensorflow_model_server \
    --port=${PORT}\
    ${BATCHING} \
    --model_name=${MODEL_NAME} \
    --model_base_path=${MODEL_PATH}

