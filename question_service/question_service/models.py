# question_service/question_service/model.py
import uuid
from django.db import models
from django.contrib.postgres.indexes import GinIndex
from django.contrib.postgres.search import SearchVectorField

class Difficulty(models.TextChoices):
    EASY = "easy", "easy"
    MEDIUM = "medium", "medium"
    HARD = "hard", "hard"

class Question(models.Model):
    question_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    slug = models.SlugField(unique=True)
    title = models.TextField()
    statement_md = models.TextField()
    assets = models.JSONField(default=list)
    difficulty = models.CharField(max_length=10, choices=Difficulty.choices)
    # NOTE: using JSON for simplicity; switch to ArrayField if you prefer TEXT[]
    topics = models.JSONField(default=list)         # e.g. ["arrays","graphs"]
    company_tags = models.JSONField(default=list)   # e.g. ["google","meta"]
    is_active = models.BooleanField(default=True)
    created_by = models.UUIDField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    search_tsv = SearchVectorField(null=True, blank=True)

    class Meta:
        db_table = "question_stats"
        indexes = [GinIndex(fields=["search_tsv"])]

    def __str__(self):
        return self.title

class QuestionStats(models.Model):
    question = models.OneToOneField(Question, on_delete=models.CASCADE, related_name="stats", primary_key=True)
    views = models.BigIntegerField(default=0)
    attempts = models.BigIntegerField(default=0)
    solved = models.BigIntegerField(default=0)
    last_activity_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "questions"

    @property
    def percentage_solved(self) -> float:
        return (float(self.solved) / float(self.attempts) * 100.0) if self.attempts > 0 else 0.0

class QuestionSolution(models.Model):
    solution_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    question = models.ForeignKey(Question, on_delete=models.CASCADE, related_name="solutions")
    language = models.TextField()
    solution_md = models.TextField()
    author = models.UUIDField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "question_solutions"
        constraints = [models.UniqueConstraint(fields=["question", "language"], name="uq_question_language")]

class QuestionScore(models.Model):
    question = models.OneToOneField(Question, on_delete=models.CASCADE, related_name="score", primary_key=True)
    attainable_score = models.IntegerField()
    model_version = models.TextField()
    computed_at = models.DateTimeField()

    class Meta:
        db_table = "question_scores"
