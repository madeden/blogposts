#!/bin/bash
# This script will perform an evaluation of the model on a separate GPU
# and output to Tensorboard. 
# Note options that could be used to improve this job: 
# usage: imagenet_eval.py [-h] [--batch_size BATCH_SIZE]
#                         [--image_size IMAGE_SIZE]
#                         [--num_preprocess_threads NUM_PREPROCESS_THREADS]
#                         [--num_readers NUM_READERS]
#                         [--input_queue_memory_factor INPUT_QUEUE_MEMORY_FACTOR]
#                         [--eval_dir EVAL_DIR]
#                         [--checkpoint_dir CHECKPOINT_DIR]
#                         [--eval_interval_secs EVAL_INTERVAL_SECS]
#                         [--run_once [RUN_ONCE]] [--norun_once]
#                         [--num_examples NUM_EXAMPLES] [--subset SUBSET]
#                         [--data_dir DATA_DIR]
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
#   --eval_dir EVAL_DIR   Directory where to write event logs.
#   --checkpoint_dir CHECKPOINT_DIR
#                         Directory where to read model checkpoints.
#   --eval_interval_secs EVAL_INTERVAL_SECS
#                         How often to run the eval.
#   --run_once [RUN_ONCE]
#                         Whether to run eval only once.
#   --norun_once
#   --num_examples NUM_EXAMPLES
#                         Number of examples to run. Note that the eval ImageNet
#                         dataset contains 50000 examples.
#   --subset SUBSET       Either 'validation' or 'train'.
#   --data_dir DATA_DIR   Path to the processed data, i.e. TFRecord of Example
#                         protos.
mkdir -p "${DATA_DIR}/${DATASET}-eval"
mkdir -p "${DATA_DIR}/${DATASET}"

cd /models/inception

bazel build inception/${DATASET}_eval

bazel-bin/inception/${DATASET}_eval \
	--checkpoint_dir="${DATA_DIR}/${DATASET}-checkpoints" \
	--eval_dir="${DATA_DIR}/${DATASET}-eval" \
    --data_dir="${DATA_DIR}/${DATASET}" \
	--subset="validation"

