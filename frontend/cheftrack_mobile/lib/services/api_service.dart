// // lib/services/api_service.dart

// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// import '../models/product_master.dart';

// class ApiService {
//   /// Point this at your Django root "/api"
//   static const String baseUrl = 'http://192.168.1.100:8000/api';

//   static String? _authToken;

//   /// Call once at app startup
//   static Future<void> init() async {
//     final prefs = await SharedPreferences.getInstance();
//     _authToken = prefs.getString('auth_token');
//   }

//   /// Save token after login
//   static Future<void> setAuthToken(String token) async {
//     _authToken = token;
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('auth_token', token);
//   }

//   /// Clear on logout
//   static Future<void> clearAuthToken() async {
//     _authToken = null;
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('auth_token');
//   }

//   // ────────────────────────────────────────────────────────────────────────
//   // GENERIC HTTP METHODS

//   static Future<Map<String, dynamic>> get(String endpoint) async {
//     try {
//       final resp = await http
//           .get(
//             Uri.parse('$baseUrl$endpoint'),
//             headers: {
//               'Content-Type': 'application/json',
//               'Accept': 'application/json',
//               if (_authToken != null) 'Authorization': 'Token $_authToken',
//             },
//           )
//           .timeout(Duration(seconds: 30));
//       return _handleResponse(resp);
//     } catch (e) {
//       throw Exception('Network error: $e');
//     }
//   }

//   static Future<Map<String, dynamic>> post(
//       String endpoint, Map<String, dynamic> data) async {
//     try {
//       final resp = await http
//           .post(
//             Uri.parse('$baseUrl$endpoint'),
//             headers: {
//               'Content-Type': 'application/json',
//               'Accept': 'application/json',
//               if (_authToken != null) 'Authorization': 'Token $_authToken',
//             },
//             body: json.encode(data),
//           )
//           .timeout(Duration(seconds: 30));
//       return _handleResponse(resp);
//     } catch (e) {
//       throw Exception('Network error: $e');
//     }
//   }

//   static Future<Map<String, dynamic>> put(
//       String endpoint, Map<String, dynamic> data) async {
//     try {
//       final resp = await http
//           .put(
//             Uri.parse('$baseUrl$endpoint'),
//             headers: {
//               'Content-Type': 'application/json',
//               'Accept': 'application/json',
//               if (_authToken != null) 'Authorization': 'Token $_authToken',
//             },
//             body: json.encode(data),
//           )
//           .timeout(Duration(seconds: 30));
//       return _handleResponse(resp);
//     } catch (e) {
//       throw Exception('Network error: $e');
//     }
//   }

//   static Future<Map<String, dynamic>> delete(String endpoint) async {
//     try {
//       final resp = await http
//           .delete(
//             Uri.parse('$baseUrl$endpoint'),
//             headers: {
//               'Content-Type': 'application/json',
//               'Accept': 'application/json',
//               if (_authToken != null) 'Authorization': 'Token $_authToken',
//             },
//           )
//           .timeout(Duration(seconds: 30));
//       return _handleResponse(resp);
//     } catch (e) {
//       throw Exception('Network error: $e');
//     }
//   }

//   static Map<String, dynamic> _handleResponse(http.Response resp) {
//     if (resp.statusCode >= 200 && resp.statusCode < 300) {
//       if (resp.body.isEmpty) return {'success': true};
//       final decoded = json.decode(resp.body);
//       if (decoded is Map<String, dynamic>) {
//         return {'success': true, 'data': decoded, 'status_code': resp.statusCode};
//       }
//       return {'success': true, 'data': decoded, 'status_code': resp.statusCode};
//     }
//     if (resp.statusCode == 401) {
//       clearAuthToken();
//       throw Exception('Unauthorized – please log in again.');
//     }
//     if (resp.statusCode == 404) {
//       return {'success': false, 'status_code': resp.statusCode, 'message': 'Not found'};
//     }
//     // Try to parse error message
//     try {
//       final err = json.decode(resp.body);
//       return {
//         'success': false, 
//         'status_code': resp.statusCode,
//         'message': err['message'] ?? err['detail'] ?? 'Server error',
//         'error': err
//       };
//     } catch (_) {
//       return {
//         'success': false, 
//         'status_code': resp.statusCode,
//         'message': 'Server error: ${resp.statusCode}'
//       };
//     }
//   }

//   // ────────────────────────────────────────────────────────────────────────
//   // PRODUCT‐MASTER ENDPOINT

//   /// Fetch the "master" product data by GTIN/barcode
//   /// Enhanced version that handles both success and failure cases
//   static Future<ProductMaster?> fetchProductMaster(String gtin) async {
//     try {
//       final resp = await get('/products/$gtin/');
//       if (resp['success'] == true && resp['data'] != null) {
//         return ProductMaster.fromJson(resp['data'] as Map<String, dynamic>);
//       }
//       return null;
//     } catch (e) {
//       print('Error fetching product master: $e');
//       return null;
//     }
//   }

//   // ────────────────────────────────────────────────────────────────────────
//   // INVENTORY ENDPOINTS

//   /// Enhanced add inventory item method that handles comprehensive product data
//   static Future<Map<String, dynamic>> addInventoryItem(Map<String, dynamic> inventoryData) async {
//     try {
//       final resp = await post('/inventory/items/', inventoryData);
//       return resp;
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Network error: $e',
//         'message': 'Failed to connect to server',
//       };
//     }
//   }

