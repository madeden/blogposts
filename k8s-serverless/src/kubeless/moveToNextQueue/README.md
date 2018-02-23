# Simple Python http to Kafka

Make sure and `kubeless` is installed. See the installation guide:
* [Kubeless](https://github.com/kubeless/kubeless/blob/master/README.md#usage)

You can deploy the function with kubeless :

## Deploy the function with kubeless

### 1. Deploy

For this we suppose that the previous function httpToKafka has been setup already, with 4 topics (new, pending, accepted, denied). Each time a message lands into the "new" queue, which is the default operation, it will be processed and sent to the pending queue, at which point a decision happens to deny or accept it. 

In order to deploy the function run the following command:

```bash
$ kubeless function deploy move-to-next-queue \
	--from-file move_to_next_queue.py \
	--handler move_to_next_queue.handler \
	--runtime python2.7 \
	--trigger-topic new \
	--dependencies requirements.txt
$ kubeless function deploy make-decision \
	--from-file make_decision.py \
	--handler make_decision.handler \
	--runtime python2.7 \
	--trigger-topic pending \
	--dependencies requirements.txt
```

You can list the function with `kubeless function ls` and you should see the following:

```bash
$ kubeless function ls
+--------------------------------+-----------+----------------------------+-----------+-------+---------+--------------+
|     NAME                       | NAMESPACE |        HANDLER             |  RUNTIME  | TYPE  | TOPIC   | DEPENDENCIES |
+--------------------------------+-----------+----------------------------+-----------+-------+---------+--------------+
| http-to-kafka                  | default   | http_to_kafka.handler      | python2.7 | HTTP  |         |              |
| move-to-next-queue-decision    | default   | move_to_next_queue.handler | python2.7 | TOPIC | pending |              |
| make-decision                  | default   | make_decision.handler      | python2.7 | TOPIC | pending |              |
+--------------------------------+-----------+----------------------------+-----------+-------+---------+--------------+
```

### 2. Invoke

You can now call your function:

```bash
kubeless function call http-to-kafka --data '{"status":"new","policy":"1234H","action":"create","description":"foobar"}'
```

### 3. Results

This will publish a message in the topic "new" (from the status items) which is a JSON object containing the rest of the data:

```json
{
	"policy":"1234H",
	"action":"create",
	"description":"foobar"
}
```


There is no test that the topic exists, so make sure you create them before you try it out

