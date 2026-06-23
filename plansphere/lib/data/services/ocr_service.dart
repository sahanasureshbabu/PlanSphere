import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String fullText;
  final String? productName;
  final String? storeName;
  final double? amount;
  final DateTime? date;
  final String? gstNumber;
  final bool? hasWarranty;
  final String? warrantyInfo;
  final int? warrantyMonths;
  final String? category;
  final double confidenceScore;
  final String? billNumber;
  final double? taxAmount;
  final bool emiEnabled;
  final double emiAmount;
  final String emiDuration;

  OcrResult({
    required this.fullText,
    this.productName,
    this.storeName,
    this.amount,
    this.date,
    this.gstNumber,
    this.hasWarranty,
    this.warrantyInfo,
    this.warrantyMonths,
    this.category,
    this.confidenceScore = 1.0,
    this.billNumber,
    this.taxAmount,
    this.emiEnabled = false,
    this.emiAmount = 0.0,
    this.emiDuration = 'No EMI',
  });
}

class OcrService {
  final TextRecognizer? _textRecognizer;

  OcrService()
      : _textRecognizer = kIsWeb
            ? null
            : TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> extractTextFromImage(XFile imageFile) async {
    if (kIsWeb || _textRecognizer == null) {
      // Mock OCR result for Web
      return OcrResult(
        fullText: 'PlanSphere Web AI Mock OCR\nStore: Croma\nProduct: Samsung OLED TV\nAmount: 54999\nDate: 15/06/2026\nGST: 27AAAAA1111A1Z1\nWarranty: 24 months\nCategory: Electronics\nTax: 9900',
        storeName: 'Croma',
        productName: 'Samsung OLED TV',
        amount: 54999.0,
        date: DateTime.now(),
        gstNumber: '27AAAAA1111A1Z1',
        hasWarranty: true,
        warrantyInfo: '24 months',
        warrantyMonths: 24,
        category: 'Electronics',
        confidenceScore: 0.96,
        billNumber: 'INV-2026-9921',
        taxAmount: 9900.0,
      );
    }
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final fullText = recognizedText.text;
    return _parseOcrText(fullText);
  }

  int? _extractWarrantyMonths(String text) {
    final patterns = [
      RegExp(r'(\d+)\s*years?', caseSensitive: false),
      RegExp(r'(\d+)\s*yrs?', caseSensitive: false),
      RegExp(r'(\d+)\s*months?', caseSensitive: false),
      RegExp(r'(\d+)\s*mos?', caseSensitive: false),
    ];

    for (var i = 0; i < patterns.length; i++) {
      final match = patterns[i].firstMatch(text.toLowerCase());
      if (match != null) {
        final val = int.tryParse(match.group(1)!);
        if (val != null) {
          if (i < 2) return val * 12; // years to months
          return val;
        }
      }
    }
    return null;
  }

  OcrResult _parseOcrText(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();

    String? storeName = _extractStoreName(lines);
    double? amount = _extractAmount(text);
    DateTime? date = _extractDate(text);
    String? gstNumber = _extractGstNumber(text);
    String? productName = _extractProductName(lines);
    bool? hasWarranty = _detectWarranty(text);
    String? warrantyInfo = hasWarranty == true ? _extractWarrantyInfo(text) : null;
    int? warrantyMonths = warrantyInfo != null ? _extractWarrantyMonths(warrantyInfo) : null;
    String? category = _categorizeFromText(text);

    String? billNumber = _extractBillNumber(text);
    double? taxAmount = _extractTaxAmount(text);
    final emi = _extractEmiDetails(text);

    // Calculate OCR Confidence Score based on parsing accuracy
    double confidenceScore = _calculateConfidence(text, amount, date, storeName);

    return OcrResult(
      fullText: text,
      productName: productName,
      storeName: storeName,
      amount: amount,
      date: date,
      gstNumber: gstNumber,
      hasWarranty: hasWarranty,
      warrantyInfo: warrantyInfo,
      warrantyMonths: warrantyMonths,
      category: category,
      confidenceScore: confidenceScore,
      billNumber: billNumber,
      taxAmount: taxAmount,
      emiEnabled: emi['emiEnabled'] ?? false,
      emiAmount: emi['emiAmount'] ?? 0.0,
      emiDuration: emi['emiDuration'] ?? 'No EMI',
    );
  }

