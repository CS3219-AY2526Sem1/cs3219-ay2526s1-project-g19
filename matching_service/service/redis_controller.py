import asyncio
import json
import logging
import redis.asyncio as redis
from redis.asyncio.client import PubSub
from constants.matching import RELAX_LANGUAGE_DURATION, MatchingCriteriaEnum
from uuid import UUID
from fastapi import HTTPException, status
import time
from datetime import datetime
from constants.matching import MatchingCriteriaEnum, EXPIRATION_DURATION
from kafka.kafka_client import kafka_client
from schemas.events import SessionCreatedSchema
from schemas.matching import MatchingCriteriaSchema
from schemas.matching import MatchedCriteriaSchema
from service.websocket import websocket_service
from config import settings


logger = logging.getLogger(__name__)


class RedisController:
    def __init__(self):
        self.redis = redis.Redis(
            host=settings.redis_host,
            port=settings.redis_port,
            db=0,
            decode_responses=True,
        )
        self.general_queue_key="gen_queue:"
        self.websocket_service = websocket_service

        ## Add operations

    async def add_to_queue(
        self,
        user_id: UUID,
        criteria: MatchingCriteriaSchema
    ):
        # add to general queue with timestamp for fifo deconflict
        await self.add_to_general_queue(user_id=user_id)
        await self.store_user_criteria_map(
            user_id=user_id,
            topics=criteria.topics,
            difficulty=criteria.difficulty,
            primary_lang=criteria.primary_lang,
            secondary_lang=criteria.secondary_lang
        )
        await self.add_to_all_criteria_set(
            criteria=criteria,
            user_id=user_id
        )
        await self.set_expiry(user_id=user_id)
        if criteria.primary_lang:
            await self.set_relax_language_timer(user_id=user_id)

    async def find_match(
        self,
        user_id: UUID,
        match_secondary_lang: bool = False
    ) -> None:
        # store all criteria internal unions
        await self.store_all_union_set(
            user_id=user_id,
            match_secondary_lang=match_secondary_lang
        )
        # get intersection of criteria internal unions
        await self.store_inter_set(user_id=user_id)
        # deconflict with joined time
        matched_user_id = await self.get_earliest_user(user_id=user_id)
        if matched_user_id:
            await self.handle_matched(
                user_id=user_id,
                matched_user_id=matched_user_id
            )
        return

    async def remove_from_queue(self, user_id: UUID):
        user_expiry_key = self._get_user_expiry_key(user_id=user_id)
        await self.redis.delete(user_expiry_key)
        user_relax_key = self._get_user_relax_language_timer_key(user_id=user_id)
        await self.redis.delete(user_relax_key)
        await self.remove_from_general_queue(user_id=user_id)
        await self.remove_from_criteria_set(
            user_id=user_id,
            criteria=MatchingCriteriaEnum.TOPIC
        )
        await self.remove_from_criteria_set(
            user_id=user_id,
            criteria=MatchingCriteriaEnum.DIFFICULTY
        )
        await self.remove_from_criteria_set(
            user_id=user_id,
            criteria=MatchingCriteriaEnum.PRIMARY_LANG
        )
        await self.remove_from_criteria_set(
            user_id=user_id,
            criteria=MatchingCriteriaEnum.SECONDARY_LANG
        )
        # remove user criteria map
        await self.redis.delete(self._get_user_meta_key(user_id=user_id))
        return

    async def get_matched_criteria(
        self,
        user_id: UUID,
        matched_user_id: UUID
    ) -> MatchedCriteriaSchema:
        user_topic_criteria_set = set(await self.get_criteria_list(
            criteria=MatchingCriteriaEnum.TOPIC,
            user_id=user_id
        ))
        matched_user_topic_criteria_set = set(await self.get_criteria_list(
            criteria=MatchingCriteriaEnum.TOPIC,
            user_id=matched_user_id
        ))
        topic_set =  user_topic_criteria_set & matched_user_topic_criteria_set
        user_difficulty_criteria_set = set(await self.get_criteria_list(
            criteria=MatchingCriteriaEnum.DIFFICULTY,
            user_id=user_id
        ))
        matched_user_difficulty_criteria_set = set(await self.get_criteria_list(
            criteria=MatchingCriteriaEnum.DIFFICULTY,
            user_id=matched_user_id
        ))
        difficulty_set = user_difficulty_criteria_set & matched_user_difficulty_criteria_set
        user_primary_lang = await self.get_criteria_list(
                criteria=MatchingCriteriaEnum.PRIMARY_LANG,
                user_id=user_id
            )
        matched_user_primary_lang = await self.get_criteria_list(
            criteria=MatchingCriteriaEnum.PRIMARY_LANG,
            user_id=matched_user_id
        )
        if user_primary_lang and matched_user_primary_lang:
            if user_primary_lang[0] == matched_user_primary_lang[0]:
                language = user_primary_lang[0]
        else:
            user_lang = set(user_primary_lang + await self.get_criteria_list(
                criteria=MatchingCriteriaEnum.SECONDARY_LANG,
                user_id=user_id
            ))
            matched_user_lang = set(matched_user_primary_lang + await self.get_criteria_list(
                criteria=MatchingCriteriaEnum.SECONDARY_LANG,
                user_id=matched_user_id
            ))
            language_set = user_lang & matched_user_lang
            language = language_set.pop()
        return MatchedCriteriaSchema(
            topic=topic_set.pop(),
            difficulty=difficulty_set.pop(),
            language=language
        )

    async def start_expiry_listener(self):
        pubsub = self.get_pubsub()
        await pubsub.psubscribe("__keyevent@0__:expired")
        logger.info("Subscribed to key expiry events")

        try:
            while True:
                message = await pubsub.get_message(
                    ignore_subscribe_messages=True,
                    timeout=None
                )
                if message is not None:
                    expired_key = message["data"]
                    logger.info(f"Key expired: {expired_key}")
                    if expired_key.split(":")[0] == "relax":
                        asyncio.create_task(self.handle_relax_language(expired_key))
                    else:
                        asyncio.create_task(self.handle_timeout(expired_key))
                # Small sleep prevents a busy loop if Redis is quiet
                await asyncio.sleep(0.01)
        except asyncio.CancelledError:
            logger.info("Expiry event listener cancelled — shutting down")
        finally:
            await pubsub.close()
            await self.redis.close()

    async def start_session_created_listener(self):
        pubsub = self.get_pubsub()
        await pubsub.subscribe(settings.topic_session_created)
        logger.info(f"Subscribed to session created events on {settings.topic_session_created}")
        logger.info(settings.redis_host)

        async for msg in pubsub.listen():
            if msg["type"] == "message":
                data = json.loads(msg["data"])
                logger.info(msg["data"])
                session_created = SessionCreatedSchema(**data)
                await self.websocket_service.send_session_created(session_created=session_created)

    def get_pubsub(self) -> PubSub:
        r = redis.Redis(
            host=settings.redis_host,
            port=settings.redis_port,
            db=0,
            decode_responses=True,
        )
        pubsub = r.pubsub()
        return pubsub

    async def handle_timeout(self, expiry_key: str):
        user_id = UUID(expiry_key.split(":")[1])
        logger.info(f"User {user_id} expired. Removing from queue...")
        await self.websocket_service.send_timeout(user_id=user_id)
        await self.websocket_service.close_ws_connection(user_id=user_id)
        await self.remove_from_queue(user_id=user_id)
        return

    async def handle_relax_language(self, expired_key: str):
        user_id = UUID(expired_key.split(":")[2])
        logger.info(f"Relaxing language matching for user {user_id}")
        await self.websocket_service.send_relax_lang(user_id=user_id)
        second_lang = await self.get_criteria_list(
            criteria=MatchingCriteriaEnum.SECONDARY_LANG,
            user_id=user_id
        )
        await self.add_to_criteria_set(
            criteria=MatchingCriteriaEnum.LANGUAGE,
            keys=second_lang,
            user_id=user_id
        )
        await self.find_match(
            user_id=user_id,
            match_secondary_lang=True
        )

    async def handle_matched(
        self,
        user_id: UUID,
        matched_user_id: UUID
    ) -> None:
        matched_criteria = await self.get_matched_criteria(
            user_id=user_id,
            matched_user_id=matched_user_id
        )
        logger.info(f"User {user_id} matched with user {matched_user_id}. Criteria: {matched_criteria}")
        await redis_controller.remove_from_queue(user_id=user_id)
        await redis_controller.remove_from_queue(user_id=matched_user_id)
        kafka_client.pub_match_found(
            user_id_list=[user_id, matched_user_id],
            criteria=matched_criteria
        )
        return

    ## Add operations

    async def add_to_general_queue(self, user_id: UUID) -> None:
        time_joined = time.time()
        logger.info(f"Adding user {user_id} to queue at {datetime.fromtimestamp(time_joined).strftime("%Y-%m-%d %H:%M:%S")}")
        added = await self.redis.zadd(self.general_queue_key, {str(user_id): time_joined}, nx=True)
        # check if user was already in queue
        if not added:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"User {user_id} already in queue")
        return

    async def store_user_criteria_map(
        self,
        user_id: UUID,
        topics: list[str],
        difficulty: list[str],
        primary_lang: str,
        secondary_lang: list[str]
    ):
        meta_key = self._get_user_meta_key(user_id=user_id)
        await self.redis.hset(
            name=meta_key,
            mapping={
                MatchingCriteriaEnum.TOPIC.value: json.dumps(topics),
                MatchingCriteriaEnum.DIFFICULTY.value: json.dumps(difficulty),
                MatchingCriteriaEnum.PRIMARY_LANG.value: json.dumps(primary_lang),
                MatchingCriteriaEnum.SECONDARY_LANG.value: json.dumps(secondary_lang)
            }
        )
        return

    async def add_to_all_criteria_set(
        self,
        criteria: MatchingCriteriaSchema,
        user_id: UUID
    ) -> None:
        await self.add_to_criteria_set(
            criteria=MatchingCriteriaEnum.TOPIC,
            keys=criteria.topics,
            user_id=user_id
        )
        await self.add_to_criteria_set(
            criteria=MatchingCriteriaEnum.DIFFICULTY,
            keys=criteria.difficulty,
            user_id=user_id
        )
        await self.add_to_criteria_set(
            criteria=MatchingCriteriaEnum.LANGUAGE,
            keys=criteria.primary_lang if criteria.primary_lang else criteria.secondary_lang,
            user_id=user_id
        )
        return

    async def add_to_criteria_set(
        self,
        criteria: MatchingCriteriaEnum,
        keys: str | list[str],
        user_id: UUID
    ):
        redis_key_list = self._get_criteria_key_list(criteria=criteria, criteria_list=keys)
        for key in redis_key_list:
            await self.redis.sadd(key, str(user_id))
        return

    async def set_expiry(self, user_id: UUID):
        user_expiry_key = self._get_user_expiry_key(user_id=user_id)
        await self.redis.set(user_expiry_key, "1", ex=EXPIRATION_DURATION)
        return

    async def set_relax_language_timer(self, user_id: UUID):
        user_relax_language_key = self._get_user_relax_language_timer_key(user_id=user_id)
        await self.redis.set(user_relax_language_key, "1", ex=RELAX_LANGUAGE_DURATION)
        return

    ## Query operations

    async def store_all_union_set(
        self,
        user_id: UUID,
        match_secondary_lang: bool = False
    ) -> None:
        await self.store_union_set(criteria=MatchingCriteriaEnum.TOPIC, user_id=user_id)
        await self.store_union_set(criteria=MatchingCriteriaEnum.DIFFICULTY, user_id=user_id)
        await self.store_union_set(
            criteria=MatchingCriteriaEnum.LANGUAGE,
            user_id=user_id,
            match_secondary_lang=match_secondary_lang
        )

    async def store_union_set(
        self,
        criteria: MatchingCriteriaEnum,
        user_id: UUID,
        match_secondary_lang: bool = False
    ) -> None:
        criteria_list = await self.get_criteria_list(
            criteria=MatchingCriteriaEnum.PRIMARY_LANG if criteria == MatchingCriteriaEnum.LANGUAGE else criteria,
            user_id=user_id
        )
        if criteria == MatchingCriteriaEnum.LANGUAGE and match_secondary_lang:
            criteria_list += await self.get_criteria_list(
                criteria=MatchingCriteriaEnum.SECONDARY_LANG,
                user_id=user_id
            )
        redis_key_list = self._get_criteria_key_list(criteria=criteria, criteria_list=criteria_list)
        if redis_key_list:
            await self.redis.sunionstore(
                self._get_union_set_key(criteria=criteria, user_id=user_id),
                *redis_key_list
            )
        return

    async def store_inter_set(
        self,
        user_id: UUID
    ) -> None:
        intersection_key = self._get_intersection_key(user_id=user_id)
        keys = [
            self._get_union_set_key(criteria=MatchingCriteriaEnum.TOPIC, user_id=user_id),
            self._get_union_set_key(criteria=MatchingCriteriaEnum.DIFFICULTY, user_id=user_id),
            self._get_union_set_key(criteria=MatchingCriteriaEnum.LANGUAGE, user_id=user_id)
        ]
        await self.redis.sinterstore(
            dest=intersection_key,
            keys=keys
        )
        # remove self
        await self.redis.srem(
            intersection_key,
            str(user_id)
        )
        # clean up union sets
        await self.redis.delete(*keys)
        return

    async def get_criteria_list(
        self,
        criteria: MatchingCriteriaEnum,
        user_id: UUID
    ) -> list[str]:
        meta_key = self._get_user_meta_key(user_id=user_id)
        raw = await self.redis.hget(name=meta_key, key=criteria.value)
        if not raw:
            return []
        criteria_list = json.loads(await self.redis.hget(name=meta_key, key=criteria.value))
        if criteria_list is None:
            criteria_list = []
        if isinstance(criteria_list, str):
            return [criteria_list]
        return criteria_list

    async def get_earliest_user(self, user_id: UUID) -> UUID | None:
        intersection_key = self._get_intersection_key(user_id=user_id)
        inter_set_length = await self.redis.scard(intersection_key)
        if inter_set_length == 0:
            return None
        if inter_set_length == 1:
            return UUID(await self.redis.spop(intersection_key))
        temp_set_key = f"sortedset:match:user:{str(user_id)}"
        await self.redis.zinterstore(
            temp_set_key,
            {self.general_queue_key: 1, intersection_key: 0},  # keep sorted set scores (timestamp)
            aggregate="SUM"
        )
        assert await self.redis.zcard(temp_set_key) > 0
        earliest_user = (await self.redis.zpopmin(temp_set_key, 1))[0][0]
        await self.redis.delete(intersection_key, temp_set_key)
        return UUID(earliest_user)

    ## Remove operations

    async def remove_from_general_queue(self, user_id: UUID) -> None:
        await self.redis.zrem(self.general_queue_key, str(user_id))
        return

    async def remove_from_criteria_set(
        self,
        user_id: UUID,
        criteria: MatchingCriteriaEnum
    ) -> None:
        criteria_list = await self.get_criteria_list(criteria=criteria, user_id=user_id)
        key_list = self._get_criteria_key_list(criteria=criteria, criteria_list=criteria_list)
        for key in key_list:
            await self.redis.srem(key, str(user_id))
        return

    ## Helper methods

    def _get_criteria_key_list(
        self,
        criteria: MatchingCriteriaEnum,
        criteria_list: list[str]
    ) -> list[str]:
        if criteria == MatchingCriteriaEnum.PRIMARY_LANG or criteria == MatchingCriteriaEnum.SECONDARY_LANG:
            criteria = MatchingCriteriaEnum.LANGUAGE
        if isinstance(criteria_list, str):
            criteria_list = [criteria_list]
        return [f"queue:{criteria.value}:{key}" for key in criteria_list]

    def _get_union_set_key(
        self,
        criteria: MatchingCriteriaEnum,
        user_id: UUID
    ) -> str:
        if criteria == MatchingCriteriaEnum.PRIMARY_LANG:
            criteria = MatchingCriteriaEnum.LANGUAGE
        return f"set:union:{criteria.value}:user:{str(user_id)}"

    def _get_intersection_key(
        self,
        user_id: UUID
    ) -> str:
        return f"set:intersection:user:{str(user_id)}"

    def _get_user_meta_key(self, user_id: UUID) -> str:
        return f"user:{user_id}:meta"

    def _get_user_expiry_key(self, user_id: UUID) -> str:
        return f"user_expiry:{user_id}"

    def _get_user_relax_language_timer_key(self, user_id: UUID) -> str:
        return f"relax:user:{user_id}"


redis_controller = RedisController()
