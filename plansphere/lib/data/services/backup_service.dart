import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
import 'package:plansphere/core/constants/app_constants.dart';

class BackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Creates a full JSON backup of all user data in Firestore
  Future<String?> createBackup(String userId) async {
    try {
      final data = <String, dynamic>{};

      // Backup bills
      final billsSnap = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.billsCollection)
          .get();
      data['bills'] = billsSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      // Backup documents metadata (not the actual files)
      final docsSnap = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.documentsCollection)
          .get();
      data['documents'] = docsSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      // Backup user profile
      final userSnap = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      if (userSnap.exists) {
        data['user'] = userSnap.data();
      }

      data['backupDate'] = DateTime.now().toIso8601String();
      data['version'] = AppConstants.appVersion;

      // Upload backup JSON to Storage
      final json = jsonEncode(data);
      final bytes = utf8.encode(json);
      final backupPath =
          'backups/$userId/backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final ref = _storage.ref(backupPath);
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'application/json'),
      ).timeout(const Duration(seconds: 8));

      final downloadUrl = await ref.getDownloadURL().timeout(const Duration(seconds: 8));

      // Update last backup time in user doc
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'lastBackup': Timestamp.fromDate(DateTime.now()),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          AppConstants.keyLastBackup, DateTime.now().toIso8601String());

      return downloadUrl;
    } catch (e) {
      debugPrint('Backup error: $e');
      return null;
    }
  }

  /// Lists available backups for the user
  Future<List<Map<String, dynamic>>> listBackups(String userId) async {
    try {
      final result =
          await _storage.ref('backups/$userId').listAll().timeout(const Duration(seconds: 8));
      final backups = <Map<String, dynamic>>[];
      for (final item in result.items) {
        final meta = await item.getMetadata().timeout(const Duration(seconds: 8));
        backups.add({
          'name': item.name,
          'path': item.fullPath,
          'size': meta.size,
          'updated': meta.updated,
        });
      }
      backups.sort((a, b) => (b['updated'] as DateTime)
          .compareTo(a['updated'] as DateTime));
      return backups;
    } catch (e) {
      return [];
    }
  }

  /// Restores data from a backup file
  Future<bool> restoreBackup(
      String userId, String backupPath) async {
    try {
      final ref = _storage.ref(backupPath);
      final data = await ref.getData().timeout(const Duration(seconds: 8));
      if (data == null) return false;

      final json =
          jsonDecode(utf8.decode(data)) as Map<String, dynamic>;

      final batch = _firestore.batch();

      // Restore bills
      if (json['bills'] != null) {
        for (final bill in json['bills'] as List) {
          final billMap = Map<String, dynamic>.from(bill as Map);
          final id = billMap.remove('id') as String?;
          if (id != null) {
            batch.set(
              _firestore
                  .collection(AppConstants.usersCollection)
                  .doc(userId)
                  .collection(AppConstants.billsCollection)
                  .doc(id),
              billMap,
              SetOptions(merge: true),
            );

            // Also restore warranties if applicable
            if (billMap['hasWarranty'] == true) {
              batch.set(
                _firestore
                    .collection(AppConstants.usersCollection)
                    .doc(userId)
                    .collection('warranties')
                    .doc(id),
                billMap,
                SetOptions(merge: true),
              );
            }
          }
        }
      }

      // Restore documents metadata
      if (json['documents'] != null) {
        for (final doc in json['documents'] as List) {
          final docMap = Map<String, dynamic>.from(doc as Map);
          final id = docMap.remove('id') as String?;
          if (id != null) {
            batch.set(
              _firestore
                  .collection(AppConstants.usersCollection)
                  .doc(userId)
                  .collection(AppConstants.documentsCollection)
                  .doc(id),
              docMap,
              SetOptions(merge: true),
            );
          }
        }
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }
}
