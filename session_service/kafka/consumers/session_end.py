import asyncio
from datetime import timezone
import json
import logging
import logging.config
from uuid import uuid4
from config import settings
from kafka.kafka_client import kafka_client
from confluent_kafka import Message
from schemas.events import SessionEnd
from pg_db.core import engine
from sqlalchemy.ext.asyncio import AsyncSession
from crud.session import session_repo


with open("log_config.json", "r") as f:
    config = json.load(f)
logging.config.dictConfig(config)
logger = logging.getLogger(__name__)


class SessionEndConsumer:
    def __init__(self):
        self.topics = [settings.topic_session_end]

    async def listen(self):
        await kafka_client.consumer_listen(
            topics=self.topics,
            handler=self.handle_session_end
        )
        return

    async def handle_session_end(self, msg: Message):
        key = msg.key().decode()
        value = kafka_client.deserializer(msg.value())
        session_end = SessionEnd(
            **value
        )
        logger.info(f"Received key {key}: value {value}")
        async with AsyncSession(engine) as session:
            await session_repo.end_session(
                session_id=session_end.session_id,
                ended_at=session_end.ended_at.replace(tzinfo=None),
                db_session=session
            )
        return


if __name__=="__main__":
    consumer = SessionEndConsumer()
    asyncio.run(consumer.listen())
    kafka_client.shutdown()