//   /// Original add inventory method (kept for backward compatibility)
//   static Future<bool> addInventoryItemSimple({
//     required String gtin,
//     required int quantity,
//     required DateTime purchaseDate,
//     required DateTime expiryDate,
//     required String supplier,
//     required double costPrice,
//     String? batchNumber,
//   }) async {
//     final payload = {
//       'product':       gtin,
//       'quantity':      quantity,
//       'purchase_date': purchaseDate.toIso8601String(),
//       'expiry_date':   expiryDate.toIso8601String(),
//       'supplier':      supplier,
//       'cost_price':    costPrice,
//       'batch_number':  batchNumber ?? '',
//     };
//     final resp = await post('/inventory/items/', payload);
//     return resp['success'] == true;
//   }

//   /// List all inventory items
//   static Future<Map<String, dynamic>> getInventoryItems() =>
//       get('/inventory/items/');

//   /// Update one by ID
//   static Future<Map<String, dynamic>> updateInventoryItem(
//           int id, Map<String, dynamic> data) =>
//       put('/inventory/items/$id/', data);

//   /// Delete one
//   static Future<Map<String, dynamic>> deleteInventoryItem(int id) =>
//       delete('/inventory/items/$id/');

//   // ────────────────────────────────────────────────────────────────────────
//   // AUTHENTICATION ENDPOINTS

//   /// Register user
//   static Future<Map<String, dynamic>> register(
//       String fullName, String email, String password) async {
//     try {
//       final payload = {
//         'full_name': fullName,
//         'email': email,
//         'password': password,
//         'confirm_password': password,
//       };
//       final resp = await post('/users/register/', payload);
//       return resp;
//     } catch (e) {
//       return {'success': false, 'error': 'Network error: $e'};
//     }
//   }

//   /// Login user
//   static Future<Map<String, dynamic>> login(
//       String email, String password) async {
//     try {
//       final payload = {
//         'email': email,
//         'password': password,
//       };
//       final resp = await post('/users/login/', payload);
      
//       // If login successful, save the token
//       if (resp['success'] == true && resp['data'] != null) {
//         final token = resp['data']['token'];
//         if (token != null) {
//           await setAuthToken(token);
//         }
//       }
      
//       return resp;
//     } catch (e) {
//       return {'success': false, 'error': 'Network error: $e'};
//     }
//   }

//   /// Logout user
//   static Future<Map<String, dynamic>> logout() async {
//     try {
//       final resp = await post('/users/logout/', {});
//       await clearAuthToken();
//       return resp;
//     } catch (e) {
//       await clearAuthToken(); // Clear token even if request fails
//       return {'success': true}; // Consider logout successful if token is cleared
//     }
//   }

//   // ────────────────────────────────────────────────────────────────────────
//   // DASHBOARD & ANALYTICS ENDPOINTS

//   /// Get dashboard statistics
//   static Future<Map<String, dynamic>> getDashboardStats() async {
//     try {
//       return await get('/dashboard/stats/');
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Failed to load dashboard stats: $e'
//       };
//     }
//   }

//   /// Get expiring items
//   static Future<Map<String, dynamic>> getExpiringItems({int days = 7}) async {
//     try {
//       return await get('/inventory/expiring/?days=$days');
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Failed to load expiring items: $e'
//       };
//     }
//   }

//   /// Get expired items
//   static Future<Map<String, dynamic>> getExpiredItems() async {
//     try {
//       return await get('/inventory/expired/');
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Failed to load expired items: $e'
//       };
//     }
//   }

//   // ────────────────────────────────────────────────────────────────────────
//   // OPENFOODFACTS INTEGRATION (FALLBACK)

//   /// Fetch from OpenFoodFacts as fallback when backend doesn't have product
//   static Future<ProductMaster?> fetchFromOpenFoodFacts(String barcode) async {
//     try {
//       final response = await http.get(
//         Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
//         headers: {
//           'User-Agent': 'ChefTrack/1.0.0',
//           'Accept': 'application/json',
//         },
//       ).timeout(Duration(seconds: 10));
      
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         if (data['status'] == 1) {
//           return ProductMaster.fromOpenFoodFacts(data, barcode);
//         }
//       }
//     } catch (e) {
//       print('Error fetching from OpenFoodFacts: $e');
//     }
//     return null;
//   }

//   // ────────────────────────────────────────────────────────────────────────
//   // UTILITY METHODS

//   /// Check if user is authenticated
//   static bool get isAuthenticated => _authToken != null;

//   /// Get current auth token
//   static String? get authToken => _authToken;

//   /// Test connection to backend
//   static Future<bool> testConnection() async {
//     try {
//       final resp = await http.get(
//         Uri.parse('$baseUrl/health/'),
//         headers: {'Content-Type': 'application/json'},
//       ).timeout(Duration(seconds: 5));
//       return resp.statusCode == 200;
//     } catch (e) {
//       return false;
//     }
//   }
// }


// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://192.168.1.187:8000/api';

  static Future<Map<String, dynamic>> register(
      String fullName, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/register/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': fullName,
          'email': email,
          'password': password,
          'confirm_password': password,
        }),
      );
      return {
        'success': response.statusCode == 201,
        'data': json.decode(response.body),
        'status_code': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );
      return {
        'success': response.statusCode == 200,
        'data': json.decode(response.body),
        'status_code': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    try {
      print('API POST to: $baseUrl$path');
      print('Body: $body');
      
      // For testing purposes, simulate success
      await Future.delayed(Duration(seconds: 1));
      
      return {
        'success': true,
        'data': {'id': DateTime.now().millisecondsSinceEpoch},
        'status_code': 200,
        'message': 'Item added successfully (TEST MODE)',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
        'message': 'Failed to add item',
      };
    }
  }
}