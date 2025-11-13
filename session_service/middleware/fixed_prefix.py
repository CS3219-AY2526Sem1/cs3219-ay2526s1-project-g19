from __future__ import annotations

from urllib.parse import parse_qs, urlencode, urlparse, urlunparse

from starlette.datastructures import MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send


class FixedPrefixMiddleware:
    """
    Strip a fixed prefix from incoming paths and rewrite redirect locations so
    the service can sit behind a reverse proxy that mounts it under a prefix.
    """

    def __init__(self, app: ASGIApp, prefix: str) -> None:
        self.app = app
        normalized = prefix or ""
        if normalized and not normalized.startswith("/"):
            normalized = "/" + normalized
        self.prefix = normalized.rstrip("/")

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        scope_to_use = scope
        if scope["type"] in {"http", "websocket"} and self.prefix:
            path = scope.get("path", "")
            raw_path = scope.get("raw_path", b"")
            if path.startswith(self.prefix):
                scope_to_use = dict(scope)
                trimmed_path = path[len(self.prefix) :] or "/"
                scope_to_use["path"] = trimmed_path
                if isinstance(raw_path, (bytes, bytearray)) and raw_path.startswith(
                    self.prefix.encode("utf-8")
                ):
                    scope_to_use["raw_path"] = raw_path[len(self.prefix) :] or b"/"
                scope_to_use["root_path"] = self.prefix

        async def wrapped_send(message: Message) -> None:
            if message["type"] == "http.response.start" and self.prefix:
                headers = MutableHeaders(scope=message)
                location = headers.get("location")
                if location and location.startswith("/") and not location.startswith(self.prefix):
                    rewritten = self._rewrite_location(location)
                    headers["location"] = rewritten
            await send(message)

        await self.app(scope_to_use, receive, wrapped_send)

    def _rewrite_location(self, location: str) -> str:
        parsed = urlparse(location)
        new_path = self.prefix + parsed.path
        if parsed.query:
            query_params = parse_qs(parsed.query, keep_blank_values=True)
            for key, values in query_params.items():
                if key in {"next", "redirect", "return_url", "return_to"}:
                    query_params[key] = [self._prefix_value(v) for v in values]
            new_query = urlencode(query_params, doseq=True)
        else:
            new_query = parsed.query

        return urlunparse(
            (
                parsed.scheme,
                parsed.netloc,
                new_path,
                parsed.params,
                new_query,
                parsed.fragment,
            )
        )

    def _prefix_value(self, value: str) -> str:
        if value.startswith("/") and not value.startswith(self.prefix):
            return f"{self.prefix}{value}"
        return value

