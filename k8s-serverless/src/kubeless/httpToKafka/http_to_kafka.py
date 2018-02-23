import json

from kafka import KafkaProducer
from kafka.errors import KafkaError

producer=KafkaProducer(bootstrap_servers='kafka.kubeless:9092',value_serializer=lambda v: json.dumps(v).encode('utf-8'))

def handler(context):
    msg = {'policy':context.json.get('policy', '0000A'),'action':context.json.get('action', 'new'),'description':context.json.get('description','N/A')}
    producer.send('new', msg)
    producer.flush()
