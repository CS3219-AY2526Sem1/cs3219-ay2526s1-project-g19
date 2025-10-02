# question_service/question_service/serializer.py
from rest_framework import serializers
from .models import Question, QuestionStats, QuestionScore

class DynamicFieldsModelSerializer(serializers.ModelSerializer):
    def __init__(self, *args, **kwargs):
        fields = kwargs.pop("fields", None)
        super().__init__(*args, **kwargs)
        if fields is not None:
            allowed = set(fields)
            for name in set(self.fields) - allowed:
                self.fields.pop(name)

class QuestionStatsSerializer(serializers.ModelSerializer):
    percentage_solved = serializers.FloatField(read_only=True)

    class Meta:
        model = QuestionStats
        fields = ["views", "attempts", "solved", "last_activity_at", "percentage_solved"]

class QuestionScoreSerializer(serializers.ModelSerializer):
    class Meta:
        model = QuestionScore
        fields = ["attainable_score", "model_version", "computed_at"]

class QuestionListSerializer(DynamicFieldsModelSerializer):
    percentage_solved = serializers.SerializerMethodField()

    class Meta:
        model = Question
        fields = ["question_id", "slug", "title", "difficulty", "topics", "percentage_solved"]

    def get_percentage_solved(self, obj):
        return obj.stats.percentage_solved if getattr(obj, "stats", None) else 0.0

class QuestionDetailSerializer(serializers.ModelSerializer):
    stats = QuestionStatsSerializer(read_only=True)
    score = QuestionScoreSerializer(read_only=True)

    class Meta:
        model = Question
        fields = [
            "question_id","slug","title","statement_md","assets",
            "difficulty","topics","company_tags","is_active",
            "created_by","created_at","updated_at","stats","score"
        ]
