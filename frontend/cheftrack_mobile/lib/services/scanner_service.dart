// lib/services/scanner_service.dart
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../models/product_master.dart';
import '../models/scan_result.dart';
import 'api_service.dart';

class ScannerService {
  static final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin
  );

  /// Main method to process any scanned barcode
  static Future<ScanResult> processScanResult(
    String rawBarcode, 
    Uint8List? imageBytes,
    Size? imageSize,
  ) async {
    print('Processing barcode: $rawBarcode');
    
    // Step 1: Try to parse GS1-128 format
    final gs1Result = _parseGS1_128(rawBarcode);
    if (gs1Result != null) {
      print('GS1-128 detected with expiry: ${gs1Result['expiry']}');
      final product = await _fetchProductInfo(gs1Result['gtin']!);
      return ScanResult(
        barcode: gs1Result['gtin']!,
        product: product,
        expiryDate: gs1Result['expiry'],
        batchNumber: gs1Result['batch'],
        scanType: ScanType.gs1_128,
        gs1Data: gs1Result,
      );
    }

    // Step 2: Regular barcode - fetch product info
    final product = await _fetchProductInfo(rawBarcode);
    
    // Step 3: If we have image data, try OCR for expiry date
    DateTime? ocrExpiry;
    if (imageBytes != null && imageSize != null) {
      ocrExpiry = await _extractExpiryFromImage(imageBytes, imageSize);
    }

    return ScanResult(
      barcode: rawBarcode,
      product: product,
      expiryDate: ocrExpiry,
      scanType: ocrExpiry != null ? ScanType.ocrEnhanced : ScanType.basicBarcode,
    );
  }

  /// Parse GS1-128 barcodes to extract GTIN, expiry date, batch number, etc.
  static Map<String, dynamic>? _parseGS1_128(String rawData) {
    // GS1-128 Application Identifiers:
    // (01) - GTIN (14 digits)
    // (17) - Expiry date (YYMMDD)
    // (10) - Batch/Lot number (variable length)
    // (15) - Best before date (YYMMDD)
    // (21) - Serial number (variable length)
    
    final Map<String, dynamic> result = {};
    
    // Try different GS1 patterns
    final patterns = [
      // Pattern 1: (01)GTIN(17)YYMMDD
      RegExp(r'\(01\)(\d{14})\(17\)(\d{6})'),
      // Pattern 2: (01)GTIN(15)YYMMDD (best before)
      RegExp(r'\(01\)(\d{14})\(15\)(\d{6})'),
      // Pattern 3: With batch number (01)GTIN(17)YYMMDD(10)BATCH
      RegExp(r'\(01\)(\d{14})\(17\)(\d{6})\(10\)([A-Za-z0-9]+)'),
      // Pattern 4: With batch number (01)GTIN(10)BATCH(17)YYMMDD
      RegExp(r'\(01\)(\d{14})\(10\)([A-Za-z0-9]+)\(17\)(\d{6})'),
    ];

    for (int i = 0; i < patterns.length; i++) {
      final pattern = patterns[i];
      final match = pattern.firstMatch(rawData);
      if (match != null) {
        result['gtin'] = match.group(1)!;
        
        String? dateStr;
        String? batchStr;
        
        if (i == 3) {
          // Pattern 4: batch comes before date
          batchStr = match.group(2);
          dateStr = match.group(3);
        } else {
          // Other patterns: date comes before batch (if present)
          dateStr = match.group(2);
          if (match.groupCount >= 3 && match.group(3) != null) {
            batchStr = match.group(3);
          }
        }
        
        if (dateStr != null) {
          result['expiry'] = _parseGS1Date(dateStr);
        }
        if (batchStr != null) {
          result['batch'] = batchStr;
        }
        
        return result;
      }
    }
    
    // Try to extract just GTIN if other patterns fail
    final gtinPattern = RegExp(r'\(01\)(\d{14})');
    final gtinMatch = gtinPattern.firstMatch(rawData);
    if (gtinMatch != null) {
      result['gtin'] = gtinMatch.group(1)!;
      return result;
    }
    
    return null;
  }

  /// Convert GS1 date format (YYMMDD) to DateTime
  static DateTime? _parseGS1Date(String yymmdd) {
    if (yymmdd.length != 6) return null;
    
    try {
      final yy = int.parse(yymmdd.substring(0, 2));
      final mm = int.parse(yymmdd.substring(2, 4));
      final dd = int.parse(yymmdd.substring(4, 6));
      
      // Assume 20xx for years 00-30, 19xx for years 31-99
      final year = yy <= 30 ? 2000 + yy : 1900 + yy;
      
      return DateTime(year, mm, dd);
    } catch (e) {
      print('Error parsing GS1 date: $e');
      return null;
    }
  }

  /// Fetch product information using your existing API service
  static Future<ProductMaster?> _fetchProductInfo(String barcode) async {
    try {
      // First try your backend API
      final backendProduct = await ApiService.fetchProductMaster(barcode);
      if (backendProduct != null && backendProduct.isValid) {
        print('Product found in backend: ${backendProduct.productName}');
        return backendProduct;
      }
      
      // Fallback to OpenFoodFacts
      print('Product not found in backend, trying OpenFoodFacts...');
      final openFoodFactsProduct = await ApiService.fetchFromOpenFoodFacts(barcode);
      if (openFoodFactsProduct != null && openFoodFactsProduct.isValid) {
        print('Product found in OpenFoodFacts: ${openFoodFactsProduct.productName}');
        return openFoodFactsProduct;
      }
      
      print('Product not found in any source');
      return null;
    } catch (e) {
      print('Error fetching product info: $e');
      return null;
    }
  }

  /// Extract expiry date from image using OCR
  static Future<DateTime?> _extractExpiryFromImage(
    Uint8List imageBytes, 
    Size imageSize,
  ) async {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        inputImageData: InputImageData(
          size: imageSize,
          imageRotation: InputImageRotation.rotation0deg,
          inputImageFormat: InputImageFormat.yuv420,
          planeData: [],
        ),
      );
      
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final fullText = recognizedText.text;
      
      print('OCR Text found: $fullText');
      
      // Try multiple date patterns
      final datePatterns = [
        // MM/DD/YYYY or MM-DD-YYYY
        RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})'),
        // DD/MM/YYYY or DD-MM-YYYY
        RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})'),
        // YYYY-MM-DD
        RegExp(r'(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})'),
        // MMM DD, YYYY (Jan 15, 2024)
        RegExp(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2}),?\s+(\d{4})', caseSensitive: false),
        // DD MMM YYYY (15 Jan 2024)
        RegExp(r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})', caseSensitive: false),
        // Expiry keywords followed by date
        RegExp(r'(?:exp|expire|expiry|best before|use by)[:\s]*(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})', caseSensitive: false),
        // DDMMYY or DDMMYYYY format
        RegExp(r'(?:exp|expire|expiry|best before|use by)[:\s]*(\d{2})(\d{2})(\d{2,4})', caseSensitive: false),
      ];
      
      for (final pattern in datePatterns) {
        final matches = pattern.allMatches(fullText);
        for (final match in matches) {
          final date = _parseOCRDate(match, pattern);
          if (date != null && _isValidExpiryDate(date)) {
            print('Valid expiry date found: $date');
            return date;
          }
        }
      }
      
    } catch (e) {
      print('OCR Error: $e');
    }
    
    return null;
  }

  /// Parse date from OCR match
  static DateTime? _parseOCRDate(RegExpMatch match, RegExp pattern) {
    try {
      final text = match.group(0)!.toLowerCase();
      
      // Handle month name patterns
      if (text.contains(RegExp(r'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec'))) {
        // Extract month name and convert to number
        final monthNames = ['jan', 'feb', 'mar', 'apr', 'may', 'jun',
                           'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
        
        int? month, day, year;
        
        // Find month
        for (int i = 0; i < monthNames.length; i++) {
          if (text.contains(monthNames[i])) {
            month = i + 1;
            break;
          }
        }
        
        // Extract numbers
        final numbers = RegExp(r'\d+').allMatches(text).map((m) => int.parse(m.group(0)!)).toList();
        
        if (numbers.length >= 2 && month != null) {
          // Determine day and year based on pattern
          if (text.startsWith(RegExp(r'\d'))) {
            // DD MMM YYYY format
            day = numbers[0];
            year = numbers[1];
          } else {
            // MMM DD, YYYY format
            day = numbers[0];
            year = numbers.length > 1 ? numbers[1] : DateTime.now().year;
          }
          
          if (day != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      } else {
        // Handle numeric date patterns
        final groups = <int>[];
        for (int i = 1; i <= match.groupCount; i++) {
          final group = match.group(i);
          if (group != null) {
            final num = int.tryParse(group);
            if (num != null) groups.add(num);
          }
        }
        
        if (groups.length >= 3) {
          // Handle DDMMYY format specifically
          if (groups.length == 3 && groups[2] < 100) {
            // Convert YY to YYYY
            final yy = groups[2];
            final year = yy <= 30 ? 2000 + yy : 1900 + yy;
            return DateTime(year, groups[1], groups[0]); // DD MM YY
          }
          
          // Determine date format based on values
          if (groups[0] > 31) {
            // YYYY-MM-DD
            return DateTime(groups[0], groups[1], groups[2]);
          } else if (groups[0] > 12) {
            // DD-MM-YYYY
            return DateTime(groups[2], groups[1], groups[0]);
          } else {
            // MM-DD-YYYY (default US format)
            return DateTime(groups[2], groups[0], groups[1]);
          }
        }
      }
    } catch (e) {
      print('Date parsing error: $e');
    }
    return null;
  }

  /// Validate if the extracted date is a reasonable expiry date
  static bool _isValidExpiryDate(DateTime date) {
    final now = DateTime.now();
    final fiveYearsFromNow = now.add(Duration(days: 365 * 5));
    
    // Date should be between yesterday and 5 years from now
    return date.isAfter(now.subtract(Duration(days: 1))) && 
           date.isBefore(fiveYearsFromNow);
  }

  /// Dispose resources
  static void dispose() {
    _textRecognizer.close();
  }
}