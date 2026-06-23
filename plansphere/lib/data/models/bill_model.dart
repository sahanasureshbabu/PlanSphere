import 'package:cloud_firestore/cloud_firestore.dart';
import 'maintenance_model.dart';

enum WarrantyStatus { active, expiringSoon, expired, noWarranty }

class BillModel {
  final String id;
  final String userId;
  final String title;
  final String category;
  final String recordType;
  final DateTime purchaseDate;
  final double amount;
  final String storeName;
  final String description;
  final List<String> tags;
  final String? imageUrl;
  final String? pdfUrl;
  final String? imageBase64;
  final bool hasWarranty;
  final int? warrantyDurationMonths;
  final DateTime? warrantyExpiryDate;
  final String? gstNumber;
  final String? productName;
  final String? ocrText;
  final bool isDuplicate;
  final String? duplicateOfId;
  final String? familyGroupId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Added Fields
  final String brand;
  final double ocrConfidenceScore;
  final String claimStatus; // none, submitted, under_review, approved, rejected
  final String? claimNotes;
  final List<ServiceRecord> serviceHistory;
  final AmcRecord? amcDetails;
  final String? billNumber;
  final double? taxAmount;
  final bool emiEnabled;
  final double emiAmount;
  final String emiDuration;

  BillModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.recordType,
    required this.purchaseDate,
    required this.amount,
    required this.storeName,
    required this.description,
    required this.tags,
    this.imageUrl,
    this.pdfUrl,
    this.imageBase64,
    required this.hasWarranty,
    this.warrantyDurationMonths,
    this.warrantyExpiryDate,
    this.gstNumber,
    this.productName,
    this.ocrText,
    required this.isDuplicate,
    this.duplicateOfId,
    this.familyGroupId,
    required this.createdAt,
    required this.updatedAt,
    // Added Fields
    this.brand = 'Generic',
    this.ocrConfidenceScore = 1.0,
    this.claimStatus = 'none',
    this.claimNotes,
    this.serviceHistory = const [],
    this.amcDetails,
    this.billNumber,
    this.taxAmount,
    this.emiEnabled = false,
    this.emiAmount = 0.0,
    this.emiDuration = 'No EMI',
  });

  WarrantyStatus get warrantyStatus {
    if (!hasWarranty) return WarrantyStatus.noWarranty;
    if (warrantyExpiryDate == null) return WarrantyStatus.noWarranty;
    final now = DateTime.now();
    if (warrantyExpiryDate!.isBefore(now)) return WarrantyStatus.expired;
    final daysUntilExpiry = warrantyExpiryDate!.difference(now).inDays;
    if (daysUntilExpiry <= 30) return WarrantyStatus.expiringSoon;
    return WarrantyStatus.active;
  }

  int? get daysUntilWarrantyExpiry {
    if (warrantyExpiryDate == null) return null;
    return warrantyExpiryDate!.difference(DateTime.now()).inDays;
  }

  factory BillModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse service history
    final rawHistory = data['serviceHistory'] as List<dynamic>? ?? [];
    final parsedHistory = rawHistory
        .map((item) => ServiceRecord.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    // Parse AMC details
    final rawAmc = data['amcDetails'] as Map<dynamic, dynamic>?;
    final parsedAmc = rawAmc != null
        ? AmcRecord.fromMap(Map<String, dynamic>.from(rawAmc))
        : null;

    return BillModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      recordType: data['recordType'] ?? '',
      purchaseDate: (data['purchaseDate'] as Timestamp).toDate(),
      amount: (data['amount'] ?? 0.0).toDouble(),
      storeName: data['storeName'] ?? '',
      description: data['description'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      imageUrl: data['imageUrl'],
      pdfUrl: data['pdfUrl'],
      imageBase64: data['imageBase64'],
      hasWarranty: data['hasWarranty'] ?? false,
      warrantyDurationMonths: data['warrantyDurationMonths'],
      warrantyExpiryDate: data['warrantyExpiryDate'] != null
          ? (data['warrantyExpiryDate'] as Timestamp).toDate()
          : null,
      gstNumber: data['gstNumber'],
      productName: data['productName'],
      ocrText: data['ocrText'],
      isDuplicate: data['isDuplicate'] ?? false,
      duplicateOfId: data['duplicateOfId'],
      familyGroupId: data['familyGroupId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      // Added Fields Mapping
      brand: data['brand'] ?? 'Generic',
      ocrConfidenceScore: (data['ocrConfidenceScore'] ?? 1.0).toDouble(),
      claimStatus: data['claimStatus'] ?? 'none',
      claimNotes: data['claimNotes'],
      serviceHistory: parsedHistory,
      amcDetails: parsedAmc,
      billNumber: data['billNumber'],
      taxAmount: data['taxAmount'] != null ? (data['taxAmount'] as num).toDouble() : null,
      emiEnabled: data['emiEnabled'] ?? false,
      emiAmount: (data['emiAmount'] ?? 0.0).toDouble(),
      emiDuration: data['emiDuration'] ?? 'No EMI',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'category': category,
      'recordType': recordType,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'amount': amount,
      'storeName': storeName,
      'description': description,
      'tags': tags,
      'imageUrl': imageUrl,
      'pdfUrl': pdfUrl,
      'imageBase64': imageBase64,
      'hasWarranty': hasWarranty,
      'warrantyDurationMonths': warrantyDurationMonths,
      'warrantyExpiryDate': warrantyExpiryDate != null
          ? Timestamp.fromDate(warrantyExpiryDate!)
          : null,
      'gstNumber': gstNumber,
      'productName': productName,
      'ocrText': ocrText,
      'isDuplicate': isDuplicate,
      'duplicateOfId': duplicateOfId,
      'familyGroupId': familyGroupId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      // Added Fields Serializers
      'brand': brand,
      'ocrConfidenceScore': ocrConfidenceScore,
      'claimStatus': claimStatus,
      'claimNotes': claimNotes,
      'serviceHistory': serviceHistory.map((item) => item.toMap()).toList(),
      'amcDetails': amcDetails?.toMap(),
      'billNumber': billNumber,
      'taxAmount': taxAmount,
      'emiEnabled': emiEnabled,
      'emiAmount': emiAmount,
      'emiDuration': emiDuration,
    };
  }

  BillModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? category,
    String? recordType,
    DateTime? purchaseDate,
    double? amount,
    String? storeName,
    String? description,
    List<String>? tags,
    String? imageUrl,
    String? pdfUrl,
    String? imageBase64,
    bool? hasWarranty,
    int? warrantyDurationMonths,
    DateTime? warrantyExpiryDate,
    String? gstNumber,
    String? productName,
    String? ocrText,
    bool? isDuplicate,
    String? duplicateOfId,
    String? familyGroupId,
    DateTime? createdAt,
    DateTime? updatedAt,
    // Added Fields copyWith
    String? brand,
    double? ocrConfidenceScore,
    String? claimStatus,
    String? claimNotes,
    List<ServiceRecord>? serviceHistory,
    AmcRecord? amcDetails,
    String? billNumber,
    double? taxAmount,
    bool? emiEnabled,
    double? emiAmount,
    String? emiDuration,
  }) {
    return BillModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      recordType: recordType ?? this.recordType,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      amount: amount ?? this.amount,
      storeName: storeName ?? this.storeName,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      imageBase64: imageBase64 ?? this.imageBase64,
      hasWarranty: hasWarranty ?? this.hasWarranty,
      warrantyDurationMonths: warrantyDurationMonths ?? this.warrantyDurationMonths,
      warrantyExpiryDate: warrantyExpiryDate ?? this.warrantyExpiryDate,
      gstNumber: gstNumber ?? this.gstNumber,
      productName: productName ?? this.productName,
      ocrText: ocrText ?? this.ocrText,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateOfId: duplicateOfId ?? this.duplicateOfId,
      familyGroupId: familyGroupId ?? this.familyGroupId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // Added Fields Bindings
      brand: brand ?? this.brand,
      ocrConfidenceScore: ocrConfidenceScore ?? this.ocrConfidenceScore,
      claimStatus: claimStatus ?? this.claimStatus,
      claimNotes: claimNotes ?? this.claimNotes,
      serviceHistory: serviceHistory ?? this.serviceHistory,
      amcDetails: amcDetails ?? this.amcDetails,
      billNumber: billNumber ?? this.billNumber,
      taxAmount: taxAmount ?? this.taxAmount,
      emiEnabled: emiEnabled ?? this.emiEnabled,
      emiAmount: emiAmount ?? this.emiAmount,
      emiDuration: emiDuration ?? this.emiDuration,
    );
  }
}
