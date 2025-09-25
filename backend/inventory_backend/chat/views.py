from django.http import JsonResponse

def test_view(request):
    return JsonResponse({'message': 'Chat app is working!', 'app': 'chat'})