import os
from django.core.management.base import BaseCommand
from django.core.management import call_command
from question_service.models import Question


class Command(BaseCommand):
    help = "Initialize database with mock data if empty"

    def add_arguments(self, parser):
        parser.add_argument(
            '--force',
            action='store_true',
            help='Force load data even if database is not empty'
        )
        parser.add_argument(
            '--fixture',
            type=str,
            default='fixtures/mock_1042_9_oct.json',
            help='Path to fixture file (default: fixtures/mock_1042_9_oct.json)'
        )

    def handle(self, **options):
        force = options.get('force', False)
        fixture_path = options.get('fixture')

        # Check if database has any questions
        question_count = Question.objects.count()

        if question_count > 0 and not force:
            self.stdout.write(
                self.style.WARNING(
                    f"Database already contains {question_count} questions. "
                    "Skipping data initialization. Use --force to load anyway."
                )
            )
            return

        # Check if fixture file exists
        if not os.path.exists(fixture_path):
            self.stdout.write(
                self.style.ERROR(
                    f"Fixture file not found: {fixture_path}"
                )
            )
            return

        # Load the fixture
        self.stdout.write(
            self.style.SUCCESS(
                f"Loading initial data from {fixture_path}..."
            )
        )

        try:
            call_command('loaddata', fixture_path, verbosity=1)

            # Verify the data was loaded
            new_count = Question.objects.count()
            self.stdout.write(
                self.style.SUCCESS(
                    f"Successfully loaded data! Database now contains {new_count} questions."
                )
            )
        except Exception as e:
            self.stdout.write(
                self.style.ERROR(
                    f"Failed to load fixture: {str(e)}"
                )
            )
            raise
