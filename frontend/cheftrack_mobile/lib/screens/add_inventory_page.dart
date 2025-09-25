// lib/screens/add_inventory_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product_master.dart';
import '../services/api_service.dart';

class AddInventoryPage extends StatefulWidget {
  final ProductMaster product;
  final DateTime? initialExpiry;

  AddInventoryPage({
    required this.product,
    this.initialExpiry,
  });

  @override
  _AddInventoryPageState createState() => _AddInventoryPageState();
}

class _AddInventoryPageState extends State<AddInventoryPage> {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _supplierController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _batchNumberController = TextEditingController();

  // Form state
  DateTime _purchaseDate = DateTime.now();
  late DateTime _expiryDate;
  String _selectedCategory = 'Food & Beverages';
  bool _isLoading = false;

  // Categories
  final List<String> _categories = [
    'Food & Beverages',
    'Dairy Products',
    'Meat & Poultry',
    'Fruits & Vegetables',
    'Pantry Items',
    'Frozen Foods',
    'Bakery Items',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // if scanner passed us an expiry, use it; otherwise calculate via shelf‐life
    _expiryDate = widget.initialExpiry ??
        _purchaseDate.add(Duration(days: widget.product.shelfLifeDays));
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _purchaseDate = picked;
        _expiryDate = picked.add(Duration(days: widget.product.shelfLifeDays));
      });
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _addToInventory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final inventoryData = {
      'product': {
        'name': widget.product.productName ?? 'Unknown Product',
        'barcode': widget.product.barcode,
        'category': _selectedCategory,
        'brand': widget.product.brand ?? '',
        'unit_price': double.tryParse(_costPriceController.text) ?? 0.0,
        'description': widget.product.description ?? '',
        'image_url': widget.product.imageUrl,
      },
      'quantity': int.tryParse(_quantityController.text) ?? 0,
      'purchase_date': _purchaseDate.toIso8601String(),
      'expiry_date': _expiryDate.toIso8601String(),
      'batch_number': _batchNumberController.text.isNotEmpty 
          ? _batchNumberController.text 
          : null,
      'supplier': _supplierController.text,
      'cost_price': double.tryParse(_costPriceController.text) ?? 0.0,
    };

    try {
      final result = await ApiService.post('/inventory/add/', inventoryData);
      
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item added to inventory successfully!'),
            backgroundColor: Colors.green[600],
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: ${result['message'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF2C3E50),
      appBar: AppBar(
        title: Text(
          'Add to Inventory',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF3A4A5C),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductInfoCard(),
            SizedBox(height: 20),
            _buildInventoryForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF3A4A5C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFFF6B35).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: widget.product.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: widget.product.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF6B35),
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (_, __, ___) => Icon(
                        Icons.fastfood,
                        color: Colors.grey[600],
                        size: 40,
                      ),
                    ),
                  )
                : Icon(
                    Icons.fastfood,
                    color: Colors.grey[600],
                    size: 40,
                  ),
          ),
          SizedBox(width: 16),
          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.displayName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.product.brand != null) ...[
                  SizedBox(height: 4),
                  Text(
                    widget.product.brand!,
                    style: TextStyle(
                      color: Color(0xFFFF6B35),
                      fontSize: 14,
                    ),
                  ),
                ],
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6B35).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Barcode: ${widget.product.barcode}',
                    style: TextStyle(
                      color: Color(0xFFFF6B35),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryForm() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF3A4A5C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            
            // Quantity
            _buildTextFormField(
              controller: _quantityController,
              label: 'Quantity *',
              hint: 'Enter quantity (e.g., 10)',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter quantity';
                }
                if (int.tryParse(value) == null || int.parse(value) <= 0) {
                  return 'Please enter valid quantity';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Category
            _buildCategoryDropdown(),
            SizedBox(height: 16),

            // Supplier
            _buildTextFormField(
              controller: _supplierController,
              label: 'Supplier *',
              hint: 'Enter supplier name',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter supplier name';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Cost Price
            _buildTextFormField(
              controller: _costPriceController,
              label: 'Cost Price (\$) *',
              hint: 'Enter cost price',
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter cost price';
                }
                if (double.tryParse(value) == null || double.parse(value) <= 0) {
                  return 'Please enter valid price';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Batch Number
            _buildTextFormField(
              controller: _batchNumberController,
              label: 'Batch Number',
              hint: 'Enter batch number (optional)',
            ),
            SizedBox(height: 16),

            // Purchase Date
            _buildDatePicker(
              label: 'Purchase Date',
              date: _purchaseDate,
              onTap: _pickPurchaseDate,
            ),
            SizedBox(height: 16),

            // Expiry Date
            _buildDatePicker(
              label: 'Expiry Date',
              date: _expiryDate,
              onTap: _pickExpiryDate,
              isExpiry: true,
            ),
            SizedBox(height: 30),

            // Add Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _addToInventory,
                icon: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.add),
                label: Text(
                  _isLoading ? 'Adding...' : 'Add to Inventory',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Color(0xFF455A64),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFFF6B35)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category *',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          hint: Text('Select category'),
          items: _categories.map((category) => DropdownMenuItem(
            value: category,
            child: Text(
              category,
              style: TextStyle(color: Colors.white),
            ),
          )).toList(),
          onChanged: (value) => setState(() => _selectedCategory = value!),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a category';
            }
            return null;
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Color(0xFF455A64),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFFF6B35)),
            ),
          ),
          dropdownColor: Color(0xFF455A64),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    bool isExpiry = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isExpiry && widget.initialExpiry != null)
              Container(
                margin: EdgeInsets.only(left: 8),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Auto-detected',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF455A64),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: TextStyle(color: Colors.white),
                ),
                Icon(
                  Icons.calendar_today,
                  color: Color(0xFFFF6B35),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _supplierController.dispose();
    _costPriceController.dispose();
    _batchNumberController.dispose();
    super.dispose();
  }
}