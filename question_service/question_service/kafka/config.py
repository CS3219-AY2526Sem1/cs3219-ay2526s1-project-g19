import os

schema_registry_conf = {
    "url": os.getenv("SCHEMA_REGISTRY_URL"),
    # "basic.auth.user.info": f"{os.getenv('SCHEMA_REGISTRY_KEY')}:{os.getenv('SCHEMA_REGISTRY_SECRET')}"
}
producer_admin_config = {
    "bootstrap.servers": os.getenv("KAFKA_BOOTSTRAP_SERVERS"),
    "security.protocol": "PLAINTEXT",
    # "sasl.username": os.getenv("SASL_USERNAME"),
    # "sasl.password": os.getenv("SASL_PASSWORD"),
    # "security.protocol": "SASL_SSL",
    # "sasl.mechanisms": "PLAIN"
}
consumer_config = {
    'bootstrap.servers': os.getenv("KAFKA_BOOTSTRAP_SERVERS"),
    'group.id': os.getenv("QUESTION_GROUP_ID", "question-service-group"),
    'session.timeout.ms': 6000,
    'auto.offset.reset': 'latest',  # Process only new messages
    "security.protocol": "PLAINTEXT",
    # "security.protocol": "SASL_SSL",
    # 'sasl.mechanisms': 'PLAIN',
    # "sasl.username": os.getenv("SASL_USERNAME"),
    # "sasl.password": os.getenv("SASL_PASSWORD")
}

REQUEST_TOPIC = os.getenv("TOPIC_MATCH_FOUND", "match.found")
RESPONSE_TOPIC = os.getenv("TOPIC_QUESTION_CHOSEN", "question.chosen")
TOPICS_UPDATED_TOPIC = os.getenv("TOPIC_TOPICS_UPDATED", "topics.updated")
DIFFICULTIES_UPDATED_TOPIC = os.getenv("TOPIC_DIFFICULTIES_UPDATED", "difficulties.updated")
