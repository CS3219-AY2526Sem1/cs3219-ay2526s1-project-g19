# question_service/question_service/view.py
from django.db.models import F, Q, Value
from django.db.models.functions import Coalesce
from rest_framework import viewsets, mixins
from rest_framework.pagination import PageNumberPagination
from django_filters.rest_framework import DjangoFilterBackend, FilterSet, CharFilter, ChoiceFilter, NumberFilter
from .models import Question, Difficulty
from .serializer import QuestionListSerializer, QuestionDetailSerializer

class QuestionPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100

class QuestionFilter(FilterSet):
    topic = CharFilter(method="filter_topic")
    difficulty = ChoiceFilter(choices=Difficulty.choices)
    popularity_min = NumberFilter(method="filter_popularity_min")
    solved_by_user = CharFilter(method="filter_solved_by_user")  # placeholder hook

    def filter_topic(self, qs, name, value):
        values = self.request.query_params.getlist("topic") or [value]
        q = Q()
        for v in values:
            q |= Q(topics__icontains=v)  # JSON contains; swap for ArrayField with overlap if you change type
        return qs.filter(q)

    def filter_popularity_min(self, qs, name, value):
        return qs.filter(stats__attempts__gte=value)

    def filter_solved_by_user(self, qs, name, value):
        # TODO: join to your user progress model if/when available
        return qs

    class Meta:
        model = Question
        fields = ["difficulty"]

class QuestionViewSet(mixins.ListModelMixin,
                      mixins.RetrieveModelMixin,
                      viewsets.GenericViewSet):
    queryset = (Question.objects.all().filter(is_active=True).select_related("stats","score"))
    pagination_class = QuestionPagination
    filter_backends = [DjangoFilterBackend]
    filterset_class = QuestionFilter

    def get_serializer_class(self):
        return QuestionDetailSerializer if self.action == "retrieve" else QuestionListSerializer

    def get_queryset(self):
        # annotate sortable fields
        return (super().get_queryset()
                .annotate(
                    popularity=Coalesce(F("stats__attempts"), Value(0)),
                    percentage_solved_annot=Coalesce(
                        (F("stats__solved") * 100.0) / Coalesce(F("stats__attempts"), Value(0.0)),
                        Value(0.0),
                    )
                ))

    def list(self, request, *args, **kwargs):
        qs = self.filter_queryset(self.get_queryset())

        # sorting
        sort = request.query_params.get("sort", "newest")
        order = request.query_params.get("order", "desc")
        prefix = "-" if order == "desc" else ""
        sort_map = {
            "newest": f"{prefix}created_at",
            "difficulty": f"{prefix}difficulty",
            "percentage_solved": f"{prefix}percentage_solved_annot",
            "popularity": f"{prefix}popularity",
            "topic": f"{prefix}title",
        }
        qs = qs.order_by(sort_map.get(sort, f"-created_at"))

        # sparse fieldsets (?fields=title,topics,...)
        fields_param = request.query_params.get("fields")
        serializer_kwargs = {}
        if fields_param and self.action == "list":
            serializer_kwargs["fields"] = [f.strip() for f in fields_param.split(",") if f.strip()]

        page = self.paginate_queryset(qs)
        serializer = self.get_serializer(page, many=True, **serializer_kwargs)
        return self.get_paginated_response(serializer.data)
