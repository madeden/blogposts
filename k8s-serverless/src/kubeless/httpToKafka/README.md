# Simple Python http to Kafka

Make sure and `kubeless` is installed. See the installation guide:
* [Kubeless](https://github.com/kubeless/kubeless/blob/master/README.md#usage)

You can deploy the function with kubeless :

## Deploy the function with kubeless

### 1. Deploy
In order to deploy the function run the following command:

```bash
$ kubeless function deploy http-to-kafka --from-file http_to_kafka.py --handler http_to_kafka.handler --runtime python2.7 --trigger-http --dependencies requirements.txt
```

You can list the function with `kubeless function ls` and you should see the following:

```bash
$ kubeless function ls
+---------------+-----------+-----------------------+-----------+------+-------+--------------+
|     NAME      | NAMESPACE |        HANDLER        |  RUNTIME  | TYPE | TOPIC | DEPENDENCIES |
+---------------+-----------+-----------------------+-----------+------+-------+--------------+
| http-to-kafka | default   | http_to_kafka.handler | python2.7 | HTTP |       |              |
+---------------+-----------+-----------------------+-----------+------+-------+--------------+
```


Now create a few topics in the Kafka Message Bus : 

```bash
$ kubeless topic create new
$ kubeless topic create pending
$ kubeless topic create accepted
$ kubeless topic create denied
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

