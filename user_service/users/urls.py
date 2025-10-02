"""
Users app URL configuration.

Handles all user profile and data-related endpoints including:
- Profile management
- User statistics
- Account operations
"""
from django.urls import path

app_name = 'users'

urlpatterns = [
    # Future user profile endpoints:
    # path('me/', UserMeView.as_view(), name='me'),
    # path('profile/', UserProfileUpdateView.as_view(), name='profile-update'),
    # path('me/', UserDeleteView.as_view(), name='delete-account'),

    # Future user statistics endpoints:
    # path('attempts/summary/', UserAttemptsView.as_view(), name='attempts-summary'),
    # path('collaborationsessions/', CollaborationSessionsView.as_view(), name='collaboration-sessions'),
    # path('proficiency/', UserProficiencyView.as_view(), name='proficiency'),
]