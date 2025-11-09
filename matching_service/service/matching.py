import logging
from uuid import UUID

from fastapi import HTTPException, status

from schemas.matching import VALID_LANGUAGE_LIST, MatchingCriteriaSchema
from service.django_question_service import django_question_service
from service.redis_controller import redis_controller

logger = logging.getLogger(__name__)


class MatchingService:
    def __init__(self):
        self.redis_controller = redis_controller

    async def match_user(
        self,
        user_id: UUID,
        criteria: MatchingCriteriaSchema,
    ) -> str:
        criteria = await self.validate_and_transform_criteria(criteria=criteria)
        logger.info(f"Added user {user_id} to queue with criteria {criteria}")
        await self.redis_controller.add_to_queue(
            user_id=user_id,
            criteria=criteria
        )
        # find eligible matches
        await self.redis_controller.find_match(
            user_id=user_id,
            match_secondary_lang=criteria.primary_lang is None
        )
        return f"User {user_id} joined queue"

    async def validate_and_transform_criteria(
        self,
        criteria: MatchingCriteriaSchema
    ) -> MatchingCriteriaSchema:
        # validate topics
        valid_topics = await django_question_service.get_topics()
        for topic in criteria.topics:
            if topic not in valid_topics:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"Topic {topic} is not a valid topic in list {valid_topics}"
                )
        if len(criteria.topics) == 0:
            criteria.topics = valid_topics
        # validate difficulty
        valid_difficulty = await django_question_service.get_difficulty()
        for diff in criteria.difficulty:
            if diff not in valid_difficulty:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"Difficulty {diff} is not a valid difficulty in list {valid_difficulty}"
                )
        if len(criteria.difficulty) == 0:
            criteria.difficulty = valid_difficulty
        # validate language
        pri_lang = criteria.primary_lang
        sec_lang = criteria.secondary_lang
        invalid_lang_msg = "Language {} is not a valid language in the list " + str(VALID_LANGUAGE_LIST)
        if pri_lang is not None:
            if pri_lang not in VALID_LANGUAGE_LIST:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=invalid_lang_msg.format(criteria.primary_lang)
                )
            if pri_lang in sec_lang:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"Primary language {pri_lang} cannot be in secondary languages list {sec_lang}"
                )
            for lang in sec_lang:
                if lang not in VALID_LANGUAGE_LIST:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                        detail=invalid_lang_msg.format(lang)
                    )
        else:
            if len(sec_lang) > 0:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"Cannot have secondary languages without primary language"
                )
            else:
                criteria.secondary_lang = VALID_LANGUAGE_LIST
        return criteria


matching_service = MatchingService()
