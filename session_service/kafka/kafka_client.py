import logging
from confluent_kafka import Producer, Consumer, Message, KafkaError
from confluent_kafka.schema_registry import SchemaRegistryClient
from kafka.kafka_config import schema_registry_conf, producer_config, consumer_config
from confluent_kafka.schema_registry.avro import AvroDeserializer, AvroSerializer
from confluent_kafka.serialization import SerializationContext, MessageField


logger = logging.getLogger(__name__)


class KafkaController:
    def __init__(self):
        self.producer = Producer(producer_config)
        self.schema_registry_client = SchemaRegistryClient(schema_registry_conf)
        self.deserializer = AvroDeserializer(self.schema_registry_client)
        self.consumer = Consumer(consumer_config)

    async def consumer_listen(
        self,
        topics: list[str],
        handler
    ):
        self.consumer.subscribe(topics)
        logger.info(f"Kafka consumer started. Subscribed to {topics}")

        try:
            while True:
                msg = self.consumer.poll(1.0)
                if msg is None:
                    continue
                if msg.error():
                    if msg.error().code() != KafkaError._PARTITION_EOF:
                        logger.error(f"Kafka error: {msg.error()}")
                    continue
                await handler(msg)
        except KeyboardInterrupt:
            logger.info("Stopping consumer...")
        finally:
            self.consumer.close()

    def produce(
        self,
        topic: str,
        key: str,
        value: dict,
        serializer: AvroSerializer
    ) -> None:
        self.producer.produce(
            topic=topic,
            key=key,
            value=serializer(
                value,
                SerializationContext(topic, MessageField.VALUE)
            )
        )
        return

    def delivery_report(self, err: Exception | None, msg: Message) -> None:
        if err is not None:
            logger.error(f"Delivery failed for record {msg.key().decode()}: {err}")
        else:
            logger.info(f"Record {msg.key().decode()} successfully produced to {msg.topic()} [{msg.partition()}]")
        return

    def shutdown(self):
        self.producer.flush()
        return


kafka_client = KafkaController()
