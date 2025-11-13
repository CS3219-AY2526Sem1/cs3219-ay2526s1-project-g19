# question_service/question_service/admin.py
from django.contrib import admin
from django.utils.html import format_html
from django.urls import reverse
from django.utils.safestring import mark_safe
from .models import Question, QuestionStats, QuestionScore, QuestionSolution


@admin.register(Question)
class QuestionAdmin(admin.ModelAdmin):
    list_display = [
        'title', 'difficulty', 'is_active', 'topics_display', 
        'company_tags_display', 'created_at', 'updated_at'
    ]
    list_filter = ['difficulty', 'is_active', 'created_at', 'topics']
    search_fields = ['title', 'slug', 'statement_md']
    list_editable = ['is_active']
    readonly_fields = ['question_id', 'created_at', 'updated_at', 'stats_link', 'score_link']
    list_per_page = 25
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('question_id', 'slug', 'title', 'statement_md')
        }),
        ('Classification', {
            'fields': ('difficulty', 'topics', 'company_tags', 'is_active')
        }),
        ('Examples & Constraints', {
            'fields': ('examples', 'constraints'),
            'classes': ('collapse',)
        }),
        ('Media & Assets', {
            'fields': ('assets',),
            'classes': ('collapse',)
        }),
        ('Metadata', {
            'fields': ('created_by', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
        ('Related Objects', {
            'fields': ('stats_link', 'score_link'),
            'classes': ('collapse',)
        }),
    )
    
    actions = ['activate_questions', 'deactivate_questions', 'duplicate_questions']
    
    def topics_display(self, obj):
        """Display topics as a comma-separated string."""
        if obj.topics:
            return ', '.join(obj.topics[:3]) + ('...' if len(obj.topics) > 3 else '')
        return '-'
    topics_display.short_description = 'Topics'
    
    def company_tags_display(self, obj):
        """Display company tags as a comma-separated string."""
        if obj.company_tags:
            return ', '.join(obj.company_tags[:2]) + ('...' if len(obj.company_tags) > 2 else '')
        return '-'
    company_tags_display.short_description = 'Company Tags'
    
    def stats_link(self, obj):
        """Link to question stats."""
        if hasattr(obj, 'stats'):
            url = reverse('admin:question_service_questionstats_change', args=[obj.stats.pk])
            return format_html('<a href="{}">View Stats</a>', url)
        return 'No stats'
    stats_link.short_description = 'Stats'
    
    def score_link(self, obj):
        """Link to question score."""
        if hasattr(obj, 'score'):
            url = reverse('admin:question_service_questionscore_change', args=[obj.score.pk])
            return format_html('<a href="{}">View Score</a>', url)
        return 'No score'
    score_link.short_description = 'Score'
    
    def activate_questions(self, request, queryset):
        """Activate selected questions."""
        updated = queryset.update(is_active=True)
        self.message_user(request, f'{updated} questions activated.')
    activate_questions.short_description = 'Activate selected questions'
    
    def deactivate_questions(self, request, queryset):
        """Deactivate selected questions."""
        updated = queryset.update(is_active=False)
        self.message_user(request, f'{updated} questions deactivated.')
    deactivate_questions.short_description = 'Deactivate selected questions'
    
    def duplicate_questions(self, request, queryset):
        """Duplicate selected questions with new slugs."""
        duplicated = 0
        for question in queryset:
            question.pk = None
            question.slug = f"{question.slug}-copy-{duplicated}"
            question.title = f"{question.title} (Copy)"
            question.save()
            duplicated += 1
        self.message_user(request, f'{duplicated} questions duplicated.')
    duplicate_questions.short_description = 'Duplicate selected questions'


@admin.register(QuestionStats)
class QuestionStatsAdmin(admin.ModelAdmin):
    list_display = [
        'question_title', 'views', 'attempts', 'solved', 
        'percentage_solved', 'last_activity_at'
    ]
    readonly_fields = ['percentage_solved']
    list_filter = ['last_activity_at', 'views', 'attempts']
    search_fields = ['question__title', 'question__slug']
    list_per_page = 25
    
    def question_title(self, obj):
        """Display question title with link."""
        url = reverse('admin:question_service_question_change', args=[obj.question.pk])
        return format_html('<a href="{}">{}</a>', url, obj.question.title)
    question_title.short_description = 'Question'
    question_title.admin_order_field = 'question__title'


@admin.register(QuestionScore)
class QuestionScoreAdmin(admin.ModelAdmin):
    list_display = [
        'question_title', 'attainable_score', 'model_version', 'computed_at'
    ]
    list_filter = ['model_version', 'computed_at', 'attainable_score']
    search_fields = ['question__title', 'question__slug']
    list_per_page = 25
    
    def question_title(self, obj):
        """Display question title with link."""
        url = reverse('admin:question_service_question_change', args=[obj.question.pk])
        return format_html('<a href="{}">{}</a>', url, obj.question.title)
    question_title.short_description = 'Question'
    question_title.admin_order_field = 'question__title'


@admin.register(QuestionSolution)
class QuestionSolutionAdmin(admin.ModelAdmin):
    list_display = [
        'question_title', 'language', 'author', 'created_at'
    ]
    list_filter = ['language', 'created_at']
    search_fields = ['question__title', 'language', 'author']
    list_per_page = 25
    
    def question_title(self, obj):
        """Display question title with link."""
        url = reverse('admin:question_service_question_change', args=[obj.question.pk])
        return format_html('<a href="{}">{}</a>', url, obj.question.title)
    question_title.short_description = 'Question'
    question_title.admin_order_field = 'question__title'


# Customize admin site header and title
admin.site.site_header = "Question Service Administration"
admin.site.site_title = "Question Service Admin"
admin.site.index_title = "Welcome to Question Service Administration"
