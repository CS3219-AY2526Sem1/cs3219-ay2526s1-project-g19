from datetime import datetime
import logging
from uuid import UUID, uuid4
from confluent_kafka import Producer, Consumer, Message, KafkaError
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.serialization import SerializationContext, MessageField
from config import settings
from schemas.events import MatchFoundSchema
from schemas.matching import MatchedCriteriaSchema
from confluent_kafka.schema_registry.avro import AvroSerializer, AvroDeserializer
from kafka.kafka_config import schema_registry_conf, producer_config, consumer_config

logger = logging.getLogger(__name__)


class KafkaClient:
    def __init__(self):
        self.producer = Producer(producer_config)
        with open("kafka/schemas/match_found.avsc") as f:
            match_found_schema = f.read()
        self.schema_registry_client = SchemaRegistryClient(schema_registry_conf)
        self.match_found_serializer = AvroSerializer(
            self.schema_registry_client,
            match_found_schema
        )
        self.consumer = Consumer(consumer_config)
        self.deserializer = AvroDeserializer(self.schema_registry_client)

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

    def delivery_report(self, err: Exception | None, msg: Message):
        if err is not None:
            logger.error(f"Delivery failed for record {msg.key().decode()}: {err}")
        else:
            logger.info(f"Record {msg.key().decode()} successfully produced to {msg.topic()} [{msg.partition()}]")

    def pub_match_found(
        self,
        user_id_list: list[UUID],
        criteria: MatchedCriteriaSchema
    ):
        match_id = uuid4()
        match = MatchFoundSchema(
            match_id=match_id,
            user_id_list=user_id_list,
            topic=criteria.topic,
            difficulty=criteria.difficulty,
            language=criteria.language,
            timestamp=datetime.now()
        )
        serialized_value = self.match_found_serializer(
            match.model_dump(mode="json"),
            SerializationContext(settings.topic_match_found, MessageField.VALUE)
        )
        self.producer.produce(
            topic=settings.topic_match_found,
            key=str(match_id),
            value=serialized_value,
            on_delivery=self.delivery_report
        )
        self.producer.flush()
        return

    def shutdown(self):
        self.producer.flush()
        return


kafka_client = KafkaClient()
