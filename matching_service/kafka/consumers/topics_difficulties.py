import asyncio
import json
import logging
import logging.config
from kafka.kafka_client import kafka_client
from config import settings
from confluent_kafka import Message
from service.redis_controller import redis_controller

with open("log_config.json", "r") as f:
    config = json.load(f)
logging.config.dictConfig(config)
logger = logging.getLogger(__name__)


class TopicsDifficultiesConsumer:
    """Consumes topics and difficulties updates from Kafka."""
    
    def __init__(self):
        self.topics = [settings.topic_topics_updated, settings.topic_difficulties_updated]
    
    async def listen(self):
        """Start listening to topics and difficulties updates."""
        await kafka_client.consumer_listen(
            topics=self.topics,
            handler=self.handle_message
        )
    
    async def handle_message(self, msg: Message):
        """Handle incoming topics or difficulties update messages."""
        try:
            key = msg.key().decode()
            value = kafka_client.deserializer(msg.value())
            topic_name = msg.topic()
            
            logger.info(f"Received {topic_name} update: {value}")
            
            if topic_name == settings.topic_topics_updated:
                await self.handle_topics_update(value)
            elif topic_name == settings.topic_difficulties_updated:
                await self.handle_difficulties_update(value)
            else:
                logger.warning(f"Unknown topic: {topic_name}")
        except Exception as e:
            logger.error(f"Error handling message: {e}")
    
    async def handle_topics_update(self, data: dict) -> None:
        """Handle topics update message."""
        topics = data.get("topics", [])
        timestamp = data.get("timestamp")
        version = data.get("version")
        await redis_controller.update_topics(topics=topics)
        logger.info(f"Updated cached topics: {topics} (version: {version}, timestamp: {timestamp})")
        return
    
    async def handle_difficulties_update(self, data: dict) -> None:
        """Handle difficulties update message."""
        difficulties = data.get("difficulties", [])
        timestamp = data.get("timestamp")
        version = data.get("version")
        await redis_controller.update_difficulties(difficulties=difficulties)
        logger.info(f"Updated cached difficulties: {difficulties} (version: {version}, timestamp: {timestamp})")
        return


if __name__ == "__main__":
    consumer = TopicsDifficultiesConsumer()
    asyncio.run(consumer.listen())