  String? _extractBillNumber(String text) {
    final patterns = [
      RegExp(r'(?:invoice|bill|inv|receipt)\s*(?:no\.?|number|#)?[:\s]*([a-zA-Z0-9-\/]+)', caseSensitive: false),
      RegExp(r'(?:tx|transaction)\s*(?:no\.?|id|ref|number|#)?[:\s]*([a-zA-Z0-9-\/]+)', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final val = match.group(1)?.trim();
        if (val != null && val.length > 2) {
          return val;
        }
      }
    }
    return null;
  }

  double? _extractTaxAmount(String text) {
    final patterns = [
      RegExp(r'(?:cgst|sgst|igst|vat|tax|gst|sales tax)[:\s]*(?:rs\.?|₹|inr)?\s*([0-9,]+\.?[0-9]*)', caseSensitive: false),
    ];
    double? maxTax;
    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final taxStr = match.group(1)?.replaceAll(',', '');
        if (taxStr != null) {
          final tax = double.tryParse(taxStr);
          if (tax != null && tax > 0) {
            if (maxTax == null || tax > maxTax) {
              maxTax = tax;
            }
          }
        }
      }
    }
    return maxTax;
  }

  Map<String, dynamic> _extractEmiDetails(String text) {
    final lowerText = text.toLowerCase();
    final emiKeywords = ['emi', 'monthly payment', 'installment', 'tenure', 'no cost emi'];
    bool emiEnabled = emiKeywords.any((keyword) => lowerText.contains(keyword)) ||
        RegExp(r'\b\d+\s*months?\b').hasMatch(lowerText);

    if (!emiEnabled) {
      return {
        'emiEnabled': false,
        'emiAmount': 0.0,
        'emiDuration': 'No EMI',
      };
    }

    double emiAmount = 0.0;
    final emiAmtPatterns = [
      RegExp(r'(?:emi|monthly payment|installment|monthly installment)[:\s]*(?:rs\.?|₹|inr)?\s*([0-9,]+\.?[0-9]*)', caseSensitive: false),
    ];
    for (final pattern in emiAmtPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amtStr = match.group(1)?.replaceAll(',', '');
        if (amtStr != null) {
          emiAmount = double.tryParse(amtStr) ?? 0.0;
        }
      }
    }

    String emiDuration = 'No EMI';
    final tenurePattern = RegExp(r'(\d+)\s*(?:months?|installment|tenure|months duration)', caseSensitive: false);
    final match = tenurePattern.firstMatch(text);
    if (match != null) {
      emiDuration = '${match.group(1)} months';
    } else {
      for (final duration in ['3 months', '6 months', '9 months', '12 months', '24 months']) {
        if (lowerText.contains(duration)) {
          emiDuration = duration;
          break;
        }
      }
      if (emiDuration == 'No EMI' && emiEnabled) {
        emiDuration = 'Unknown';
      }
    }

    return {
      'emiEnabled': emiEnabled,
      'emiAmount': emiAmount,
      'emiDuration': emiDuration,
    };
  }

  double _calculateConfidence(String text, double? amount, DateTime? date, String? storeName) {
    double confidence = 0.35; // base confidence for successfully reading text block
    
    // Add weights for successful parsing of target fields
    if (amount != null && amount > 0) confidence += 0.25;
    if (date != null) confidence += 0.25;
    if (storeName != null && storeName.length > 3) confidence += 0.15;
    
    // Slight bonus for tax numbers
    if (text.contains(RegExp(r'\b[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\b'))) {
      confidence += 0.05;
    }
    
    return confidence.clamp(0.10, 0.99); // Clamp within realistic 10% - 99% range
  }

  String? _extractStoreName(List<String> lines) {
    // First non-empty line is usually the store name
    for (final line in lines.take(5)) {
      if (line.isNotEmpty && line.length > 3) {
        return line;
      }
    }
    return null;
  }

  double? _extractAmount(String text) {
    // Match common bill amount patterns
    final patterns = [
      RegExp(r'(?:total|amount|grand total|net amount|bill amount)[:\s]*(?:rs\.?|₹|inr)?\s*([0-9,]+\.?[0-9]*)', caseSensitive: false),
      RegExp(r'(?:rs\.?|₹|inr)\s*([0-9,]+\.?[0-9]*)', caseSensitive: false),
      RegExp(r'([0-9,]+\.?[0-9]*)\s*(?:rs\.?|₹|inr)', caseSensitive: false),
    ];

    double? maxAmount;
    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        if (amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0) {
            if (maxAmount == null || amount > maxAmount) {
              maxAmount = amount;
            }
          }
        }
      }
    }
    return maxAmount;
  }

  DateTime? _extractDate(String text) {
    final patterns = [
      RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})'),
      RegExp(r'(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})'),
      RegExp(r'(\d{1,2})\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+(\d{2,4})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          if (pattern == patterns[0]) {
            int day = int.parse(match.group(1)!);
            int month = int.parse(match.group(2)!);
            int year = int.parse(match.group(3)!);
            if (year < 100) year += 2000;
            if (day > 0 && day <= 31 && month > 0 && month <= 12) {
              return DateTime(year, month, day);
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }

  String? _extractGstNumber(String text) {
    // GST number format: 15 digit alphanumeric
    final gstPattern = RegExp(
        r'\b[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\b');
    final match = gstPattern.firstMatch(text.toUpperCase());
    return match?.group(0);
  }

  String? _extractProductName(List<String> lines) {
    // Product name is usually in the first few lines after store name
    for (final line in lines.skip(1).take(5)) {
      if (line.isNotEmpty &&
          line.length > 5 &&
          !line.contains(RegExp(r'^[0-9]'))) {
        return line;
      }
    }
    return null;
  }

  bool? _detectWarranty(String text) {
    final warrantyKeywords = [
      'warranty', 'guarantee', 'warrantee', 'गारंटी', 'वारंटी'
    ];
    final lowerText = text.toLowerCase();
    return warrantyKeywords.any((kw) => lowerText.contains(kw));
  }

  String? _extractWarrantyInfo(String text) {
    final patterns = [
      RegExp(r'warranty[:\s]*([^\n]+)', caseSensitive: false),
      RegExp(r'(\d+)\s*(?:year|month|yr|mo)[s]?\s*warranty', caseSensitive: false),
      RegExp(r'warranty[:\s]*(\d+)\s*(?:year|month|yr|mo)[s]?', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(0);
    }
    return null;
  }

  String? _categorizeFromText(String text) {
    final lowerText = text.toLowerCase();

    final categoryKeywords = {
      'Electronics': ['mobile', 'phone', 'laptop', 'computer', 'tablet', 'tv', 'television', 'camera', 'headphones', 'earphone', 'charger', 'fridge', 'washing machine', 'ac', 'air conditioner', 'refrigerator'],
      'Furniture': ['sofa', 'chair', 'table', 'cot', 'bed', 'mattress', 'cupboard', 'wardrobe', 'furniture'],
      'Home Appliances': ['mixer', 'grinder', 'oven', 'microwave', 'fan', 'iron', 'vacuum', 'dishwasher', 'purifier'],
      'Fashion': ['dress', 'shirt', 'shoes', 'bag', 'watch', 'clothing', 'apparel', 't-shirt', 'pant'],
      'Grocery': ['rice', 'oil', 'milk', 'fruits', 'vegetables', 'snacks', 'grocery', 'supermarket', 'food', 'beverage'],
      'Vehicle': ['bike', 'car', 'helmet', 'tyre', 'battery', 'vehicle', 'automobile', 'scooter'],
      'Medical': ['medicine', 'pharmacy', 'hospital', 'clinic', 'health', 'medical', 'prescription'],
    };

    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lowerText.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return 'Others';
  }

  void dispose() {
    _textRecognizer?.close();
  }
}
