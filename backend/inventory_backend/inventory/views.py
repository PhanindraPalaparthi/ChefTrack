# backend/inventory/views.py

from rest_framework import viewsets, status
from rest_framework.decorators import action, api_view
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta
from django.contrib.auth.decorators import login_required
from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
from .models import ProductMaster, InventoryItem
from .serializers import ProductMasterSerializer, InventoryItemSerializer
import json

from .models import Category, Product, Inventory, UsageLog
from .serializers import (
    CategorySerializer, 
    ProductSerializer, 
    InventorySerializer, 
    InventoryCreateSerializer,
    UsageLogSerializer
)

def test_view(request):
    return JsonResponse({
        'message': 'Inventory app is working!', 
        'app': 'inventory',
        'method': request.method,
        'available_endpoints': [
            '/api/inventory/categories/',
            '/api/inventory/products/',
            '/api/inventory/items/',
            '/api/inventory/add/',
            '/api/inventory/dashboard_stats/',
        ]
    })

class CategoryViewSet(viewsets.ModelViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer

class ProductViewSet(viewsets.ModelViewSet):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    
    @action(detail=False, methods=['get'])
    def search_by_barcode(self, request):
        barcode = request.query_params.get('barcode')
        if barcode:
            try:
                product = Product.objects.get(barcode=barcode)
                serializer = self.get_serializer(product)
                return Response(serializer.data)
            except Product.DoesNotExist:
                return Response({'error': 'Product not found'}, status=status.HTTP_404_NOT_FOUND)
        return Response({'error': 'Barcode parameter required'}, status=status.HTTP_400_BAD_REQUEST)

class InventoryViewSet(viewsets.ModelViewSet):
    queryset = Inventory.objects.all()
    serializer_class = InventorySerializer
    
    @action(detail=False, methods=['get'])
    def expiring_soon(self, request):
        days = int(request.query_params.get('days', 7))
        expiry_threshold = timezone.now() + timedelta(days=days)
        expiring_items = Inventory.objects.filter(
            expiry_date__lte=expiry_threshold,
            is_expired=False,
            quantity__gt=0
        ).select_related('product')
        serializer = self.get_serializer(expiring_items, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def dashboard_stats(self, request):
        total_items = Inventory.objects.filter(quantity__gt=0).count()
        expiring_soon = Inventory.objects.filter(
            expiry_date__lte=timezone.now() + timedelta(days=7),
            is_expired=False,
            quantity__gt=0
        ).count()
        expired_items = Inventory.objects.filter(
            expiry_date__lt=timezone.now()
        ).count()
        total_categories = Category.objects.count()
        
        return Response({
            'total_items': total_items,
            'expiring_soon': expiring_soon,
            'expired_items': expired_items,
            'total_categories': total_categories
        })

@csrf_exempt
@api_view(['POST'])
def add_inventory_item(request):
    """
    Add inventory item from barcode scanner
    """
    try:
        print(f"📥 Received add inventory request")
        print(f"📥 Request data: {request.data}")
        
        serializer = InventoryCreateSerializer(
            data=request.data, 
            context={'request': request}
        )
        
        if serializer.is_valid():
            inventory_item = serializer.save()
            
            # Return the created inventory item
            response_serializer = InventorySerializer(inventory_item)
            
            print(f"✅ Inventory item created: {inventory_item}")
            
            response = Response({
                'success': True,
                'message': 'Product added to inventory successfully!',
                'data': response_serializer.data
            }, status=status.HTTP_201_CREATED)
            
        else:
            print(f"❌ Validation errors: {serializer.errors}")
            response = Response({
                'success': False,
                'message': 'Validation failed',
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Add CORS headers
        response['Access-Control-Allow-Origin'] = '*'
        return response
        
    except Exception as e:
        print(f"❌ Error adding inventory item: {str(e)}")
        import traceback
        traceback.print_exc()
        
        response = Response({
            'success': False,
            'message': f'An error occurred: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        response['Access-Control-Allow-Origin'] = '*'
        return response

class UsageLogViewSet(viewsets.ModelViewSet):
    queryset = UsageLog.objects.all()
    serializer_class = UsageLogSerializer


class ProductMasterViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = ProductMaster.objects.all()
    lookup_field = 'gtin'
    serializer_class = ProductMasterSerializer

class InventoryItemViewSet(viewsets.ModelViewSet):
    queryset = InventoryItem.objects.all().order_by('-created_at')
    serializer_class = InventoryItemSerializer
