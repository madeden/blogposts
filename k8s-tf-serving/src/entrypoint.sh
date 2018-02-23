#!/bin/bash

[ ! -x /usr/local/bin/tensorflow_model_server ] && \
	chmod +x /usr/local/bin/tensorflow_model_server

/usr/local/bin/tensorflow_model_server \
	--port=${PORT} \
	--model_name=${MODEL_NAME} \
	--model_base_path=${MODEL_PATH}
