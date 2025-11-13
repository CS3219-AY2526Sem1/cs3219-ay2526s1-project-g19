import logging
from django.core.management.base import BaseCommand
from question_service.kafka.consumers.match_found_consumer import match_found_consumer

logger = logging.getLogger(__name__)

class Command(BaseCommand):
    help = "Runs Kafka consumer for question service"

    def handle(self, *args, **options):
        match_found_consumer.listen()
