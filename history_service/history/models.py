import uuid
from django.db import models
from django.utils import timezone


class History(models.Model):
    """
    Model representing a coding session history between two users.
    """
    history_id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    user_id = models.UUIDField()
    collaborator_id = models.UUIDField()
    session_id = models.UUIDField()
    question_id = models.UUIDField()
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        verbose_name_plural = "histories"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user_id']),
            models.Index(fields=['collaborator_id']),
            models.Index(fields=['question_id']),
            models.Index(fields=['created_at']),
        ]

    def __str__(self):
        return f"Session {self.session_id} between {self.user_id} and {self.collaborator_id}"
