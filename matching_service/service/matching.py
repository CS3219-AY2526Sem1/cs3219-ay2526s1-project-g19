import logging
from uuid import UUID
from dotenv import load_dotenv
from schemas.matching import MatchingCriteriaSchema
from service.redis_controller import redis_controller
from service.websocket import websocket_service

load_dotenv()
logger = logging.getLogger(__name__)


class MatchingService:
    def __init__(self):
        self.redis_controller = redis_controller
        self.websocket_service = websocket_service

    async def match_user(
        self,
        user_id: UUID,
        criteria: MatchingCriteriaSchema,
    ) -> UUID | None:
        logger.info(f"Added user {user_id} to queue with criteria {criteria}")
        self.redis_controller.add_to_queue(
            user_id=user_id,
            criteria=criteria
        )
        logger.info(f"{self.redis_controller.debug_show()}")
        # find eligible matches
        matched_user_id = self.redis_controller.find_match(user_id=user_id)
        if matched_user_id:
            matched_criteria = self.redis_controller.get_matched_criteria(
                user_id=user_id,
                matched_user_id=matched_user_id
            )
            logger.info(f"User {user_id} matched with user {matched_user_id}")
            await self.websocket_service.send_match_success(
                user_a=user_id,
                user_b=matched_user_id,
                criteria=matched_criteria
            )
            await self.websocket_service.close_ws_connection(user_id=user_id)
            await self.websocket_service.close_ws_connection(user_id=matched_user_id)
            logger.info(f"Removing user {user_id} from queue")
            self.redis_controller.remove_from_queue(user_id=user_id)
            logger.info(f"Removing user {matched_user_id} from queue")
            self.redis_controller.remove_from_queue(user_id=matched_user_id)
        logger.info(f"{self.redis_controller.debug_show()}")
        return matched_user_id

    def debug_show(self) -> dict:
        return self.redis_controller.debug_show()

    def clear_redis(self) -> None:
        self.redis_controller.clear_redis()
        return


matching_service = MatchingService()
