import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cheftrack_mobile/screens/scanner_page.dart';
import 'package:cheftrack_mobile/screens/add_inventory_page.dart';

// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();  // Initialize token from storage
  runApp(ChefTrackApp());
}

class ChefTrackApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChefTrack',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enhanced API Service

class ApiService {
  static const String baseUrl = 'http://192.168.0.184:8000/api';
  static String? _authToken;

  /// Call once at app startup
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
      print('ApiService initialized. Token: ${_authToken != null ? 'Present' : 'Not found'}');
    } catch (e) {
      print('Error initializing ApiService: $e');
    }
  }

  /// Save token after login
  static Future<void> setAuthToken(String token) async {
    try {
      _authToken = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      print('Auth token saved');
    } catch (e) {
      print('Error saving auth token: $e');
    }
  }

  /// Clear on logout
  static Future<void> clearAuthToken() async {
    try {
      _authToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      print('Auth token cleared');
    } catch (e) {
      print('Error clearing auth token: $e');
    }
  }

  /// Check if user is authenticated
  static bool get isAuthenticated => _authToken != null;

  /// Get current auth token
  static String? get authToken => _authToken;

  // ────────────────────────────────────────────────────────────────────────
  // HTTP METHODS

  static Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_authToken != null) 'Authorization': 'Token $_authToken',
      };

      http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(Duration(seconds: 30));
          break;
        case 'POST':
          response = await http.post(
            uri, 
            headers: headers, 
            body: body != null ? json.encode(body) : null,
          ).timeout(Duration(seconds: 30));
          break;
        case 'PUT':
          response = await http.put(
            uri, 
            headers: headers, 
            body: body != null ? json.encode(body) : null,
          ).timeout(Duration(seconds: 30));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(Duration(seconds: 30));
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
        'message': 'Failed to connect to server',
      };
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true, 'status_code': response.statusCode};
      }
      final decoded = json.decode(response.body);
      return {
        'success': true, 
        'data': decoded, 
        'status_code': response.statusCode
      };
    }
    
    if (response.statusCode == 401) {
      clearAuthToken();
      return {
        'success': false,
        'status_code': response.statusCode,
        'message': 'Unauthorized – please log in again.',
      };
    }
    
    if (response.statusCode == 404) {
      return {
        'success': false, 
        'status_code': response.statusCode, 
        'message': 'Not found'
      };
    }
    
    // Try to parse error message
    try {
      final err = json.decode(response.body);
      return {
        'success': false, 
        'status_code': response.statusCode,
        'message': err['message'] ?? err['detail'] ?? 'Server error',
        'error': err
      };
    } catch (_) {
      return {
        'success': false, 
        'status_code': response.statusCode,
        'message': 'Server error: ${response.statusCode}'
      };
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // AUTHENTICATION

  static Future<Map<String, dynamic>> register(
      String fullName, String email, String password) async {
    final payload = {
      'full_name': fullName,
      'email': email,
      'password': password,
      'confirm_password': password,
    };
    
    final result = await _makeRequest('POST', '/users/register/', body: payload);
    
    // Auto-login after successful registration
    if (result['success'] && result['data'] != null) {
      final token = result['data']['token'];
      if (token != null) {
        await setAuthToken(token);
      }
    }
    
    return result;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final payload = {
      'email': email,
      'password': password,
    };
    
    final result = await _makeRequest('POST', '/users/login/', body: payload);
    
    // Save token if login successful
    if (result['success'] && result['data'] != null) {
      final token = result['data']['token'];
      if (token != null) {
        await setAuthToken(token);
      }
    }
    
    return result;
  }

  static Future<Map<String, dynamic>> logout() async {
    try {
      final result = await _makeRequest('POST', '/users/logout/');
      await clearAuthToken();
      return result;
    } catch (e) {
      await clearAuthToken(); // Clear token even if request fails
      return {'success': true}; // Consider logout successful if token is cleared
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // GENERIC METHODS (for backward compatibility)

  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    return await _makeRequest('POST', path, body: body);
  }

  static Future<Map<String, dynamic>> get(String path) async {
    return await _makeRequest('GET', path);
  }

  static Future<Map<String, dynamic>> put(
      String path, Map<String, dynamic> body) async {
    return await _makeRequest('PUT', path, body: body);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    return await _makeRequest('DELETE', path);
  }

  // ────────────────────────────────────────────────────────────────────────
  // INVENTORY & PRODUCT METHODS

  /// Add inventory item with enhanced data
  static Future<Map<String, dynamic>> addInventoryItem(Map<String, dynamic> inventoryData) async {
    return await _makeRequest('POST', '/inventory/add/', body: inventoryData);
  }

  /// Fetch product information (if you have this endpoint)
  static Future<Map<String, dynamic>> fetchProductInfo(String barcode) async {
    return await _makeRequest('GET', '/products/$barcode/');
  }

  /// Get dashboard statistics
  static Future<Map<String, dynamic>> getDashboardStats() async {
    return await _makeRequest('GET', '/dashboard/stats/');
  }

  /// Get inventory items
  static Future<Map<String, dynamic>> getInventoryItems() async {
    return await _makeRequest('GET', '/inventory/items/');
  }

  /// Test connection to backend
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// App colors

class AppColors {
  static const Color primaryBackground = Color(0xFF2C3E50);
  static const Color secondaryBackground = Color(0xFF34495E);
  static const Color cardBackground = Color(0xFF3A4A5C);
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color inputBackground = Color(0xFF455A64);
  static const Color inputBorder = Color(0xFF607D8B);
}

// ─────────────────────────────────────────────────────────────────────────────
// SplashScreen

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _dotsController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _dotsAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    _dotsController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 1500));
    _fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(_fadeController);
    _dotsAnimation = Tween(begin: 0.0, end: 1.0).animate(_dotsController);
    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await _fadeController.forward();
    _dotsController.repeat();
    await Future.delayed(Duration(seconds: 3));
    await _fadeController.reverse();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => AuthScreen(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.restaurant_menu, size: 50, color: Colors.white),
              ),
              SizedBox(height: 30),
              Text(
                'ChefTrack',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Your Ultimate Kitchen Management Solution',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 60),
              AnimatedBuilder(
                animation: _dotsAnimation,
                builder: (_, __) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      double delay = i * 0.2;
                      double v = (_dotsAnimation.value - delay).clamp(0.0, 1.0);
                      double s = (1 + 0.5 * (1 - (v - 0.5).abs() * 2)).clamp(0.5, 1.5);
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Transform.scale(
                          scale: s,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthScreen

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool isSignUp = true, _rememberMe = false, _isLoading = false;
  late AnimationController _anim;
  late Animation<double> _fade;

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: Duration(milliseconds: 300));
    _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeIn),
    );
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toggle() => setState(() => isSignUp = !isSignUp);

  void _showMsg(String m, [bool err = false]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: err ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _doSignUp() async {
    if (_password.text != _confirm.text) {
      _showMsg('Passwords do not match', true);
      return;
    }
    setState(() => _isLoading = true);
    final res = await ApiService.register(
      _fullName.text,
      _email.text,
      _password.text,
    );
    setState(() => _isLoading = false);
    if (res['success']) {
      _showMsg('Account created!');
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => MainNavigationScreen()));
    } else {
      _showMsg(res['error'] ?? 'Failed', true);
    }
  }

  Future<void> _doSignIn() async {
    setState(() => _isLoading = true);
    final res = await ApiService.login(_email.text, _password.text);
    setState(() => _isLoading = false);
    if (res['success']) {
      _showMsg('Login successful!');
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => MainNavigationScreen()));
    } else {
      _showMsg(res['error'] ?? 'Login failed', true);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(color: AppColors.textSecondary),
            prefixIcon: Icon(icon, color: AppColors.textSecondary),
            suffixIcon: suffix,
            filled: true,
            fillColor: AppColors.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryOrange),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(children: [
              SizedBox(height: 40),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.restaurant_menu, color: Colors.white, size: 24),
                ),
                SizedBox(width: 12),
                Text('ChefTrack',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ]),
              SizedBox(height: 16),
              Text(
                'Welcome back to your kitchen',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              SizedBox(height: 40),
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSignUp ? 'Create Account' : 'Sign In',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      isSignUp
                          ? 'Join ChefTrack and start managing your kitchen'
                          : 'Enter your credentials to access your account',
                      style:
                          TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 24),
                    if (isSignUp) ...[
                      _buildField(
                        controller: _fullName,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                      SizedBox(height: 16),
                    ],
                    _buildField(
                      controller: _email,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 16),
                    _buildField(
                      controller: _password,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscure: true,
                      suffix: IconButton(
                        icon: Icon(Icons.visibility_off,
                            color: AppColors.textSecondary),
                        onPressed: () {},
                      ),
                    ),
                    if (!isSignUp) ...[
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (v) =>
                                  setState(() => _rememberMe = v!),
                              activeColor: AppColors.primaryOrange,
                            ),
                            Text('Remember me',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14)),
                          ]),
                          TextButton(
                            onPressed: () {},
                            child: Text('Forgot password?',
                                style: TextStyle(
                                    color: AppColors.primaryOrange,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : (isSignUp ? _doSignUp : _doSignIn),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                isSignUp ? 'Create Account' : 'Sign In',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isSignUp
                                ? 'Already have an account? '
                                : "Don't have an account? ",
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14),
                          ),
                          TextButton(
                            onPressed: _toggle,
                            child: Text(
                              isSignUp ? 'Sign in' : 'Sign up',
                              style: TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSignUp) ...[
                SizedBox(height: 40),
                Text(
                  '© 2025 ChefTrack. All rights reserved.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MainNavigationScreen

class MainNavigationScreen extends StatefulWidget {
  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1;
   final List<Widget> _pages = [
    ScannerPage(),
    DashboardPage(),
    AlertsPage(),
    ChatPage(),
    AccountPage(),
    
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Color(0xFF1A1A1A),
            selectedItemColor: AppColors.primaryOrange,
            unselectedItemColor: Colors.grey[600],
            showSelectedLabels: true,
            showUnselectedLabels: true,
            elevation: 0,
            selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            items: [
              _navItem(Icons.qr_code_scanner, 'Scanner', 0),
              _navItem(Icons.dashboard_rounded, 'Dashboard', 1),
              _navItem(Icons.notifications_outlined, 'Alerts', 2),
              _navItem(Icons.chat_bubble_outline, 'Chat', 3),
              _navItem(Icons.person_outline, 'Account', 4),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData icon, String label, int idx) {
    final selected = _currentIndex == idx;
    return BottomNavigationBarItem(
      icon: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryOrange.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 24, color: selected ? AppColors.primaryOrange : Colors.grey[600]),
      ),
      label: label,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DashboardPage

class DashboardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.dashboard_rounded, color: AppColors.primaryOrange),
          SizedBox(width: 8),
          Text('Dashboard', style: TextStyle(color: Colors.white)),
        ]),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: _statCard('Total Items', '247', Icons.inventory_2, Colors.blue)),
              SizedBox(width: 12),
              Expanded(child: _statCard('Expiring Soon', '12', Icons.warning_amber, Colors.orange)),
            ]),
            SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statCard('Expired', '3', Icons.error_outline, Colors.red)),
              SizedBox(width: 12),
              Expanded(child: _statCard('Categories', '15', Icons.category, Colors.green)),
            ]),
            SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Activity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text('Recent inventory activities will appear here', style: TextStyle(color: Colors.grey[400], fontSize: 16))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: color, size: 24),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ]),
        SizedBox(height: 8),
        Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AlertsPage

class AlertsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.notifications_outlined, color: AppColors.primaryOrange),
          SizedBox(width: 8),
          Text('Alerts', style: TextStyle(color: Colors.white)),
        ]),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.settings, color: Colors.white)),
        ],
      ),
      body: ListView(padding: EdgeInsets.all(16), children: [
        _alertCard('Expiring Soon', '12 items expire within 3 days', Icons.warning_amber, Colors.orange, '2 hours ago'),
        SizedBox(height: 12),
        _alertCard('Low Stock', 'Tomatoes running low (5 left)', Icons.trending_down, Colors.blue, '5 hours ago'),
        SizedBox(height: 12),
        _alertCard('Expired Items', '3 items have expired', Icons.error_outline, Colors.red, '1 day ago'),
        SizedBox(height: 24),
        Center(child: Text('All caught up! No more alerts.', style: TextStyle(color: Colors.grey[400], fontSize: 16))),
      ]),
    );
  }

  Widget _alertCard(String title, String desc, IconData icon, Color color, String time) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text(desc, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            SizedBox(height: 4),
            Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ChatPage

class ChatPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.chat_bubble_outline, color: AppColors.primaryOrange),
          SizedBox(width: 8),
          Text('Team Chat', style: TextStyle(color: Colors.white)),
        ]),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.add, color: Colors.white)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(padding: EdgeInsets.all(16), children: [
            _chatTile('Kitchen Team', 'Hey team, we need to check the dairy section...', '5 members', '2m ago', 3),
            SizedBox(height: 12),
            _chatTile('Management', 'Monthly inventory report is ready', '3 members', '1h ago', 0),
            SizedBox(height: 12),
            _chatTile('Suppliers', 'Delivery scheduled for tomorrow morning', '2 members', '3h ago', 1),
          ]),
        ),
        Container(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Chat functionality coming soon', style: TextStyle(color: Colors.grey[400], fontSize: 16))),
        )
      ]),
    );
  }

  Widget _chatTile(String title, String lastMsg, String members, String time, int unread) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: AppColors.primaryOrange,
          radius: 24,
          child: Text(title[0], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(title, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ]),
            SizedBox(height: 4),
            Text(lastMsg, style: TextStyle(color: Colors.grey[400], fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(members, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              if (unread > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(10)),
                  child: Text('$unread', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AccountPage

class AccountPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.person_outline, color: AppColors.primaryOrange),
          SizedBox(width: 8),
          Text('Account', style: TextStyle(color: Colors.white)),
        ]),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
      ),
      body: ListView(padding: EdgeInsets.all(16), children: [
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryOrange,
              radius: 30,
              child: Icon(Icons.person, size: 30, color: Colors.white),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Chef Manager', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('chef@cheftrack.com', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              ]),
            ),
            IconButton(onPressed: () {}, icon: Icon(Icons.edit, color: AppColors.primaryOrange)),
          ]),
        ),
        SizedBox(height: 24),
        _menuItem(Icons.settings, 'Settings', () {}),
        _menuItem(Icons.help_outline, 'Help & Support', () {}),
        _menuItem(Icons.privacy_tip_outlined, 'Privacy Policy', () {}),
        _menuItem(Icons.info_outline, 'About ChefTrack', () {}),
        SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppColors.cardBackground,
                title: Text('Logout', style: TextStyle(color: Colors.white)),
                content: Text('Are you sure you want to logout?', style: TextStyle(color: Colors.grey[300])),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey[400]))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AuthScreen()));
                    },
                    child: Text('Logout', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            );
          },
          icon: Icon(Icons.logout),
          label: Text('Logout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryOrange),
      title: Text(label, style: TextStyle(color: Colors.white, fontSize: 16)),
      trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: AppColors.cardBackground,
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model + OpenFoodFactsService

class FoodProduct {
  final String barcode;
  final String? productName, brands, imageUrl, categories, ingredients;
  final Map<String, dynamic>? nutritionFacts;
  final String? quantity, packaging;

  FoodProduct({
    required this.barcode,
    this.productName,
    this.brands,
    this.imageUrl,
    this.categories,
    this.ingredients,
    this.nutritionFacts,
    this.quantity,
    this.packaging,
  });

  factory FoodProduct.fromOpenFoodFacts(Map<String, dynamic> json, String barcode) {
    final prod = json['product'] as Map<String, dynamic>?;
    if (prod == null) return FoodProduct(barcode: barcode);
    return FoodProduct(
      barcode: barcode,
      productName: prod['product_name'] as String?,
      brands: prod['brands'] as String?,
      imageUrl: prod['image_url'] as String?,
      categories: prod['categories'] as String?,
      ingredients: prod['ingredients_text'] as String?,
      nutritionFacts: prod['nutriments'] as Map<String, dynamic>?,
      quantity: prod['quantity'] as String?,
      packaging: prod['packaging'] as String?,
    );
  }

  bool get isValid => productName != null && productName!.isNotEmpty;
}

class OpenFoodFactsService {
  static const String baseUrl = 'https://world.openfoodfacts.org/api/v0/product';

  static Future<FoodProduct?> getProductInfo(String barcode) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/$barcode.json'), headers: {
        'User-Agent': 'ChefTrack/1.0.0',
        'Accept': 'application/json',
      }).timeout(Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['status'] == 1) {
          return FoodProduct.fromOpenFoodFacts(data, barcode);
        } else {
          return FoodProduct(barcode: barcode);
        }
      }
    } catch (_) {}
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ProductDetailsScreen

