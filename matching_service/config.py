from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    environment: str = "production"
    redis_host: str = Field(alias="MATCHING_REDIS_HOST")
    redis_port: str = Field(alias="MATCHING_REDIS_PORT")

    # Kafka
    matching_group_id: str = Field(alias="MATCHING_GROUP_ID")
    kafka_bootstrap_servers: str
    topic_match_found: str
    topic_session_created: str
    topic_topics_updated: str
    topic_difficulties_updated: str
    schema_registry_url: str
    schema_registry_key: str
    schema_registry_secret: str
    sasl_username: str
    sasl_password: str

    # jwt decryption
    secret_key: str


settings = Settings()
