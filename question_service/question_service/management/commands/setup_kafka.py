from django.core.management.base import BaseCommand
from question_service.kafka.publisher import topics_difficulties_publisher
from question_service.kafka.scripts.register_schemas import register_schemas


class Command(BaseCommand):
    help = 'Publish initial topics and difficulties data to Kafka and register schemas'

    def add_arguments(self, parser):
        parser.add_argument(
            '--register-schemas-only',
            action='store_true',
            help='Only register schemas, do not publish data',
        )
        parser.add_argument(
            '--publish-only',
            action='store_true',
            help='Only publish data, do not register schemas',
        )

    def handle(self, *args, **options):
        if not options['publish_only']:
            self.stdout.write('Registering Kafka schemas...')
            try:
                register_schemas()
                self.stdout.write(
                    self.style.SUCCESS('Successfully registered schemas')
                )
            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(f'Failed to register schemas: {e}')
                )
                return

        if not options['register_schemas_only']:
            self.stdout.write('Publishing initial topics and difficulties data...')
            try:
                topics_difficulties_publisher.publish_initial_data()
                self.stdout.write(
                    self.style.SUCCESS('Successfully published initial data')
                )
            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(f'Failed to publish initial data: {e}')
                )
                return

        self.stdout.write(
            self.style.SUCCESS('Kafka setup completed successfully')
        )

