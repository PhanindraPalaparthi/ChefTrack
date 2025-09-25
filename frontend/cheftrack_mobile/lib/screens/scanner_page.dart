// lib/screens/scanner_page.dart
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/product_master.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';
import 'add_inventory_page.dart';

class ScannerPage extends StatefulWidget {
  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isScanning = false;
  bool _hasPermission = false;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() => _hasPermission = status.isGranted);
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera permission required to scan barcodes')),
      );
    }
  }

  /// Try to parse a GS1-128 composite: (01)14‐digit GTIN then (17)YYMMDD
  bool _tryParseGS1(String raw, Map<String,String> result) {
    final re = RegExp(r'\(01\)(\d{14})\(17\)(\d{6})');
    final m = re.firstMatch(raw);
    if (m != null) {
      result['gtin'] = m.group(1)!;
      result['expiry'] = m.group(2)!; // YYMMDD
      return true;
    }
    return false;
  }

  /// OCR fallback to scrape an expiry date from the image
  Future<DateTime?> _performOCR(InputImage image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final visionResult = await recognizer.processImage(image);
    await recognizer.close();

    final fullText = visionResult.text;
    // very simple regex: match MM/DD/YYYY or YYYY-MM-DD
    final re = RegExp(r'(\d{2}[\/\-]\d{2}[\/\-]\d{4})');
    final m = re.firstMatch(fullText);
    if (m != null) {
      try {
        return DateFormat.yMd().parseLoose(m.group(1)!);
      } catch (_) {}
    }
    return null;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final barcode = barcodes.first;
    final raw = barcode.rawValue;
    if (raw == null || raw == _lastScannedCode) return;
    
    setState(() {
      _isScanning = true;
      _lastScannedCode = raw;
    });

    String? gtin;
    DateTime? expiry;

    // 1) GS1-128 check
    final parsed = <String,String>{};
    if (_tryParseGS1(raw, parsed)) {
      gtin   = parsed['gtin'];
      final yymmdd = parsed['expiry']!; // e.g. "230712"
      final yy = int.parse(yymmdd.substring(0,2)) + 2000;
      final mm = int.parse(yymmdd.substring(2,4));
      final dd = int.parse(yymmdd.substring(4,6));
      expiry = DateTime(yy, mm, dd);
    }
    
    // 2) normal EAN/UPC
    if (gtin == null) {
      // raw is the GTIN
      gtin = raw;
    }

    // 3) fetch master
    final product = await _fetchProductMaster(gtin);
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product not found in master database')),
      );
      setState(() => _isScanning = false);
      return;
    }

    // 4) if we didn't get expiry from AI17, OCR fallback
    if (expiry == null && capture.image != null) {
      // Create InputImage from capture - FIXED TYPE ERROR
      final inputImage = InputImage.fromBytes(
        bytes: capture.image!,
        metadata: InputImageMetadata(
          size: Size(
            (capture.width ?? 640).toDouble(), 
            (capture.height ?? 480).toDouble()
          ),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.yuv420,
          bytesPerRow: (capture.width ?? 640).toInt(), // FIXED: Cast to int
        ),
      );
      expiry = await _performOCR(inputImage);
    }

    // if still no expiry, user will pick manually in AddInventoryPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInventoryPage(
          product: product,
          initialExpiry: expiry,             // new optional parameter
        ),
      ),
    );

    // Allow scanning again after delay
    await Future.delayed(Duration(seconds: 2));
    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  /// Fetch product master data
  Future<ProductMaster?> _fetchProductMaster(String barcode) async {
    try {
      // Try OpenFoodFacts for testing
      final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
        headers: {
          'User-Agent': 'ChefTrack/1.0.0',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1) {
          return ProductMaster.fromOpenFoodFacts(data, barcode);
        }
      }
    } catch (e) {
      print('Error fetching product: $e');
    }
    
    // Return basic product if not found
    return ProductMaster(barcode: barcode, productName: 'Unknown Product');
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(title: Text('Barcode Scanner')),
        body: Center(
          child: ElevatedButton(
            onPressed: _requestCameraPermission,
            child: Text('Enable Camera'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Scan Barcode')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),
          if (_isScanning)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}