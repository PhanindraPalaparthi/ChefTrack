# backend/users/views.py

from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
import json

def test_view(request):
    return JsonResponse({
        'message': 'Users app is working!', 
        'app': 'users',
        'method': request.method,
        'available_endpoints': [
            '/api/users/test/',
            '/api/users/register/',
            '/api/users/login/',
        ]
    })

@csrf_exempt
def register_view(request):
    # Handle CORS preflight request
    if request.method == 'OPTIONS':
        response = JsonResponse({'status': 'OK'})
        response['Access-Control-Allow-Origin'] = '*'
        response['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
        response['Access-Control-Allow-Headers'] = 'Content-Type, Accept'
        return response
        
    if request.method != 'POST':
        response = JsonResponse({'error': 'Method not allowed'}, status=405)
        response['Access-Control-Allow-Origin'] = '*'
        return response
        
    try:
        print(f"📥 Received registration request")
        print(f"📥 Request body: {request.body}")
        
        # Parse JSON data
        try:
            data = json.loads(request.body)
        except json.JSONDecodeError as e:
            print(f"❌ JSON decode error: {e}")
            response = JsonResponse({
                'success': False,
                'message': 'Invalid JSON data'
            }, status=400)
            response['Access-Control-Allow-Origin'] = '*'
            return response
        
        # Get registration data (no confirm_password required)
        full_name = data.get('full_name', '').strip()
        email = data.get('email', '').strip()
        password = data.get('password', '')
        
        print(f"📝 Registration data: name='{full_name}', email='{email}', pwd_len={len(password)}")
        
        # Validation
        if not full_name:
            response = JsonResponse({
                'success': False,
                'message': 'Full name is required'
            }, status=400)
            response['Access-Control-Allow-Origin'] = '*'
            return response
            
        if not email:
            response = JsonResponse({
                'success': False,
                'message': 'Email is required'
            }, status=400)
            response['Access-Control-Allow-Origin'] = '*'
            return response
            
        if not password:
            response = JsonResponse({
                'success': False,
                'message': 'Password is required'
            }, status=400)
            response['Access-Control-Allow-Origin'] = '*'
            return response
        
        if len(password) < 3:
            response = JsonResponse({
                'success': False,
                'message': 'Password must be at least 3 characters long'
            }, status=400)
            response['Access-Control-Allow-Origin'] = '*'
            return response
        
        # Check if user already exists
        if User.objects.filter(email=email).exists():
            print(f"❌ User with email {email} already exists")
            response = JsonResponse({
                'success': False,
                'message': 'An account with this email already exists'
            }, status=400)
            response['Access-Control-Allow-Origin'] = '*'
            return response
        
        # Split full name into first and last name
        name_parts = full_name.split(' ', 1)
        first_name = name_parts[0]
        last_name = name_parts[1] if len(name_parts) > 1 else ''
        
        # Create user
        print(f"🚀 Creating user with email: {email}")
        user = User.objects.create_user(
            username=email,  # Using email as username
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name
        )
        
        print(f"✅ User created successfully: {user.email} (ID: {user.id})")
        
        # Automatically log in the user
        login(request, user)
        
        response = JsonResponse({
            'success': True,
            'message': 'Account created successfully!',
            'user': {
                'id': user.id,
                'full_name': user.get_full_name(),
                'email': user.email,
                'username': user.username
            }
        }, status=201)
        
        # Add CORS headers to response
        response['Access-Control-Allow-Origin'] = '*'
        return response
        
    except Exception as e:
        print(f"❌ Registration error: {type(e).__name__}: {str(e)}")
        import traceback
        traceback.print_exc()
        
        response = JsonResponse({
            'success': False,
            'message': f'An error occurred: {str(e)}'
        }, status=500)
        response['Access-Control-Allow-Origin'] = '*'
        return response

@csrf_exempt
def login_view(request):
    # Handle CORS preflight request
    if request.method == 'OPTIONS':
        response = JsonResponse({'status': 'OK'})
        response['Access-Control-Allow-Origin'] = '*'
        response['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
        response['Access-Control-Allow-Headers'] = 'Content-Type, Accept'
        return response
        
    if request.method != 'POST':
        response = JsonResponse({'error': 'Method not allowed'}, status=405)
        response['Access-Control-Allow-Origin'] = '*'
        return response
        
    try:
        print(f"📥 Received login request")
        
        data = json.loads(request.body)
        email = data.get('email', '').strip()
        password = data.get('password', '')
        
        print(f"📝 Login attempt for email: {email}")
        
        if not email or not password:
            response = JsonResponse({
                'success': False,
                'message': 'Email and password are required'
            }, status=400)
            response['Access-Control-Allow-Origin'] = '*'
            return response
        
        # Authenticate user (using email as username)
        user = authenticate(request, username=email, password=password)
        
        if user is not None:
            login(request, user)
            print(f"✅ Login successful for: {user.email}")
            
            response = JsonResponse({
                'success': True,
                'message': 'Login successful',
                'user': {
                    'id': user.id,
                    'full_name': user.get_full_name(),
                    'email': user.email,
                    'username': user.username
                }
            })
            response['Access-Control-Allow-Origin'] = '*'
            return response
        else:
            print(f"❌ Login failed for email: {email}")
            response = JsonResponse({
                'success': False,
                'message': 'Invalid email or password'
            }, status=401)
            response['Access-Control-Allow-Origin'] = '*'
            return response
            
    except json.JSONDecodeError:
        response = JsonResponse({
            'success': False,
            'message': 'Invalid JSON data'
        }, status=400)
        response['Access-Control-Allow-Origin'] = '*'
        return response
    except Exception as e:
        print(f"❌ Login error: {str(e)}")
        response = JsonResponse({
            'success': False,
            'message': f'An error occurred: {str(e)}'
        }, status=500)
        response['Access-Control-Allow-Origin'] = '*'
        return response

@csrf_exempt
def logout_view(request):
    logout(request)
    response = JsonResponse({
        'success': True,
        'message': 'Logout successful'
    })
    response['Access-Control-Allow-Origin'] = '*'
    return response

@login_required
def profile_view(request):
    user = request.user
    response = JsonResponse({
        'success': True,
        'user': {
            'id': user.id,
            'full_name': user.get_full_name(),
            'email': user.email,
            'username': user.username,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'date_joined': user.date_joined.isoformat()
        }
    })
    response['Access-Control-Allow-Origin'] = '*'
    return response