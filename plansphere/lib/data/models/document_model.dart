import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentModel {
  final String id;
  final String userId;
  final String title;
  final String category;
  final String description;
  final List<String> tags;
  final String? fileUrl;
  final String? fileType; // pdf, image, etc.
  final double? fileSizeMB;
  final String? thumbnailUrl;
  final DateTime? expiryDate;
  final bool hasReminder;
  final String? familyGroupId;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.description,
    required this.tags,
    this.fileUrl,
    this.fileType,
    this.fileSizeMB,
    this.thumbnailUrl,
    this.expiryDate,
    required this.hasReminder,
    this.familyGroupId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  factory DocumentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DocumentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      fileUrl: data['fileUrl'],
      fileType: data['fileType'],
      fileSizeMB: data['fileSizeMB']?.toDouble(),
      thumbnailUrl: data['thumbnailUrl'],
      expiryDate: data['expiryDate'] != null
          ? (data['expiryDate'] as Timestamp).toDate()
          : null,
      hasReminder: data['hasReminder'] ?? false,
      familyGroupId: data['familyGroupId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'category': category,
      'description': description,
      'tags': tags,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSizeMB': fileSizeMB,
      'thumbnailUrl': thumbnailUrl,
      'expiryDate': expiryDate != null
          ? Timestamp.fromDate(expiryDate!)
          : null,
      'hasReminder': hasReminder,
      'familyGroupId': familyGroupId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
