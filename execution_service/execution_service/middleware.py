"""
Middleware to handle proxy headers for Django services behind nginx
"""


class ForwardedPrefixMiddleware:
    """
    Middleware to handle X-Forwarded-Prefix header from nginx proxy.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        forwarded_prefix = request.META.get('HTTP_X_FORWARDED_PREFIX', '')
        if forwarded_prefix:
            request.META['SCRIPT_NAME'] = forwarded_prefix
            request.path_info = request.META.get('PATH_INFO', request.path)

        response = self.get_response(request)

        if forwarded_prefix and 'Location' in response:
            from urllib.parse import urlparse, parse_qs, urlencode, urlunparse
            location = response['Location']
            if location.startswith('/') and not location.startswith(forwarded_prefix):
                parsed = urlparse(location)
                new_path = forwarded_prefix + parsed.path
                if parsed.query:
                    query_params = parse_qs(parsed.query)
                    for key, values in query_params.items():
                        if key in ['next', 'redirect', 'return_url', 'return_to']:
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
                new_location = urlunparse((
                    parsed.scheme, parsed.netloc, new_path,
                    parsed.params, new_query, parsed.fragment
                ))
                response['Location'] = new_location

        return response


class FixedPrefixMiddleware:
    """
    Strips a fixed prefix from incoming paths and rewrites redirect Location headers.
    """
    def __init__(self, get_response):
        self.get_response = get_response
        self.prefix = '/execution-service-api'.rstrip('/')

    def __call__(self, request):
        if request.path.startswith(self.prefix):
            request.path_info = request.path[len(self.prefix):] or '/'
            request.META['SCRIPT_NAME'] = self.prefix

        response = self.get_response(request)

        if 'Location' in response:
            from urllib.parse import urlparse, parse_qs, urlencode, urlunparse
            location = response['Location']
            if location.startswith('/') and not location.startswith(self.prefix):
                parsed = urlparse(location)
                new_path = self.prefix + parsed.path
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
                    parsed.scheme, parsed.netloc, new_path,
                    parsed.params, new_query, parsed.fragment
                ))
                response['Location'] = new_location

        return response


