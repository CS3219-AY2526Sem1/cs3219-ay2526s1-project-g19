import json
import logging
from uuid import UUID
from fastapi import WebSocket
from fastapi.websockets import WebSocketState

from schemas.matching import MatchedCriteriaSchema, MatchingCriteriaSchema, MatchingEventMessage, MatchingStatus


logger = logging.getLogger(__name__)

class WebSocketService:
    def __init__(self):
        self.ws_connections: dict[UUID, WebSocket] = {}

        ## WebSocket stuff

    def record_ws_connection(
        self,
        user_id: UUID,
        websocket: WebSocket
    ) -> None:
        self.ws_connections[user_id] = websocket
        return

    def check_ws_connection(
        self,
        user_id: UUID
    ) -> bool:
        logger.info(f"Current websocket connections: {self.ws_connections}")
        return user_id in self.ws_connections

    async def close_ws_connection(
        self,
        user_id: UUID
    ) -> None:
        logger.info(f"Closing websocket of {user_id}")
        if user_id in self.ws_connections:
            ws = self.ws_connections[user_id]
            if ws.client_state == WebSocketState.CONNECTED:
                await ws.close()
            self.ws_connections.pop(user_id)
        return

    async def send_match_success(
        self,
        user_a: UUID,
        user_b: UUID,
        criteria: MatchedCriteriaSchema
    ) -> None:
        # send to user a
        message = MatchingEventMessage(
            status=MatchingStatus.SUCCESS,
            matched_user_id=user_b,
            criteria=criteria
        )
        if user_a in self.ws_connections:
            await self.ws_connections[user_a].send_json(json.loads(message.model_dump_json()))
        # send to user b
        message = MatchingEventMessage(
            status=MatchingStatus.SUCCESS,
            matched_user_id=user_a,
            criteria=criteria
        )
        if user_b in self.ws_connections:
            await self.ws_connections[user_b].send_json(json.loads(message.model_dump_json()))
        return


websocket_service = WebSocketService()
