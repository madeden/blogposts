#!/bin/bash
# This script will train the inception on CPU or GPU depending on the docker image you use. 
# Additional parameter that could be used in a more detailled post: 
# usage: imagenet_distributed_train.py [-h] [--batch_size BATCH_SIZE]
#                                      [--image_size IMAGE_SIZE]
#                                      [--num_preprocess_threads NUM_PREPROCESS_THREADS]
#                                      [--num_readers NUM_READERS]
#                                      [--input_queue_memory_factor INPUT_QUEUE_MEMORY_FACTOR]
#                                      [--job_name JOB_NAME]
#                                      [--ps_hosts PS_HOSTS]
#                                      [--worker_hosts WORKER_HOSTS]
#                                      [--train_dir TRAIN_DIR]
#                                      [--max_steps MAX_STEPS] [--subset SUBSET]
#                                      [--log_device_placement [LOG_DEVICE_PLACEMENT]]
#                                      [--nolog_device_placement]
#                                      [--task_id TASK_ID]
#                                      [--num_replicas_to_aggregate NUM_REPLICAS_TO_AGGREGATE]
#                                      [--save_interval_secs SAVE_INTERVAL_SECS]
#                                      [--save_summaries_secs SAVE_SUMMARIES_SECS]
#                                      [--initial_learning_rate INITIAL_LEARNING_RATE]
#                                      [--num_epochs_per_decay NUM_EPOCHS_PER_DECAY]
#                                      [--learning_rate_decay_factor LEARNING_RATE_DECAY_FACTOR]
#                                      [--data_dir DATA_DIR]

# optional arguments:
#   -h, --help            show this help message and exit
#   --batch_size BATCH_SIZE
#                         Number of images to process in a batch.
#   --image_size IMAGE_SIZE
#                         Provide square images of this size.
#   --num_preprocess_threads NUM_PREPROCESS_THREADS
#                         Number of preprocessing threads per tower. Please make
#                         this a multiple of 4.
#   --num_readers NUM_READERS
#                         Number of parallel readers during train.
#   --input_queue_memory_factor INPUT_QUEUE_MEMORY_FACTOR
#                         Size of the queue of preprocessed images. Default is
#                         ideal but try smaller values, e.g. 4, 2 or 1, if host
#                         memory is constrained. See comments in code for more
#                         details.
#   --job_name JOB_NAME   One of "ps", "worker"
#   --ps_hosts PS_HOSTS   Comma-separated list of hostname:port for the
#                         parameter server jobs. e.g.
#                         'machine1:2222,machine2:1111,machine2:2222'
#   --worker_hosts WORKER_HOSTS
#                         Comma-separated list of hostname:port for the worker
#                         jobs. e.g. 'machine1:2222,machine2:1111,machine2:2222'
#   --train_dir TRAIN_DIR
#                         Directory where to write event logs and checkpoint.
#   --max_steps MAX_STEPS
#                         Number of batches to run.
#   --subset SUBSET       Either "train" or "validation".
#   --log_device_placement [LOG_DEVICE_PLACEMENT]
#                         Whether to log device placement.
#   --nolog_device_placement
#   --task_id TASK_ID     Task ID of the worker/replica running the training.
#   --num_replicas_to_aggregate NUM_REPLICAS_TO_AGGREGATE
#                         Number of gradients to collect before updating the
#                         parameters.
#   --save_interval_secs SAVE_INTERVAL_SECS
#                         Save interval seconds.
#   --save_summaries_secs SAVE_SUMMARIES_SECS
#                         Save summaries interval seconds.
#   --initial_learning_rate INITIAL_LEARNING_RATE
#                         Initial learning rate.
#   --num_epochs_per_decay NUM_EPOCHS_PER_DECAY
#                         Epochs after which learning rate decays.
#   --learning_rate_decay_factor LEARNING_RATE_DECAY_FACTOR
#                         Learning rate decay factor.
#   --data_dir DATA_DIR   Path to the processed data, i.e. TFRecord of Example
#                         protos.
mkdir -p "${DATA_DIR}/${DATASET}-checkpoints"

cd /models/inception

# Notes: 
## | tr -d '\n ' | sed -e 's#,]#]#g' -e 's#,}#}#g' -> cleans up the bad JSON from the configMap
PS_HOSTS="$(echo ${CLUSTER_CONFIG} | tr -d '\n ' | sed -e 's#,]#]#g' -e 's#,}#}#g' | jq --raw-output '.ps[]' | tr '\n' ',' | sed 's/.$//' )"
WORKER_HOSTS="$(echo ${CLUSTER_CONFIG} | tr -d '\n ' | sed -e 's#,]#]#g' -e 's#,}#}#g' | jq --raw-output '.worker[]' | tr '\n' ',' | sed 's/.$//' )"
TASK_ID=$(echo ${POD_NAME} | cut -f2 -d'-')
JOB_NAME=$(echo ${POD_NAME} | cut -f1 -d'-')

echo "Starting job $JOB_NAME and task $TASK_ID"
bazel build inception/${DATASET}_distributed_train

bazel-bin/inception/${DATASET}_distributed_train \
	--batch_size=32 \
	--data_dir=${DATA_DIR}/${DATASET} \
	--train_dir=${DATA_DIR}/${DATASET}-checkpoints \
	--job_name="${JOB_NAME}" \
	--task_id=${TASK_ID} \
	--ps_hosts="${PS_HOSTS}" \
	--worker_hosts="${WORKER_HOSTS}" \
	--subset="train"


