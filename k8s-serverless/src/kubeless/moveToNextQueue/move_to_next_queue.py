import json
import random

from kafka import KafkaProducer
from kafka.errors import KafkaError

producer=KafkaProducer(bootstrap_servers='kafka.kubeless:9092',value_serializer=lambda v: json.dumps(v).encode('utf-8'))

def handler(context):
    risk = random.randint(1,100)
    msg = {'policy':context.get('policy', '0000A'),'action':context.get('action', 'new'),'description':context.get('description','N/A'), 'risk': risk}
    producer.send('pending', msg)
    producer.flush()
    print msg