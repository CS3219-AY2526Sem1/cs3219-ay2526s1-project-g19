from django.apps import AppConfig


class EmailVerificationConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'email_verification'

    def ready(self):
        """Import signals when app is ready."""
        import email_verification.signals
