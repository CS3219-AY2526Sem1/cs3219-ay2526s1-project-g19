from django.apps import AppConfig

class QuestionServiceConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "question_service"
    
    def ready(self):
        import question_service.admin
        # Import Kafka signal handlers only after apps are ready
        try:
            import question_service.kafka.signals  # noqa: F401
        except Exception:
            # Kafka may be disabled/not configured in some environments
            pass

