"""
Signal handlers to sync User.is_verified with allauth's EmailAddress model.

This module ensures two-way synchronization:
1. When allauth marks an email as verified -> update User.is_verified = True
2. When User.is_verified changes -> sync to allauth's EmailAddress.verified
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from allauth.account.signals import email_confirmed
from allauth.account.models import EmailAddress
from users.models import User


@receiver(email_confirmed)
def email_confirmed_handler(sender, request, email_address, **kwargs):  # pylint: disable=unused-argument
    """
    When allauth confirms an email, mark User.is_verified as True.

    This signal is triggered when a user clicks the verification link.
    """
    try:
        user = email_address.user
        if not user.is_verified:
            user.is_verified = True
            user.save(update_fields=['is_verified'])
    except Exception as e:
        # Log error but don't break the verification flow
        print(f"Error syncing email verification to User model: {e}")


@receiver(post_save, sender=User)
def sync_user_verified_to_allauth(sender, instance, created, **kwargs):  # pylint: disable=unused-argument
    """
    When User.is_verified changes, sync to allauth's EmailAddress model.

    This ensures consistency when is_verified is updated manually
    (e.g., admin panel, custom verification logic).
    """
    if created:
        # Create EmailAddress entry for new users
        EmailAddress.objects.get_or_create(
            user=instance,
            email=instance.email,
            defaults={
                'verified': instance.is_verified,
                'primary': True,
            }
        )
    else:
        # Update existing EmailAddress entries
        try:
            email_address = EmailAddress.objects.get(
                user=instance,
                email=instance.email
            )
            if email_address.verified != instance.is_verified:
                email_address.verified = instance.is_verified
                email_address.save(update_fields=['verified'])
        except EmailAddress.DoesNotExist:
            # Create if doesn't exist
            EmailAddress.objects.create(
                user=instance,
                email=instance.email,
                verified=instance.is_verified,
                primary=True,
            )
        except Exception as e:
            # Log error but don't break user save
            print(f"Error syncing User.is_verified to allauth EmailAddress: {e}")
