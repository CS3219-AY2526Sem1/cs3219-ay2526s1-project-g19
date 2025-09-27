cd user_service/

python3.10 manage.py startapp user

pip install djangorestframework
pip install djangorestframework-simplejwt  # For JWT authentication (optional)

# Add to INSTALLED_APPS in settings.py
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework', #rest!
    'user',  # Your new app
]

also
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.SessionAuthentication',
        'rest_framework.authentication.TokenAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20
}


# added also into requirements.txt
djangorestframework==3.15.2
djangorestframework-simplejwt==5.3.0
psycopg2-binary==2.9.9
python-decouple==3.8
Pillow==10.4.0
django-cors-headers==4.3.1
dj-database-url==2.1.0

# added sample to models.py to setup ORM
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.core.validators import EmailValidator
import uuid

class User(AbstractUser):
    """Custom User model extending AbstractUser"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(
        unique=True, 
        validators=[EmailValidator()],
        help_text='Required. Enter a valid email address.'
    )
    phone_number = models.CharField(max_length=15, blank=True, null=True)
    date_of_birth = models.DateField(blank=True, null=True)
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Use email as username field
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username', 'first_name', 'last_name']
    
    class Meta:
        db_table = 'users'
        verbose_name = 'User'
        verbose_name_plural = 'Users'
    
    def __str__(self):
        return f"{self.email} ({self.get_full_name()})"

# after that i do some makemigrations to test up or using docker to try to run it up
docker-compose up --build user_service user_db
or 
python3.10 manage.py makemigrations 
python3.10 manage.py migrate


Step 5: Create Service Layer
Create user/services.py:
Step 6: Create CRUD Operations
Create user/crud.py:
Step 7: Create Serializers
Create user/serializers.py:
Step 8: Create API Views
Create user/views.py:

Step 9: Configure URLs
Create user/urls.py:
Update user_service/urls.py:
Step 10: Update Settings for Custom User Model
Add to user_service/settings.py:
Step 12: Register Models in Admin
Update user/admin.py:
