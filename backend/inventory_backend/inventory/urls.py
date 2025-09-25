# backend/inventory/urls.py

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views
from .views import ProductMasterViewSet, InventoryItemViewSet

router = DefaultRouter()
router.register(r'categories',  views.CategoryViewSet)
router.register(r'products',    views.ProductViewSet)
router.register(r'items',       views.InventoryViewSet)
router.register(r'usage-logs',  views.UsageLogViewSet)

# Master list of all products
router.register(
    r'product-masters',
    ProductMasterViewSet,
    basename='product-master'
)

# Inventory items endpoint (unique basename)
router.register(
    r'inventory',
    InventoryItemViewSet,
    basename='inventory-item'
)

urlpatterns = [
    path('test/', views.test_view, name='inventory_test'),
    path('add/',  views.add_inventory_item, name='add_inventory_item'),
    path('', include(router.urls)),
]
