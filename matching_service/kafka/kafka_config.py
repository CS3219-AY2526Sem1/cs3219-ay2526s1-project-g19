from config import settings

schema_registry_conf = {
    "url": settings.schema_registry_url,
    # "basic.auth.user.info": f"{settings.schema_registry_key}:{settings.schema_registry_secret}"
}
producer_config = {
    "bootstrap.servers": settings.kafka_bootstrap_servers,
    "security.protocol": "PLAINTEXT",
    # "sasl.username": settings.sasl_username,
    # "sasl.password": settings.sasl_password,
    # "security.protocol": "SASL_SSL",
    # "sasl.mechanisms": "PLAIN"
}
consumer_config = {
    "bootstrap.servers": settings.kafka_bootstrap_servers,
    'group.id': settings.matching_group_id,
    'session.timeout.ms': 6000,
    "security.protocol": "PLAINTEXT",
    'auto.offset.reset': 'latest',  # Process only new messages
    # "security.protocol": "SASL_SSL",
    # 'sasl.mechanisms': 'PLAIN',
    # "sasl.username": settings.sasl_username,
    # "sasl.password": settings.sasl_password,
    }
