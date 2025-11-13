import logging
import os
from confluent_kafka.schema_registry import Schema
from ..kafka_client import kafka_client

logger = logging.getLogger(__name__)

def register_schemas(schema_dir: str = "kafka/schemas"):
    # List all .avsc files in the schema directory
    for filename in os.listdir(schema_dir):
        if not filename.endswith(".avsc"):
            continue

        file_path = os.path.join(schema_dir, filename)
        with open(file_path, "r") as f:
            schema_str = f.read()

        # Derive subject name, e.g. "session_created.avsc" → "session.created-value"
        base_name = os.path.splitext(filename)[0]
        subject = base_name.replace("_", ".") + "-value"

        schema = Schema(schema_str, "AVRO")

        try:
            registered = kafka_client.schema_registry_client.register_schema(subject, schema)
            logger.info(f"Registered schema '{subject}' with ID {registered}")
        except Exception as e:
            logger.error(f"Failed to register schema '{subject}': {e}")

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    register_schemas()
