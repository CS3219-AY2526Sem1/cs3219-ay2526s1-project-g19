import time
from uuid import UUID
from question_service.kafka.kafka_client import kafka_client
from question_service.kafka.config import REQUEST_TOPIC
import logging
import random
from confluent_kafka import Producer, Consumer, KafkaError, Message
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import SerializationContext, MessageField
import json
from question_service.kafka.config import REQUEST_TOPIC, RESPONSE_TOPIC, \
    consumer_config, producer_admin_config, schema_registry_conf
from question_service.kafka.schemas.match_found import MatchFound
from django.db.models import F, Value, FloatField, Case, When, Q
from django.db.models.functions import Coalesce, Cast
from question_service.models import Question
from django.conf import settings

logger = logging.getLogger(__name__)

class MatchFoundConsumer:
    def __init__(self):
        self.topics = [REQUEST_TOPIC]
        with open("question_service/kafka/schemas/question_chosen.avsc") as f:
            question_chosen_schema = f.read()
        self.serializer = AvroSerializer(
            kafka_client.schema_registry_client,
            question_chosen_schema
        )

    def handle_match_found(self, msg: Message):
        key = msg.key().decode()
        payload = kafka_client.deserializer(msg.value())
        logger.info(f"Received match id {key}")
        logger.info(f"Received message: {payload}")
        match = MatchFound(**payload)
        logger.info(f"Match object: {match}")
        question = self.get_filtered_question(
            topic=match.topic,
            difficulty=match.difficulty
        )
        logger.info(question)
        logger.info(question.__dict__)

        value = self.question_to_avro(
            question,
            match_id=match.match_id,
            user_id_list=match.user_id_list,
            language=match.language
        )
        kafka_client.producer.produce(
            topic=RESPONSE_TOPIC,
            key=str(match.match_id),
            value=self.serializer(
                value,
                SerializationContext(RESPONSE_TOPIC, MessageField.VALUE)
            )
        )
        kafka_client.producer.flush()
        return

    def listen(self):
        kafka_client.consumer_listen(
            topic=REQUEST_TOPIC,
            handler=self.handle_match_found
        )
        return

    def get_filtered_question(self, topic, difficulty):
        # Base queryset
        qs = Question.objects.all().select_related("stats", "score")

        # Annotate sortable fields
        solved_float = Cast(F("stats__solved"), FloatField())
        attempts_float = Cast(F("stats__attempts"), FloatField())
        percentage_expr = Case(
            When(stats__attempts__gt=0, then=(solved_float * Value(100.0)) / attempts_float),
            default=Value(0.0),
            output_field=FloatField(),
        )
        qs = qs.annotate(
            popularity=Coalesce(F("stats__attempts"), Value(0)),
            percentage_solved_annot=percentage_expr,
        )

        # Filter by difficulty
        qs = qs.filter(difficulty=difficulty)

        # Filter by topic safely
        if isinstance(topic, str):
            topic = [topic]

        engine = settings.DATABASES['default']['ENGINE']
        if 'postgresql' in engine:
            from django.db.models import Q
            q = Q()
            for t in topic:
                q |= Q(topics__contains=[t])
            qs = qs.filter(q)
        else:
            # SQLite fallback: filter in Python
            qs = [q_obj for q_obj in qs if any(t in (q_obj.topics or []) for t in topic)]

        # Randomize and limit
        if isinstance(qs, list):
            if qs:
                return random.choice(qs)
            return None
        else:
            return qs.order_by("?").first()

    def question_to_avro(
        self,
        question: Question,
        match_id: UUID,
        user_id_list: list[UUID],
        language: str
    ) -> dict:
        return {
            "match_id": str(match_id),
            "user_id_list": [str(id) for id in user_id_list],
            "question_id": str(question.question_id),
            "title": question.title,
            "statement_md": question.statement_md,
            "assets": question.assets or [],
            "topics": question.topics,
            "difficulty": question.difficulty,
            "language": language,
            "company_tags": question.company_tags or [],
            "examples": [str(e) for e in question.examples] if question.examples else [],
            "constraints": [str(c) for c in question.constraints] if question.constraints else [],
            "timestamp": int(time.time() * 1000),
        }


match_found_consumer = MatchFoundConsumer()
