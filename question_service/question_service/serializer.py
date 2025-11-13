# question_service/question_service/serializer.py
from rest_framework import serializers
from .models import Question, QuestionStats, QuestionScore

class QuestionStatsSerializer(serializers.ModelSerializer):
    percentage_solved = serializers.FloatField(read_only=True)

    class Meta:
        model = QuestionStats
        fields = ["views", "attempts", "solved", "last_activity_at", "percentage_solved"]

class QuestionScoreSerializer(serializers.ModelSerializer):
    class Meta:
        model = QuestionScore
        fields = ["attainable_score", "model_version", "computed_at"]

class QuestionSerializer(serializers.ModelSerializer):
    stats = QuestionStatsSerializer(read_only=True)
    score = QuestionScoreSerializer(read_only=True)
    question_id = serializers.UUIDField(read_only=True)
    created_at = serializers.DateTimeField(read_only=True)
    updated_at = serializers.DateTimeField(read_only=True)

    class Meta:
        model = Question
        fields = [
            "question_id","slug","title","statement_md","assets",
            "difficulty","topics","company_tags","is_active",
            "created_by","created_at","updated_at","stats","score",
            "examples","constraints"
        ]
        read_only_fields = ["question_id", "created_at", "updated_at", "stats", "score"]
