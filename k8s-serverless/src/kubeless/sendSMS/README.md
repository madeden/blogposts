# Simple Python http to Kafka

Make sure and `kubeless` is installed. See the installation guide:
* [Kubeless](https://github.com/kubeless/kubeless/blob/master/README.md#usage)

You can deploy the function with kubeless :

## Deploy the function with kubeless

### 1. Deploy
In order to deploy the function run the following command:

```bash
$ kubeless function deploy send-ko-sms \
	--from-file send_sms.py \
	--handler send_sms.handler \
	--runtime python2.7 \
	--trigger-topic denied \
	--dependencies requirements.txt
$ kubeless function deploy send-ok-sms \
	--from-file send_sms.py \
	--handler send_sms.handler \
	--runtime python2.7 \
	--trigger-topic accepted \
	--dependencies requirements.txt
```

You can list the function with `kubeless function ls` and you should see the following:

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

