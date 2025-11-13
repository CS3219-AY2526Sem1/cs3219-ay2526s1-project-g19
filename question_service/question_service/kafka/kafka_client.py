import logging
from confluent_kafka import Producer, Consumer, KafkaError, Message
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer
from question_service.kafka.config import consumer_config, producer_admin_config, schema_registry_conf

logger = logging.getLogger(__name__)

class KafkaClient:
    def __init__(self):
        self.schema_registry_client = SchemaRegistryClient(schema_registry_conf)
        self.deserializer = AvroDeserializer(
            schema_registry_client=self.schema_registry_client
        )
        self.producer = Producer(producer_admin_config)
        self.consumer = Consumer(consumer_config)

    def consumer_listen(self, topic, handler):
        self.consumer.subscribe([topic])
        logger.info(f"Kafka consumer started. Subscribed to {topic}")

        try:
            while True:
                msg = self.consumer.poll(1.0)
                if msg is None:
                    continue
                if msg.error():
                    if msg.error().code() != KafkaError._PARTITION_EOF:
                        logger.error(f"Kafka error: {msg.error()}")
                    continue
                handler(msg)
        except KeyboardInterrupt:
            logger.info("Stopping consumer...")
        finally:
            self.consumer.close()


kafka_client = KafkaClient()
