"""
URL configuration for execution service apps.
"""
from django.urls import path
from .views import ExecuteView, ExecuteTestsView, LanguagesView

urlpatterns = [
    path('execute', ExecuteView.as_view(), name='execute'),
    path('execute/tests', ExecuteTestsView.as_view(), name='execute-tests'),
    path('languages', LanguagesView.as_view(), name='languages'),
]


