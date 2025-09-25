// lib/models/product_master.dart

class ProductMaster {
  final String barcode;
  final String? productName;
  final String? brand;
  final String? imageUrl;
  final String? category;
  final String? description;
  final double? unitPrice;
  final int shelfLifeDays;
  final String? unit;
  final String? packaging;
  final String? ingredients;
  final Map<String, dynamic>? nutritionFacts;

  ProductMaster({
    required this.barcode,
    this.productName,
    this.brand,
    this.imageUrl,
    this.category,
    this.description,
    this.unitPrice,
    this.shelfLifeDays = 30, // default 30 days
    this.unit,
    this.packaging,
    this.ingredients,
    this.nutritionFacts,
  });

  /// Factory constructor for OpenFoodFacts API response
  factory ProductMaster.fromOpenFoodFacts(Map<String, dynamic> json, String barcode) {
    final product = json['product'] as Map<String, dynamic>?;
    if (product == null) {
      return ProductMaster(barcode: barcode);
    }
    
    return ProductMaster(
      barcode: barcode,
      productName: product['product_name'] as String?,
      brand: product['brands'] as String?,
      imageUrl: product['image_url'] as String?,
      category: product['categories'] as String?,
      description: product['ingredients_text'] as String?,
      unit: product['quantity'] as String?,
      packaging: product['packaging'] as String?,
      ingredients: product['ingredients_text'] as String?,
      nutritionFacts: product['nutriments'] as Map<String, dynamic>?,
      shelfLifeDays: _estimateShelfLife(product),
    );
  }

  /// Check if product has valid/complete data
  bool get isValid => productName != null && productName!.isNotEmpty;

  /// Get display name (product name or fallback)
  String get displayName => productName ?? 'Unknown Product';

  /// Get display brand (brand or fallback)
  String get displayBrand => brand ?? 'Unknown Brand';

  /// Estimate shelf life based on product category
  static int _estimateShelfLife(Map<String, dynamic> product) {
    final categories = (product['categories'] as String? ?? '').toLowerCase();
    final productName = (product['product_name'] as String? ?? '').toLowerCase();
    
    // Dairy products
    if (categories.contains('dairy') || 
        categories.contains('milk') || 
        categories.contains('yogurt') ||
        productName.contains('milk') ||
        productName.contains('yogurt')) {
      return 7; // 1 week
    }
    
    // Meat and poultry
    if (categories.contains('meat') || 
        categories.contains('poultry') ||
        categories.contains('chicken') ||
        categories.contains('beef') ||
        productName.contains('chicken') ||
        productName.contains('meat')) {
      return 3; // 3 days
    }
    
    // Fresh produce
    if (categories.contains('fruit') || 
        categories.contains('vegetable') ||
        categories.contains('produce') ||
        productName.contains('apple') ||
        productName.contains('banana')) {
      return 5; // 5 days
    }
    
    // Frozen foods
    if (categories.contains('frozen')) {
      return 90; // 3 months
    }
    
    // Bakery items
    if (categories.contains('bakery') || 
        categories.contains('bread') ||
        productName.contains('bread') ||
        productName.contains('cake')) {
      return 5; // 5 days
    }
    
    // Beverages
    if (categories.contains('beverage') || 
        categories.contains('drink') ||
        categories.contains('water') ||
        categories.contains('juice') ||
        productName.contains('water') ||
        productName.contains('juice')) {
      return 180; // 6 months
    }
    
    // Canned goods
    if (categories.contains('canned') || 
        categories.contains('preserved') ||
        productName.contains('canned')) {
      return 730; // 2 years
    }
    
    // Default for other products
    return 30; // 1 month
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'name': productName,
      'brand': brand,
      'image_url': imageUrl,
      'category': category,
      'description': description,
      'unit_price': unitPrice,
      'shelf_life_days': shelfLifeDays,
      'unit': unit,
      'packaging': packaging,
      'ingredients': ingredients,
      'nutrition_facts': nutritionFacts,
    };
  }

  @override
  String toString() {
    return 'ProductMaster(barcode: $barcode, name: $productName, brand: $brand)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductMaster && other.barcode == barcode;
  }

  @override
  int get hashCode => barcode.hashCode;
}