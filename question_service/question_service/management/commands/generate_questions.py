import random
import uuid
from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils.timezone import now
from question_service.models import Question, QuestionStats, QuestionScore, Difficulty


class Command(BaseCommand):
    help = "Generate sample questions with stats and scores for testing filters"

    def add_arguments(self, parser):
        parser.add_argument("count", type=int, nargs="?", default=50, help="Number of questions to create")
        parser.add_argument("--category", dest="category", default=None, help="Force include this topic in all questions")
        parser.add_argument("--difficulty", dest="difficulty", default=None, choices=[d[0] for d in Difficulty.choices], help="Force difficulty for all questions")
        parser.add_argument("--active", dest="active", action="store_true", help="Force is_active=True")

    def handle(self, *args, **options):
        count = options["count"]
        forced_topic = options.get("category")
        forced_difficulty = options.get("difficulty")
        force_active = options.get("active")

        topics_pool = ["technology","arrays","graphs","dp","math","strings","stack","tree","greedy"]
        companies_pool = ["google","meta","apple","amazon","microsoft","netflix"]
        difficulties = [Difficulty.EASY, Difficulty.MEDIUM, Difficulty.HARD]

        created = 0
        for i in range(count):
            slug = f"sample-q-{i}-{uuid.uuid4().hex[:6]}"
            topics = random.sample(topics_pool, k=random.randint(1, 3))
            if forced_topic and forced_topic not in topics:
                topics[0:0] = [forced_topic]

            difficulty = forced_difficulty or random.choice(difficulties)
            is_active = True if force_active else random.choice([True, True, True, False])

            q = Question.objects.create(
                slug=slug,
                title=f"Sample Question {i}",
                statement_md="Sample statement...",
                assets=[],
                difficulty=difficulty,
                topics=topics,
                company_tags=random.sample(companies_pool, k=random.randint(0, 2)),
                is_active=is_active,
                created_by=uuid.uuid4(),
                created_at=now() - timedelta(days=random.randint(0, 120)),
                updated_at=now(),
            )

            attempts = random.randint(0, 200)
            solved = random.randint(0, attempts) if attempts > 0 else 0
            QuestionStats.objects.create(
                question=q,
                views=random.randint(0, 500),
                attempts=attempts,
                solved=solved,
                last_activity_at=now() - timedelta(days=random.randint(0, 60)),
            )
            QuestionScore.objects.create(
                question=q,
                attainable_score=random.choice([50, 100]),
                model_version="v1",
                computed_at=now(),
            )

            created += 1

        self.stdout.write(self.style.SUCCESS(f"Created {created} questions"))


