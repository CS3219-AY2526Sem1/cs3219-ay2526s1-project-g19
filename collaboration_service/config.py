from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Kafka variables
    topic_session_end: str
    schema_registry_url: str
    schema_registry_key: str
    schema_registry_secret: str
    kafka_bootstrap_servers: str
    sasl_username: str
    sasl_password: str
    
    # Server configuration
    log_level: str = "INFO"
    service_prefix: str = Field(
        default="/collaboration-service-api",
        validation_alias=AliasChoices("COLLABORATION_SERVICE_PREFIX", "SERVICE_PREFIX")
    )
    redis_url: str = "redis://localhost:6379"
    port: int = 8005
    
    # Timeouts and expiry
    expiry_time: int = 3600
    inactive_session_timeout: int = 300

    model_config = SettingsConfigDict(env_file=".env", extra='ignore')

settings = Settings()
