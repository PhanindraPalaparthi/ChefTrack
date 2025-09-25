# backend/inventory/serializers.py

from rest_framework import serializers
from .models import Category, Product, Inventory, UsageLog
from .models import ProductMaster, InventoryItem

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'

class ProductSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name', read_only=True)
    
    class Meta:
        model = Product
        fields = '__all__'

class ProductMasterSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProductMaster
        fields = ['id', 'gtin', 'name', 'shelf_life_days']

class InventorySerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source='product.name', read_only=True)
    product_barcode = serializers.CharField(source='product.barcode', read_only=True)
    days_until_expiry = serializers.ReadOnlyField()
    status = serializers.ReadOnlyField()
    
    class Meta:
        model = Inventory
        fields = '__all__'

class InventoryItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = InventoryItem
        fields = [
            'id', 'product', 'quantity',
            'purchase_date', 'expiry_date',
            'supplier', 'cost_price', 'batch_number'
        ]

class InventoryCreateSerializer(serializers.Serializer):
    # Product data
    product = serializers.DictField()
    
    # Inventory data
    quantity = serializers.IntegerField()
    purchase_date = serializers.DateTimeField()
    expiry_date = serializers.DateTimeField()
    batch_number = serializers.CharField(required=False, allow_blank=True)
    supplier = serializers.CharField()
    cost_price = serializers.DecimalField(max_digits=10, decimal_places=2)
    
    def create(self, validated_data):
        from django.contrib.auth.models import User
        
        # Extract product data
        product_data = validated_data.pop('product')
        
        # Get or create category
        category_name = product_data.get('category', 'Food & Beverages')
        category, created = Category.objects.get_or_create(
            name=category_name,
            defaults={'description': f'Auto-created category: {category_name}'}
        )
        
        # Get or create product
        product, created = Product.objects.get_or_create(
            barcode=product_data['barcode'],
            defaults={
                'name': product_data['name'],
                'category': category,
                'brand': product_data.get('brand', ''),
                'unit_price': product_data['unit_price'],
                'description': product_data.get('description', ''),
                'image_url': product_data.get('image_url', ''),
            }
        )
        
        # Create inventory item
        # Get current user from request context
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            user = request.user
        else:
            # Fallback to first superuser if no request context
            user = User.objects.filter(is_superuser=True).first()
            if not user:
                # Create a default user if none exists
                user = User.objects.create_user(
                    username='system',
                    email='system@cheftrack.com',
                    password='temporary123'
                )
        
        inventory = Inventory.objects.create(
            product=product,
            added_by=user,
            **validated_data
        )
        
        return inventory

class UsageLogSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source='inventory.product.name', read_only=True)
    
    class Meta:
        model = UsageLog
        fields = '__all__'