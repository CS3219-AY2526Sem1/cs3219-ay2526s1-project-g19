import logging
import time
from datetime import datetime
from confluent_kafka import Producer, KafkaError
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import SerializationContext, MessageField
from question_service.kafka.config import (
    producer_admin_config, 
    schema_registry_conf,
    TOPICS_UPDATED_TOPIC,
    DIFFICULTIES_UPDATED_TOPIC
)
from question_service.models import Question, Difficulty

logger = logging.getLogger(__name__)


class TopicsDifficultiesPublisher:
    """Publishes topics and difficulties updates to Kafka topics."""
    
    def __init__(self):
        self.producer = Producer(producer_admin_config)
        self.schema_registry_client = SchemaRegistryClient(schema_registry_conf)
        
        # Load schemas
        with open("question_service/kafka/schemas/topics_updated.avsc") as f:
            topics_schema = f.read()
        with open("question_service/kafka/schemas/difficulties_updated.avsc") as f:
            difficulties_schema = f.read()
            
        self.topics_serializer = AvroSerializer(
            self.schema_registry_client,
            topics_schema
        )
        self.difficulties_serializer = AvroSerializer(
            self.schema_registry_client,
            difficulties_schema
        )
    
    def delivery_report(self, err, msg):
        """Callback for message delivery reports."""
        if err is not None:
            logger.error(f"Delivery failed for record {msg.key().decode()}: {err}")
        else:
            logger.info(f"Record {msg.key().decode()} successfully produced to {msg.topic()} [{msg.partition()}]")
    
    def publish_topics_update(self, topics_list):
        """Publish updated topics list to Kafka."""
        try:
            # Create the message payload
            payload = {
                "topics": topics_list,
                "timestamp": int(time.time() * 1000),  # milliseconds
                "version": "1.0"
            }
            
            # Serialize and produce
            serialized_value = self.topics_serializer(
                payload,
                SerializationContext(TOPICS_UPDATED_TOPIC, MessageField.VALUE)
            )
            
            self.producer.produce(
                topic=TOPICS_UPDATED_TOPIC,
                key="topics_update",
                value=serialized_value,
                on_delivery=self.delivery_report
            )
            self.producer.flush()
            
            logger.info(f"Published topics update: {topics_list}")
            
        except Exception as e:
            logger.error(f"Failed to publish topics update: {e}")
    
    def publish_difficulties_update(self, difficulties_list):
        """Publish updated difficulties list to Kafka."""
        try:
            # Create the message payload
            payload = {
                "difficulties": difficulties_list,
                "timestamp": int(time.time() * 1000),  # milliseconds
                "version": "1.0"
            }
            
            # Serialize and produce
            serialized_value = self.difficulties_serializer(
                payload,
                SerializationContext(DIFFICULTIES_UPDATED_TOPIC, MessageField.VALUE)
            )
            
            self.producer.produce(
                topic=DIFFICULTIES_UPDATED_TOPIC,
                key="difficulties_update",
                value=serialized_value,
                on_delivery=self.delivery_report
            )
            self.producer.flush()
            
            logger.info(f"Published difficulties update: {difficulties_list}")
            
        except Exception as e:
            logger.error(f"Failed to publish difficulties update: {e}")
    
        """Publish initial topics and difficulties data on startup."""
    def publish_initial_data(self):
        try:
            # Get current topics from database
            topics_query = Question.objects.filter(is_active=True).values_list('topics', flat=True)
            topics_set = set()
            for topics_list in topics_query:
                if topics_list:  # Handle None/empty values
                    topics_set.update(topics_list)
            topics_list = sorted(list(topics_set))
            
            # Get current difficulties
            difficulties_list = [choice[0] for choice in Difficulty.choices]
            
            # Publish both
            self.publish_topics_update(topics_list)
            self.publish_difficulties_update(difficulties_list)
            
            logger.info("Published initial topics and difficulties data")
            
        except Exception as e:
            logger.error(f"Failed to publish initial data: {e}")
    
    def shutdown(self):
        """Clean shutdown of the producer."""
        self.producer.flush()


# Global instance
topics_difficulties_publisher = TopicsDifficultiesPublisher()

