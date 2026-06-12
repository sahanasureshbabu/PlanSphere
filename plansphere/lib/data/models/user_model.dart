import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String? phoneNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? familyGroupId;
  final String? familyRole; // admin, member
  final int totalBills;
  final int totalDocuments;
  final double storageUsedMB;
  final bool biometricEnabled;
  final bool notificationsEnabled;
  final String themeMode; // light, dark, system
  final String language;
  final DateTime? lastBackup;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
    this.familyGroupId,
    this.familyRole,
    this.totalBills = 0,
    this.totalDocuments = 0,
    this.storageUsedMB = 0,
    this.biometricEnabled = false,
    this.notificationsEnabled = true,
    this.themeMode = 'system',
    this.language = 'en',
    this.lastBackup,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      phoneNumber: data['phoneNumber'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      familyGroupId: data['familyGroupId'],
      familyRole: data['familyRole'],
      totalBills: data['totalBills'] ?? 0,
      totalDocuments: data['totalDocuments'] ?? 0,
      storageUsedMB: (data['storageUsedMB'] ?? 0).toDouble(),
      biometricEnabled: data['biometricEnabled'] ?? false,
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      themeMode: data['themeMode'] ?? 'system',
      language: data['language'] ?? 'en',
      lastBackup: data['lastBackup'] != null
          ? (data['lastBackup'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'familyGroupId': familyGroupId,
      'familyRole': familyRole,
      'totalBills': totalBills,
      'totalDocuments': totalDocuments,
      'storageUsedMB': storageUsedMB,
      'biometricEnabled': biometricEnabled,
      'notificationsEnabled': notificationsEnabled,
      'themeMode': themeMode,
      'language': language,
      'lastBackup': lastBackup != null ? Timestamp.fromDate(lastBackup!) : null,
    };
  }

  UserModel copyWith({
    String? name,
    String? photoUrl,
    String? phoneNumber,
    String? familyGroupId,
    String? familyRole,
    int? totalBills,
    int? totalDocuments,
    double? storageUsedMB,
    bool? biometricEnabled,
    bool? notificationsEnabled,
    String? themeMode,
    String? language,
    DateTime? lastBackup,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      familyGroupId: familyGroupId ?? this.familyGroupId,
      familyRole: familyRole ?? this.familyRole,
      totalBills: totalBills ?? this.totalBills,
      totalDocuments: totalDocuments ?? this.totalDocuments,
      storageUsedMB: storageUsedMB ?? this.storageUsedMB,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      lastBackup: lastBackup ?? this.lastBackup,
    );
  }
}
