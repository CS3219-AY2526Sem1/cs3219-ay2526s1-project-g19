from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    environment: str = "production"
    session_db_host: str
    session_db_port: int
    session_db_name: str
    session_db_user: str
    session_db_password: str
    session_db_ssl_mode: str = "require"

    # Kafka variables
    session_group_id: str = Field(alias="SESSION_GROUP_ID")
    topic_question_chosen: str
    topic_session_created: str
    topic_session_end: str
    schema_registry_url: str
    schema_registry_key: str
    schema_registry_secret: str
    kafka_bootstrap_servers: str
    sasl_username: str
    sasl_password: str

    # jwt decode
    secret_key: str

    def _build_pg_url(self, driver: str, query_param: str | None) -> str:
        url = (
            f"postgresql+{driver}://{self.session_db_user}:"
            f"{self.session_db_password}@{self.session_db_host}:"
            f"{self.session_db_port}/{self.session_db_name}"
        )
        if query_param:
            return f"{url}?{query_param}"
        return url

    def _ssl_query(self) -> str | None:
        mode = (self.session_db_ssl_mode or "").strip()
        if not mode:
            return None
        return f"sslmode={mode}"

    @property
    def pg_url(self) -> str:
        return self._build_pg_url("asyncpg", self._ssl_query())

    @property
    def pg_sync_url(self) -> str:
        return self._build_pg_url("psycopg2", self._ssl_query())


settings = Settings()
