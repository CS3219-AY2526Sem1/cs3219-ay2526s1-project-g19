import json
import logging
import os
from dotenv import load_dotenv
import redis
from constants.matching import MatchingCriteriaEnum
from uuid import UUID
from fastapi import HTTPException, status
import time
from datetime import datetime
from constants.matching import MatchingCriteriaEnum
from schemas.matching import MatchedCriteriaSchema, MatchingCriteriaSchema


load_dotenv()
logger = logging.getLogger(__name__)


class RedisController:
    def __init__(self):
        self.redis = redis.Redis(
            host=os.getenv("REDIS_HOST"),
            port=os.getenv("REDIS_PORT"),
            db=0,
            decode_responses=True
        )
        self.general_queue_key="gen_queue:"

        ## Add operations

    def add_to_queue(
        self,
        user_id: UUID,
        criteria: MatchingCriteriaSchema
    ):
        # add to general queue with timestamp for fifo deconflict
        self.add_to_general_queue(user_id=user_id)
        self.store_user_criteria_map(
            user_id=user_id,
            topics=criteria.topics,
            difficulty=criteria.difficulty
        )
        self.add_to_criteria_set(
            criteria=MatchingCriteriaEnum.TOPIC,
            keys=criteria.topics,
            user_id=user_id
        )
        self.add_to_criteria_set(
            criteria=MatchingCriteriaEnum.DIFFICULTY,
            keys=criteria.difficulty,
            user_id=user_id
        )

    def find_match(self, user_id: UUID) -> UUID | None:
        # store all criteria internal unions
        self.store_union_set(criteria=MatchingCriteriaEnum.TOPIC, user_id=user_id)
        self.store_union_set(criteria=MatchingCriteriaEnum.DIFFICULTY, user_id=user_id)
        # get intersection of criteria internal unions
        self.store_inter_set(user_id=user_id)
        # deconflict with joined time
        return self.get_earliest_user(user_id=user_id)

    def remove_from_queue(self, user_id: UUID):
        self.remove_from_general_queue(user_id=user_id)
        self.remove_from_criteria_set(
            user_id=user_id,
            criteria=MatchingCriteriaEnum.TOPIC
        )
        self.remove_from_criteria_set(
            user_id=user_id,
            criteria=MatchingCriteriaEnum.DIFFICULTY
        )
        # remove user criteria map
        self.redis.delete(self._get_user_meta_key(user_id=user_id))
        return

    def get_matched_criteria(
        self,
        user_id: UUID,
        matched_user_id: UUID
    ) -> MatchedCriteriaSchema:
        topic_set = set(self.get_criteria_list(criteria=MatchingCriteriaEnum.TOPIC, user_id=user_id)) & \
            set(self.get_criteria_list(criteria=MatchingCriteriaEnum.TOPIC, user_id=matched_user_id))
        difficulty_set = set(self.get_criteria_list(criteria=MatchingCriteriaEnum.DIFFICULTY, user_id=user_id)) & \
            set(self.get_criteria_list(criteria=MatchingCriteriaEnum.DIFFICULTY, user_id=matched_user_id))
        return MatchedCriteriaSchema(
            topic=topic_set.pop(),
            difficulty=difficulty_set.pop()
        )

    ## Add operations

    def add_to_general_queue(self, user_id: UUID) -> None:
        time_joined = time.time()
        logger.info(f"Adding user {user_id} to queue at {datetime.fromtimestamp(time_joined).strftime("%Y-%m-%d %H:%M:%S")}")
        added = self.redis.zadd(self.general_queue_key, {str(user_id): time_joined}, nx=True)
        # check if user was already in queue
        if not added:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"User {user_id} already in queue")
        return

    def store_user_criteria_map(
        self,
        user_id: UUID,
        topics: list[str],
        difficulty: list[str]
    ):
        meta_key = self._get_user_meta_key(user_id=user_id)
        self.redis.hset(
            name=meta_key,
            mapping={
                MatchingCriteriaEnum.TOPIC.value: json.dumps(topics),
                MatchingCriteriaEnum.DIFFICULTY.value: json.dumps(difficulty)
            }
        )

    def add_to_criteria_set(
        self,
        criteria: MatchingCriteriaEnum,
        keys: list[str],
        user_id: UUID
    ):
        redis_key_list = self._get_criteria_key_list(criteria=criteria, criteria_list=keys)
        for key in redis_key_list:
            self.redis.sadd(key, str(user_id))
        return

    ## Query operations

    def store_union_set(
        self,
        criteria: MatchingCriteriaEnum,
        user_id: UUID
    ) -> None:
        criteria_list = self.get_criteria_list(criteria=criteria, user_id=user_id)
        redis_key_list = self._get_criteria_key_list(criteria=criteria, criteria_list=criteria_list)
        if redis_key_list:
            self.redis.sunionstore(
                self._get_union_set_key(criteria=criteria, user_id=user_id),
                *redis_key_list
            )
        return

    def store_inter_set(
        self,
        user_id: UUID
    ) -> None:
        intersection_key = self._get_intersection_key(user_id=user_id)
        keys = [
            self._get_union_set_key(criteria=MatchingCriteriaEnum.TOPIC, user_id=user_id),
            self._get_union_set_key(criteria=MatchingCriteriaEnum.DIFFICULTY, user_id=user_id)
        ]
        self.redis.sinterstore(
            dest=intersection_key,
            keys=keys
        )
        # remove self
        self.redis.srem(
            intersection_key,
            str(user_id)
        )
        # clean up union sets
        self.redis.delete(*keys)
        return

    def get_criteria_list(
        self,
        criteria: MatchingCriteriaEnum,
        user_id: UUID
    ) -> list[str]:
        meta_key = self._get_user_meta_key(user_id=user_id)
        return json.loads(self.redis.hget(name=meta_key, key=criteria.value))

    def get_earliest_user(self, user_id: UUID) -> UUID | None:
        intersection_key = self._get_intersection_key(user_id=user_id)
        inter_set_length = self.redis.scard(intersection_key)
        if inter_set_length == 0:
            return None
        if inter_set_length == 1:
            return UUID(self.redis.spop(intersection_key))
        temp_set_key = f"sortedset:match:user:{str(user_id)}"
        self.redis.zinterstore(
            temp_set_key,
            {self.general_queue_key: 1, intersection_key: 0},  # keep sorted set scores (timestamp)
            aggregate="SUM"
        )
        assert self.redis.zcard(temp_set_key) > 0
        earliest_user = self.redis.zpopmin(temp_set_key, 1)[0][0]
        self.redis.delete(intersection_key, temp_set_key)
        return UUID(earliest_user)

    ## Remove operations

    def remove_from_general_queue(self, user_id: UUID) -> None:
        self.redis.zrem(self.general_queue_key, str(user_id))
        return

    def remove_from_criteria_set(
        self,
        user_id: UUID,
        criteria: MatchingCriteriaEnum
    ) -> None:
        criteria_list = self.get_criteria_list(criteria=criteria, user_id=user_id)
        key_list = self._get_criteria_key_list(criteria=criteria, criteria_list=criteria_list)
        for key in key_list:
            self.redis.srem(key, str(user_id))
        return

    ## Helper methods

    def _get_criteria_key_list(
        self,
        criteria: MatchingCriteriaEnum,
        criteria_list: list[str]
    ) -> list[str]:
        return [f"queue:{criteria.value}:{key}" for key in criteria_list]

    def _get_union_set_key(
        self,
        criteria: MatchingCriteriaEnum,
        user_id: UUID
    ) -> str:
        return f"set:union:{criteria.value}:user:{str(user_id)}"

    def _get_intersection_key(
        self,
        user_id: UUID
    ) -> str:
        return f"set:intersection:user:{str(user_id)}"

    def _get_user_meta_key(self, user_id: UUID) -> str:
        return f"user:{user_id}:meta"

    ## Debug

    def debug_show(self) -> dict:
        r = self.redis
        result = {}

        keys = r.keys('*')
        if not keys:
            return {"message": "Redis is empty."}

        for key in sorted(keys):
            key_type = r.type(key)
            entry = {"type": key_type, "values": None}

            try:
                if key_type == 'set':
                    values = r.smembers(key)
                    entry["values"] = sorted(values)

                elif key_type == 'zset':
                    values = r.zrange(key, 0, -1, withscores=True)
                    entry["values"] = [{"member": member, "score": int(score)} for member, score in values]

                elif key_type == 'list':
                    values = r.lrange(key, 0, -1)
                    entry["values"] = values

                elif key_type == 'hash':
                    values = r.hgetall(key)
                    entry["values"] = values

                else:  # string
                    value = r.get(key)
                    entry["values"] = value

            except Exception as e:
                entry["error"] = str(e)

            result[key] = entry

        return result

    def clear_redis(self) -> None:
        self.redis.flushdb()
        return

redis_controller = RedisController()
