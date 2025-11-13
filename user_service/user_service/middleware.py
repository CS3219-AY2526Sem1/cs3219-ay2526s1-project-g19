"""
Middleware to handle proxy headers for Django services behind nginx
"""


class ForwardedPrefixMiddleware:
    """
    Middleware to handle X-Forwarded-Prefix header from nginx proxy.

    When nginx proxies requests like:
      Browser: /user-service-api/admin/ → Backend: /admin/

    Django needs to know about the /user-service-api prefix for redirects.
    This middleware sets SCRIPT_NAME based on X-Forwarded-Prefix header.

    Usage:
        Add to MIDDLEWARE in settings.py (near the top, after SecurityMiddleware):
        'user_service.middleware.ForwardedPrefixMiddleware',
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Get the prefix from the X-Forwarded-Prefix header
        forwarded_prefix = request.META.get('HTTP_X_FORWARDED_PREFIX', '')

        if forwarded_prefix:
            # Set SCRIPT_NAME so Django prepends this to all URL generation
            # This must be set in request.META for Django's URL resolvers to use it
            request.META['SCRIPT_NAME'] = forwarded_prefix
            # Also set path_info to remove the prefix from the path if it exists
            # (nginx already strips it with rewrite, but this ensures consistency)
            request.path_info = request.META.get('PATH_INFO', request.path)

        response = self.get_response(request)

        # Fix Location header in redirects
        if forwarded_prefix and 'Location' in response:
            from urllib.parse import urlparse, parse_qs, urlencode, urlunparse

            location = response['Location']

            # If location is a relative path (starts with /), prepend the prefix
            if location.startswith('/') and not location.startswith(forwarded_prefix):
                # Parse the URL to handle query parameters
                parsed = urlparse(location)

                # Fix the path
                new_path = forwarded_prefix + parsed.path

                # Fix query parameters (like ?next=/admin/ should become ?next=/user-service-api/admin/)
                if parsed.query:
                    query_params = parse_qs(parsed.query)
                    for key, values in query_params.items():
                        if key in ['next', 'redirect', 'return_url', 'return_to']:
                            # Fix redirect URLs in query params
                            fixed_values = []
                            for value in values:
                                if value.startswith('/') and not value.startswith(forwarded_prefix):
                                    fixed_values.append(forwarded_prefix + value)
                                else:
                                    fixed_values.append(value)
                            query_params[key] = fixed_values

                    new_query = urlencode(query_params, doseq=True)
                else:
                    new_query = parsed.query

                # Reconstruct the URL
                new_location = urlunparse((
                    parsed.scheme,
                    parsed.netloc,
                    new_path,
                    parsed.params,
                    new_query,
                    parsed.fragment
                ))

                response['Location'] = new_location

        return response

"""
Middleware to strip a fixed prefix from incoming requests
and fix redirect Location headers accordingly.
"""

from urllib.parse import urlparse, parse_qs, urlencode, urlunparse

class FixedPrefixMiddleware:
    """
    Strips a fixed prefix from incoming paths and rewrites
    redirect Location headers so Django works behind a prefix.

    Example:
      /question-service-api/admin/ -> /admin/
    """

    def __init__(self, get_response):
        self.get_response = get_response
        self.prefix = '/user-service-api'.rstrip('/')

    def __call__(self, request):
        if request.path.startswith(self.prefix):
            request.path_info = request.path[len(self.prefix):] or '/'
            request.META['SCRIPT_NAME'] = self.prefix

        response = self.get_response(request)

        # Fix redirect Location headers
        if 'Location' in response:
            location = response['Location']

            if location.startswith('/') and not location.startswith(self.prefix):
                parsed = urlparse(location)
                new_path = self.prefix + parsed.path

                # Fix query parameters for next/redirect URLs
                if parsed.query:
                    query_params = parse_qs(parsed.query)
                    for key, values in query_params.items():
                        if key in ['next', 'redirect', 'return_url', 'return_to']:
                            fixed_values = [
                                self.prefix + v if v.startswith('/') and not v.startswith(self.prefix) else v
                                for v in values
                            ]
                            query_params[key] = fixed_values
                    new_query = urlencode(query_params, doseq=True)
                else:
                    new_query = parsed.query

                new_location = urlunparse((
                    parsed.scheme,
                    parsed.netloc,
                    new_path,
                    parsed.params,
                    new_query,
                    parsed.fragment
                ))

                response['Location'] = new_location

        return response
