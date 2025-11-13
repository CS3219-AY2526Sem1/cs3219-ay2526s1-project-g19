import asyncio
import json
import logging
import logging.config
from kafka.kafka_client import kafka_client
from config import settings
from confluent_kafka import Message
from service.redis_controller import redis_controller
from schemas.events import SessionCreatedSchema


with open("log_config.json", "r") as f:
    config = json.load(f)
logging.config.dictConfig(config)
logger = logging.getLogger(__name__)


class SessionCreatedConsumer:
    def __init__(self):
        pass

    async def listen(self):
        await kafka_client.consumer_listen(
            topics=[settings.topic_session_created],
            handler=self.handle_session_created
        )

    async def handle_session_created(self, msg: Message):
        key = msg.key().decode()
        value = kafka_client.deserializer(msg.value())
        logger.info(f"Received key {key}: value {value}")
        session_created = SessionCreatedSchema(**value)
        await redis_controller.redis.publish(settings.topic_session_created, session_created.model_dump_json())
        return


if __name__=="__main__":
    consumer = SessionCreatedConsumer()
    asyncio.run(consumer.listen())
