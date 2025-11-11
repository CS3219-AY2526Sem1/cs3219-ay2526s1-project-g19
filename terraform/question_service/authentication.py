from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework.authentication import SessionAuthentication


class LenientSessionAuthentication(SessionAuthentication):
    """
    Session authentication that gracefully ignores malformed session payloads.

    Browsers may forward Django session cookies issued by other services
    (e.g. ones that store UUID user IDs). The default SessionAuthentication
    tries to coerce the stored `_auth_user_id` into an int, which raises a
    ValidationError before the request reaches our view. We treat those
    failures as “no session” instead of returning 500.
    """

    def authenticate(self, request):
        try:
            user = getattr(request._request, "user", None)
        except (ValueError, DjangoValidationError):
            return None

        if not user or not user.is_active:
            return None

        self.enforce_csrf(request)
        return (user, None)