class ProductDetailsScreen extends StatefulWidget {
  final FoodProduct product;
  const ProductDetailsScreen({Key? key, required this.product}) : super(key: key);
  @override
  _ProductDetailsScreenState createState() => _ProductDetailsScreenState();
}
class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();

  DateTime _purchaseDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(Duration(days: 7));
  String _category = 'Food & Beverages';
  bool _isLoading = false;

  final _categories = [
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: Text('Product Details', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildProductInfoCard(),
          SizedBox(height: 20),
          _buildInventoryForm(),
        ]),
      ),
    );
  }

  Widget _buildProductInfoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
          child: widget.product.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.product.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => CircularProgressIndicator(color: AppColors.primaryOrange),
                    errorWidget: (_, __, ___) => Icon(Icons.fastfood, color: Colors.grey[600], size: 40),
                  ),
                )
              : Icon(Icons.fastfood, color: Colors.grey[600], size: 40),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.product.productName ?? 'Unknown Product',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            if (widget.product.brands != null) ...[
              SizedBox(height: 4),
              Text(widget.product.brands!, style: TextStyle(color: AppColors.primaryOrange, fontSize: 14)),
            ],
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primaryOrange.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text('Barcode: ${widget.product.barcode}',
                  style: TextStyle(color: AppColors.primaryOrange, fontSize: 12, fontFamily: 'monospace')),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildInventoryForm() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add to Inventory',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          _buildTextFormField(
            controller: _quantityCtrl,
            label: 'Quantity',
            hint: 'Enter quantity (e.g., 10)',
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter quantity';
              if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Please enter valid quantity';
              return null;
            },
          ),
          SizedBox(height: 16),
          _buildDropdown(),
          SizedBox(height: 16),
          _buildTextFormField(
            controller: _supplierCtrl,
            label: 'Supplier',
            hint: 'Enter supplier name',
            validator: (v) => (v == null || v.isEmpty) ? 'Please enter supplier name' : null,
          ),
          SizedBox(height: 16),
          _buildTextFormField(
            controller: _costCtrl,
            label: 'Cost Price (\$)',
            hint: 'Enter cost price',
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter cost price';
              if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Please enter valid price';
              return null;
            },
          ),
          SizedBox(height: 16),
          _buildTextFormField(
            controller: _batchCtrl,
            label: 'Batch Number (Optional)',
            hint: 'Enter batch number',
            validator: (_) => null,
          ),
          SizedBox(height: 16),
          _buildDatePicker(
            label: 'Purchase Date',
            date: _purchaseDate,
            onSelected: (d) => setState(() => _purchaseDate = d),
          ),
          SizedBox(height: 16),
          _buildDatePicker(
            label: 'Expiry Date',
            date: _expiryDate,
            onSelected: (d) => setState(() => _expiryDate = d),
          ),
          SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _addToInventory,
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(Icons.add),
              label: Text(_isLoading ? 'Adding...' : 'Add to Inventory',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
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
          fillColor: AppColors.inputBackground,
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
            borderSide: BorderSide(color: AppColors.primaryOrange),
          ),
        ),
      ),
    ]);
  }

  Widget _buildDropdown() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Category', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      SizedBox(height: 8),
  DropdownButtonFormField<String>(
  // if for some reason your initial value isn't in the list, fall back to null
  value: _categories.contains(_category) ? _category : null,
  hint: Text('Select category'),
  items: _categories.map((c) => DropdownMenuItem(
    value: c,
    child: Text(c, style: TextStyle(color: Colors.white)),
  )).toList(),
  onChanged: (v) => setState(() => _category = v!),
  decoration: InputDecoration(
    filled: true,
    fillColor: AppColors.inputBackground,
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
      borderSide: BorderSide(color: AppColors.primaryOrange),
          ),
        ),
      ),
    ]);
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onSelected,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      SizedBox(height: 8),
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime.now().subtract(Duration(days: 365)),
            lastDate: DateTime.now().add(Duration(days: 365 * 2)),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: ColorScheme.dark(
                  primary: AppColors.primaryOrange,
                  onPrimary: Colors.white,
                  surface: AppColors.cardBackground,
                  onSurface: Colors.white,
                ),
              ),
              child: child!,
            ),
          );
          if (picked != null) onSelected(picked);
        },
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[600]!),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(DateFormat('MMM dd, yyyy').format(date), style: TextStyle(color: Colors.white)),
            Icon(Icons.calendar_today, color: AppColors.primaryOrange),
          ]),
        ),
      ),
    ]);
  }

  Future<void> _addToInventory() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final payload = {
      'product': {
        'name': widget.product.productName ?? 'Unknown Product',
        'barcode': widget.product.barcode,
        'category': _category,
        'brand': widget.product.brands ?? '',
        'unit_price': double.tryParse(_costCtrl.text) ?? 0.0,
        'description': widget.product.categories ?? '',
      },
      'quantity': int.tryParse(_quantityCtrl.text) ?? 0,
      'purchase_date': _purchaseDate.toIso8601String(),
      'expiry_date': _expiryDate.toIso8601String(),
      'batch_number': _batchCtrl.text,
      'supplier': _supplierCtrl.text,
      'cost_price': double.tryParse(_costCtrl.text) ?? 0.0,
    };

    final res = await ApiService.post('/inventory/add/', payload);
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added successfully!'), backgroundColor: Colors.green[600]),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${res['message']}'), backgroundColor: Colors.red[600]),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ScannerPage

