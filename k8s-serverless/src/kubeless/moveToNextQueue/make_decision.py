import json
import random
import time

from kafka import KafkaProducer
from kafka.errors import KafkaError

producer=KafkaProducer(bootstrap_servers='kafka.kubeless:9092',value_serializer=lambda v: json.dumps(v).encode('utf-8'))

def handler(context):
    risk = context.get('risk')
    if risk > 70:
        queue = 'denied'
    else:
        queue = 'accepted'

    msg = {'policy':context.get('policy', '0000A'),'action':context.get('action', 'new'),'description':context.get('description','N/A'), 'risk': risk, 'status': queue}
    producer.send(queue, msg)
    producer.flush()
    print msg