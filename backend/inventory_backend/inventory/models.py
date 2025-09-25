# backend/inventory/models.py

from django.db import models
from django.contrib.auth.models import User

class Category(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name_plural = "Categories"
    
    def __str__(self):
        return self.name

class Product(models.Model):
    name = models.CharField(max_length=200)
    barcode = models.CharField(max_length=100, unique=True)
    category = models.ForeignKey(Category, on_delete=models.CASCADE, null=True, blank=True)
    brand = models.CharField(max_length=100, blank=True)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)
    shelf_life_days = models.IntegerField(default=7)  # Default shelf life from manufacture
    description = models.TextField(blank=True)
    image_url = models.URLField(blank=True)  # For Open Food Facts images
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return self.name

class Inventory(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    quantity = models.IntegerField()
    purchase_date = models.DateTimeField()
    expiry_date = models.DateTimeField()
    batch_number = models.CharField(max_length=50, blank=True)
    supplier = models.CharField(max_length=200)
    cost_price = models.DecimalField(max_digits=10, decimal_places=2)
    is_expired = models.BooleanField(default=False)
    added_by = models.ForeignKey(User, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name_plural = "Inventory Items"
    
    def __str__(self):
        return f"{self.product.name} - {self.quantity} units"
    
    @property
    def days_until_expiry(self):
        from datetime import datetime
        if self.expiry_date:
            delta = self.expiry_date.date() - datetime.now().date()
            return delta.days
        return None
    
    @property
    def is_expiring_soon(self):
        days = self.days_until_expiry
        return days is not None and 0 < days <= 7
    
    @property
    def status(self):
        if self.is_expired:
            return 'expired'
        elif self.is_expiring_soon:
            return 'expiring_soon'
        else:
            return 'good'

class UsageLog(models.Model):
    inventory = models.ForeignKey(Inventory, on_delete=models.CASCADE)
    quantity_used = models.IntegerField()
    used_by = models.ForeignKey(User, on_delete=models.CASCADE)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.inventory.product.name} - {self.quantity_used} used"
    

    from django.db import models

class ProductMaster(models.Model):
    gtin = models.CharField(max_length=32, unique=True)          # barcode
    name = models.CharField(max_length=200)
    shelf_life_days = models.PositiveIntegerField()              # e.g. 7 days

    def __str__(self):
        return f"{self.gtin} – {self.name}"

class InventoryItem(models.Model):
    product = models.ForeignKey(ProductMaster, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField()
    purchase_date = models.DateField()
    expiry_date = models.DateField()
    supplier = models.CharField(max_length=200, blank=True)
    cost_price = models.DecimalField(max_digits=10, decimal_places=2)
    batch_number = models.CharField(max_length=100, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.product.name} ({self.quantity})"
