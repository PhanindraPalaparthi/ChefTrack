// lib/models/scan_result.dart

import 'product_master.dart';

enum ScanType {
  basicBarcode,
  gs1_128,
  ocrEnhanced,
}

class ScanResult {
  final String barcode;
  final ProductMaster? product;
  final DateTime? expiryDate;
  final String? batchNumber;
  final ScanType scanType;
  final Map<String, dynamic>? gs1Data;

  ScanResult({
    required this.barcode,
    this.product,
    this.expiryDate,
    this.batchNumber,
    required this.scanType,
    this.gs1Data,
  });

  /// Check if scan was successful (found product)
  bool get isSuccessful => product != null;

  /// Get scan type as display string
  String get scanTypeDisplay {
    switch (scanType) {
      case ScanType.basicBarcode:
        return 'Basic Barcode';
      case ScanType.gs1_128:
        return 'GS1-128 Enhanced';
      case ScanType.ocrEnhanced:
        return 'OCR Enhanced';
    }
  }

  /// Check if expiry was automatically detected
  bool get hasAutoExpiry => expiryDate != null;

  /// Check if batch number was detected
  bool get hasBatchNumber => batchNumber != null && batchNumber!.isNotEmpty;

  /// Convert to JSON for logging/debugging
  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'product_name': product?.productName,
      'expiry_date': expiryDate?.toIso8601String(),
      'batch_number': batchNumber,
      'scan_type': scanType.toString(),
      'gs1_data': gs1Data,
    };
  }

  @override
  String toString() {
    return 'ScanResult(barcode: $barcode, type: $scanType, product: ${product?.productName})';
  }
}