// Replace the ScannerPage class in your main.dart with this:

class ScannerPage extends StatefulWidget {
  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanning = false, _permitted = false;

  @override
  void initState() {
    super.initState();
    _askPermission();
  }

  Future<void> _askPermission() async {
    final s = await Permission.camera.request();
    setState(() => _permitted = s.isGranted);
    if (!s.isGranted) _showPermissionDialog();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Camera Permission', style: TextStyle(color: Colors.white)),
        content: Text(
          'ChefTrack needs camera access to scan barcodes. Please enable it in settings.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Open Settings'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
          ),
        ],
      ),
    );
  }

  Future<void> _processBarcode(String code) async {
    if (_scanning) return;
    setState(() => _scanning = true);
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryOrange),
            SizedBox(height: 16),
            Text('Processing barcode...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    final product = await OpenFoodFactsService.getProductInfo(code);
    Navigator.pop(context);

    if (product != null && product.isValid) {
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(product: product)
        )
      );
    } else {
      _showError('Failed to fetch product info.');
    }

    await Future.delayed(Duration(seconds: 2));
    if (mounted) setState(() => _scanning = false);
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(msg, style: TextStyle(color: Colors.grey[300])),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_permitted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: ElevatedButton(
            onPressed: _askPermission,
            child: Text('Enable Camera'),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Barcode Scanner'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          )
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: (BarcodeCapture capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final code = barcodes.first.rawValue;
            if (code != null) _processBarcode(code);
          }
        },
      ),
    );
  }
}