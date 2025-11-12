import logging
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from question_service.models import Question
from question_service.kafka.publisher import topics_difficulties_publisher

logger = logging.getLogger(__name__)


@receiver(post_save, sender=Question)
def question_saved(sender, instance, created, **kwargs):
    """Publish topics update when a question is saved."""
    try:
        # Get all current topics from active questions
        topics_query = Question.objects.filter(status='active').values_list('topics', flat=True)
        topics_set = set()
        for topics_list in topics_query:
            if topics_list:  # Handle None/empty values
                topics_set.update(topics_list)
        topics_list = sorted(list(topics_set))
        
        # Publish the updated topics list
        topics_difficulties_publisher.publish_topics_update(topics_list)
        
        logger.info(f"Published topics update after question {'created' if created else 'updated'}: {instance.title}")
        
    except Exception as e:
        logger.error(f"Failed to publish topics update after question save: {e}")


@receiver(post_delete, sender=Question)
def question_deleted(sender, instance, **kwargs):
    """Publish topics update when a question is deleted."""
    try:
        # Get all current topics from active questions
        topics_query = Question.objects.filter(status='active').values_list('topics', flat=True)
        topics_set = set()
        for topics_list in topics_query:
            if topics_list:  # Handle None/empty values
                topics_set.update(topics_list)
        topics_list = sorted(list(topics_set))
        
        # Publish the updated topics list
        topics_difficulties_publisher.publish_topics_update(topics_list)
        
        logger.info(f"Published topics update after question deleted: {instance.title}")
        
    except Exception as e:
        logger.error(f"Failed to publish topics update after question deletion: {e}")

