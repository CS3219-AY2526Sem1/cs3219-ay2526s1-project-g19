"""
Custom allauth adapter to build proxy-aware email confirmation URLs.

Ensures the confirmation link uses the public base URL plus the
/user-service-api prefix so recipients see a working link.
"""
from allauth.account.adapter import DefaultAccountAdapter
from django.conf import settings
from django.urls import reverse


class ProxyAwareAccountAdapter(DefaultAccountAdapter):
    """Override email confirmation URL to respect proxy base URL/prefix."""

    def get_email_confirmation_url(self, request, emailconfirmation):
        # Built-in path (e.g., /accounts/confirm-email/<key>/)
        confirmation_path = reverse(
            "account_confirm_email",
            args=[emailconfirmation.key],
        )

        public_base_url = getattr(settings, "USER_SERVICE_PUBLIC_BASE_URL", None)

        if public_base_url:
            return f"{public_base_url.rstrip('/')}{confirmation_path}"

        if request is not None:
            return request.build_absolute_uri(confirmation_path)

        # Fall back to default behaviour (uses Sites framework)
        return super().get_email_confirmation_url(request, emailconfirmation)
